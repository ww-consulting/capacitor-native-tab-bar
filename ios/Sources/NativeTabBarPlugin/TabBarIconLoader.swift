import CryptoKit
import Foundation
import UIKit

/// Downloads tab icons as template images.
///
/// Icon URLs are immutable per icon id and scale, so a file copy in Caches is
/// never revalidated. It exists for offline cold starts, where the HTTP cache
/// of URLSession alone may already have been evicted.
final class TabBarIconLoader {
    static let shared = TabBarIconLoader()

    private let session = URLSession(configuration: .default)
    private let ioQueue = DispatchQueue(label: "de.ww-consulting.nativetabbar.icons", qos: .userInitiated)
    private let cacheDirectory: URL?

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        cacheDirectory = caches?.appendingPathComponent("NativeTabBarIcons", isDirectory: true)
        if let directory = cacheDirectory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// Loads the icon at `url` and calls `completion` on the main queue.
    /// - Parameters:
    ///   - url: PNG location.
    ///   - scale: Pixel scale the PNG was rendered at.
    ///   - completion: Receives the template image, or nil when it could not be loaded.
    func load(url: URL, scale: CGFloat, completion: @escaping (UIImage?) -> Void) {
        let fileURL = cacheFileURL(for: url)
        ioQueue.async {
            if let fileURL = fileURL, let data = try? Data(contentsOf: fileURL),
               let image = TabBarIconLoader.templateImage(data: data, scale: scale) {
                DispatchQueue.main.async { completion(image) }
                return
            }

            let task = self.session.dataTask(with: url) { data, response, _ in
                var image: UIImage?
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                if let data = data, (200..<300).contains(statusCode) {
                    image = TabBarIconLoader.templateImage(data: data, scale: scale)
                    if image != nil, let fileURL = fileURL {
                        try? data.write(to: fileURL, options: .atomic)
                    }
                }
                DispatchQueue.main.async { completion(image) }
            }
            task.resume()
        }
    }

    private func cacheFileURL(for url: URL) -> URL? {
        guard let directory = cacheDirectory else { return nil }
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name).appendingPathExtension("png")
    }

    private static func templateImage(data: Data, scale: CGFloat) -> UIImage? {
        return UIImage(data: data, scale: scale)?.withRenderingMode(.alwaysTemplate)
    }
}
