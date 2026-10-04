import Capacitor
import Foundation
import UIKit
import WebKit

/// Renders the app tab bar as a native iOS 26 Liquid Glass `UITabBar`, while
/// navigation itself stays in the web layer.
///
/// Design choice: a standalone `UITabBar` laid over the web view instead of a
/// `UITabBarController`. That needs no re-parenting of Capacitor's root view
/// controller, leaves the web view's safe area untouched (the web layer pads
/// its content with the reported height) and allows `selectedItem = nil` for
/// routes that belong to no tab. The glass material comes with the Xcode 26
/// SDK as long as no background is set on the bar.
///
/// Fallback, should the selection lens flicker when an action item restores
/// the previous selection: an embedded `UITabBarController` with empty child
/// view controllers that answers `shouldSelect` with false, behind the same
/// JS contract.
@objc(NativeTabBarPlugin)
public class NativeTabBarPlugin: CAPPlugin, CAPBridgedPlugin, UITabBarDelegate {
    public let identifier = "NativeTabBarPlugin"
    public let jsName = "NativeTabBar"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "isSupported", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setItems", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "select", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setBadge", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setAppearance", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setHidden", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getHeight", returnType: CAPPluginReturnPromise)
    ]

    /// Keeps the icon slot occupied while the PNG loads, so the title does not jump.
    private static let placeholderIcon = UIGraphicsImageRenderer(size: CGSize(width: 25, height: 25))
        .image { _ in }
        .withRenderingMode(.alwaysTemplate)

    // Plugin methods run on the bridge queue; everything below is only touched on the main queue.
    private var tabBar: LayoutReportingTabBar?
    private var itemsByKey: [String: KeyedTabBarItem] = [:]
    private var selectedKey: String?
    private var badges: [String: String] = [:]
    private var badgeColor: UIColor?
    private var badgeTextColor: UIColor?
    private var hiddenByJS = false
    private var keyboardVisible = false
    private var reportedHeight: CGFloat = 0
    private var loadingObservation: NSKeyValueObservation?

    override public func load() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(keyboardWillShow),
                           name: UIResponder.keyboardWillShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillHide),
                           name: UIResponder.keyboardWillHideNotification, object: nil)

        // A full page load (reload, live-update bundle switch) starts a web layer
        // that may never talk to this plugin, e.g. an older bundle. Same-document
        // navigations of the SPA do not toggle isLoading.
        loadingObservation = webView?.observe(\.isLoading, options: [.new]) { [weak self] _, change in
            guard change.newValue == true else { return }
            NativeTabBarPlugin.onMain { self?.resetForPageLoad() }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        loadingObservation?.invalidate()
    }

    // MARK: - Plugin methods

    @objc func isSupported(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let bar = self.ensureTabBar() else {
                call.resolve(["supported": false, "height": 0])
                return
            }
            call.resolve(["supported": true, "height": self.layoutHeight(of: bar)])
        }
    }

    @objc func setItems(_ call: CAPPluginCall) {
        let specs = (call.getArray("items", JSObject.self) ?? []).compactMap(ItemSpec.init)
        let selectedKey = call.getString("selectedKey")
        DispatchQueue.main.async {
            guard let bar = self.ensureTabBar() else {
                call.resolve(["height": 0])
                return
            }
            var nextByKey: [String: KeyedTabBarItem] = [:]
            var items: [KeyedTabBarItem] = []
            for spec in specs where nextByKey[spec.key] == nil {
                let item = self.itemsByKey[spec.key] ?? self.makeItem(key: spec.key)
                item.title = spec.title
                item.isAction = spec.isAction
                self.applyIcon(of: spec, to: item)
                nextByKey[spec.key] = item
                items.append(item)
            }
            self.itemsByKey = nextByKey
            bar.setItems(items, animated: false)
            self.applySelection(key: selectedKey)
            self.updateVisibility(animated: true)
            call.resolve(["height": self.layoutHeight(of: bar)])
        }
    }

    @objc func select(_ call: CAPPluginCall) {
        let key = call.getString("key")
        DispatchQueue.main.async {
            self.applySelection(key: key)
            call.resolve()
        }
    }

    @objc func setBadge(_ call: CAPPluginCall) {
        guard let key = call.getString("key") else {
            call.reject("key is required")
            return
        }
        let value = call.getString("value")
        DispatchQueue.main.async {
            // Remembered per key, so a badge set before its item exists is applied on creation.
            self.badges[key] = value
            self.itemsByKey[key]?.badgeValue = value
            call.resolve()
        }
    }

    @objc func setAppearance(_ call: CAPPluginCall) {
        let tintColor = call.getString("tintColor").flatMap { UIColor.capacitor.color(fromHex: $0) }
        let badgeColor = call.getString("badgeColor").flatMap { UIColor.capacitor.color(fromHex: $0) }
        let badgeTextColor = call.getString("badgeTextColor").flatMap { UIColor.capacitor.color(fromHex: $0) }
        let style = call.getString("style")
        DispatchQueue.main.async {
            self.badgeColor = badgeColor
            self.badgeTextColor = badgeTextColor
            guard let bar = self.ensureTabBar() else {
                call.resolve()
                return
            }
            // Only tint and interface style: any background, barTintColor or
            // UITabBarAppearance background would replace the Liquid Glass material.
            if let tintColor = tintColor {
                bar.tintColor = tintColor
            }
            switch style {
            case "light": bar.overrideUserInterfaceStyle = .light
            case "dark": bar.overrideUserInterfaceStyle = .dark
            default: bar.overrideUserInterfaceStyle = .unspecified
            }
            for item in self.itemsByKey.values {
                self.applyBadgeAppearance(to: item)
            }
            call.resolve()
        }
    }

    @objc func setHidden(_ call: CAPPluginCall) {
        let hidden = call.getBool("hidden", false)
        let animated = call.getBool("animated", true)
        DispatchQueue.main.async {
            self.hiddenByJS = hidden
            self.updateVisibility(animated: animated)
            call.resolve()
        }
    }

    @objc func getHeight(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let height = self.tabBar.map { self.layoutHeight(of: $0) } ?? 0
            call.resolve(["height": height])
        }
    }

    // MARK: - UITabBarDelegate

    public func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let item = item as? KeyedTabBarItem else { return }
        if item.isAction {
            // UITabBar has already moved the selection to the action item; put it
            // back without animation so the action never looks like a tab.
            let previous = selectedKey.flatMap { itemsByKey[$0] }
            UIView.performWithoutAnimation {
                tabBar.selectedItem = previous
            }
            notifyListeners("actionTap", data: ["key": item.key])
            return
        }
        let reselect = item.key == selectedKey
        selectedKey = item.key
        notifyListeners("tabSelect", data: ["key": item.key, "reselect": reselect])
    }

    // MARK: - Bar lifecycle

    private static var isGlassAvailable: Bool {
        guard #available(iOS 26.0, *) else { return false }
        // Apps that opt out of the new design via Info.plist get no glass, so the HTML bar stays.
        return Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool != true
    }

    private func ensureTabBar() -> LayoutReportingTabBar? {
        if let bar = tabBar {
            return bar
        }
        guard NativeTabBarPlugin.isGlassAvailable, let container = bridge?.viewController?.view else {
            return nil
        }
        let bar = LayoutReportingTabBar()
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.alpha = 0
        bar.isUserInteractionEnabled = false
        bar.onLayout = { [weak self] height in
            self?.reportHeight(height)
        }

        // In Capacitor the root view is the web view itself. Inserting right above
        // its scroll view keeps views other plugins add later (splash screen,
        // scanner overlays) on top of the bar.
        if let webView = webView, webView === container, webView.scrollView.superview === container {
            container.insertSubview(bar, aboveSubview: webView.scrollView)
        } else {
            container.addSubview(bar)
        }

        // Pinned to the view edges, not the safe area: UITabBar extends itself
        // over the home indicator and reports that in its height.
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        tabBar = bar
        return bar
    }

    private func layoutHeight(of bar: UITabBar) -> Double {
        bar.superview?.layoutIfNeeded()
        return Double(bar.bounds.height)
    }

    private func reportHeight(_ height: CGFloat) {
        guard height != reportedHeight else { return }
        reportedHeight = height
        notifyListeners("heightChange", data: ["height": Double(height)])
    }

    private func resetForPageLoad() {
        guard let bar = tabBar else { return }
        itemsByKey = [:]
        selectedKey = nil
        badges = [:]
        hiddenByJS = false
        bar.setItems([], animated: false)
        updateVisibility(animated: false)
    }

    /// Hidden while the web layer asks for it, while the keyboard is up, or
    /// while there are no items (before the first `setItems` and after a reset).
    private func updateVisibility(animated: Bool) {
        guard let bar = tabBar else { return }
        let hidden = hiddenByJS || keyboardVisible || itemsByKey.isEmpty
        bar.isUserInteractionEnabled = !hidden
        let changes = {
            bar.alpha = hidden ? 0 : 1
            bar.transform = hidden ? CGAffineTransform(translationX: 0, y: bar.bounds.height) : .identity
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut],
                           animations: changes)
        } else {
            changes()
        }
    }

    // MARK: - Items

    private func makeItem(key: String) -> KeyedTabBarItem {
        let item = KeyedTabBarItem(key: key)
        item.badgeValue = badges[key]
        applyBadgeAppearance(to: item)
        return item
    }

    private func applySelection(key: String?) {
        let item = key.flatMap { itemsByKey[$0] }
        tabBar?.selectedItem = item
        selectedKey = item?.key
    }

    private func applyBadgeAppearance(to item: UITabBarItem) {
        item.badgeColor = badgeColor
        let attributes: [NSAttributedString.Key: Any]? = badgeTextColor.map { [.foregroundColor: $0] }
        item.setBadgeTextAttributes(attributes, for: .normal)
    }

    private func applyIcon(of spec: ItemSpec, to item: KeyedTabBarItem) {
        // A nil image with a URL means the last load failed; retry it on the next setItems.
        let failedBefore = spec.iconURL != nil && item.image == nil
        guard item.iconURL != spec.iconURL || item.iconScale != spec.iconScale || failedBefore else { return }
        item.iconURL = spec.iconURL
        item.iconScale = spec.iconScale
        guard let url = spec.iconURL else {
            item.image = nil
            return
        }
        item.image = NativeTabBarPlugin.placeholderIcon
        TabBarIconLoader.shared.load(url: url, scale: spec.iconScale) { [weak item] image in
            // The item may have been given another icon while this one loaded.
            guard let item = item, item.iconURL == url else { return }
            item.image = image
        }
    }

    // MARK: - Keyboard

    @objc private func keyboardWillShow(_ notification: Notification) {
        NativeTabBarPlugin.onMain {
            self.keyboardVisible = true
            self.updateVisibility(animated: true)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        NativeTabBarPlugin.onMain {
            self.keyboardVisible = false
            self.updateVisibility(animated: true)
        }
    }

    private static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

/// One item as sent by `setItems`.
private struct ItemSpec {
    let key: String
    let title: String
    let iconURL: URL?
    let iconScale: CGFloat
    let isAction: Bool

    init?(_ object: JSObject) {
        guard let key = object["key"] as? String else { return nil }
        self.key = key
        title = object["title"] as? String ?? ""
        iconURL = (object["iconUrl"] as? String).flatMap { URL(string: $0) }
        iconScale = CGFloat(object["iconScale"] as? Double ?? 3)
        isAction = object["kind"] as? String == "action"
    }
}

/// Tab bar item that carries the JS key and the icon it currently wants.
final class KeyedTabBarItem: UITabBarItem {
    let key: String
    var isAction = false
    var iconURL: URL?
    var iconScale: CGFloat = 3

    init(key: String) {
        self.key = key
        super.init()
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

/// `UITabBar` that reports its height on every layout pass, so safe-area and
/// rotation changes reach the web layer as `heightChange`.
final class LayoutReportingTabBar: UITabBar {
    var onLayout: ((CGFloat) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(bounds.height)
    }
}
