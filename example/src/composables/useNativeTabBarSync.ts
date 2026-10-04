import type { PluginListenerHandle } from '@capacitor/core'
import { NativeTabBar, type NativeTabBarAppearance, type NativeTabBarItem } from '@ww-consulting/capacitor-native-tab-bar'
import { nextTick, onBeforeUnmount, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useNativeTabBar } from './useNativeTabBar'

/** What the native bar needs to know besides the items. */
export interface NativeTabBarSyncOptions {
  /** Current badge text per item key; a missing key or null means no badge. */
  badges: () => Readonly<Record<string, string | null>>
  /** Colors and interface style of the bar. */
  appearance: () => NativeTabBarAppearance
}

/**
 * Ionic overlays that cover the web view. The native bar lies above every web
 * overlay, so it has to step aside while one of them is open.
 */
const OVERLAY_TYPES = ['Modal', 'Popover', 'Alert', 'ActionSheet', 'Loading', 'Picker']

const openOverlays = new Set<Element>()
let overlayTrackingInstalled = false
let hiddenForOverlay = false

/**
 * Mirrors Ionic's selected tab to the native bar. Read from the `ion-tab-bar`
 * element, which Ionic sets synchronously and clears for routes whose tab has
 * no button; that case fires no `ionTabsDidChange`.
 */
const syncSelection = () => {
  const selectedTab = document.querySelector('ion-tab-bar')?.selectedTab
  void NativeTabBar.select({ key: selectedTab || null })
}

/**
 * Forwards a native tap to the matching HTML tab-bar element, so routing,
 * reselect-to-root and every click handler of the tabs page stay the single
 * code path. The HTML elements carry `data-tab-key` for this.
 *
 * For an `ion-tab-button` the click is dispatched on its content, where a
 * finger tap lands too, so capture handlers on the button run first.
 * @param key - Item key the native bar reported.
 */
const forwardTap = (key: string) => {
  const element = document.querySelector<HTMLElement>(`ion-tab-bar [data-tab-key="${CSS.escape(key)}"]`)
  if (!element) return
  const content = element.tagName === 'ION-TAB-BUTTON' ? element.firstElementChild : null
  const target = content instanceof HTMLElement ? content : element
  target.click()
}

const updateOverlayVisibility = () => {
  for (const overlay of openOverlays) {
    if (!overlay.isConnected) openOverlays.delete(overlay)
  }
  const hidden = openOverlays.size > 0
  if (hidden === hiddenForOverlay) return
  hiddenForOverlay = hidden
  void NativeTabBar.setHidden({ hidden })
  // A tap that opened an overlay instead of navigating left the native
  // selection on the tapped item.
  if (!hidden) syncSelection()
}

/**
 * Hides the native bar while any Ionic overlay is open. Installed once for the
 * app's lifetime; overlay events bubble to the document from inline and
 * controller-created overlays alike. Non-Ionic overlays are not tracked.
 */
const installOverlayTracking = () => {
  if (overlayTrackingInstalled) return
  overlayTrackingInstalled = true

  for (const type of OVERLAY_TYPES) {
    document.addEventListener(`ion${type}WillPresent`, (event) => {
      if (event.target instanceof Element) openOverlays.add(event.target)
      updateOverlayVisibility()
    })
    document.addEventListener(`ion${type}WillDismiss`, (event) => {
      if (event.target instanceof Element) openOverlays.delete(event.target)
      updateOverlayVisibility()
    })
  }
}

/**
 * Keeps the native iOS glass tab bar in sync with the HTML `ion-tab-bar` in
 * glass mode; a no-op otherwise. Must be called from the tabs page's setup.
 *
 * Everything runs through watchers and event listeners, never through the
 * tabs page's render: any re-render of `ion-tab-bar` makes Ionic forget each
 * tab's remembered page.
 * @param items - Items of the native bar, in display order.
 * @param options - Badges and appearance.
 * @returns `syncSelection`, to be bound to `ion-tabs`' `ionTabsDidChange`.
 */
export const useNativeTabBarSync = (items: () => readonly NativeTabBarItem[], options: NativeTabBarSyncOptions) => {
  const { glassMode, setNativeHeight } = useNativeTabBar()
  if (!glassMode.value) return { syncSelection: () => undefined }

  const route = useRoute()

  installOverlayTracking()

  const listeners: Promise<PluginListenerHandle>[] = [
    NativeTabBar.addListener('tabSelect', ({ key }) => forwardTap(key)),
    NativeTabBar.addListener('actionTap', ({ key }) => forwardTap(key)),
    NativeTabBar.addListener('heightChange', ({ height }) => setNativeHeight(height)),
  ]

  watch(
    items,
    async (next) => {
      const selectedKey = document.querySelector('ion-tab-bar')?.selectedTab || null
      const { height } = await NativeTabBar.setItems({ items: [...next], selectedKey })
      setNativeHeight(height)
    },
    { immediate: true }
  )

  watch(
    [items, options.badges],
    ([next, badges]) => {
      for (const item of next) {
        void NativeTabBar.setBadge({ key: item.key, value: badges[item.key] ?? null })
      }
    },
    { immediate: true }
  )

  watch(options.appearance, (appearance) => void NativeTabBar.setAppearance(appearance), { immediate: true })

  watch(
    () => route.fullPath,
    async () => {
      await nextTick()
      syncSelection()
      updateOverlayVisibility()
    }
  )

  onBeforeUnmount(() => {
    void Promise.all(listeners).then((handles) => handles.forEach((handle) => void handle.remove()))
    void NativeTabBar.setItems({ items: [], selectedKey: null })
  })

  return { syncSelection }
}
