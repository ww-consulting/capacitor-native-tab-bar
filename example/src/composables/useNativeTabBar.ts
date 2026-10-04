import { Capacitor } from '@capacitor/core'
import { NativeTabBar } from '@ww-consulting/capacitor-native-tab-bar'
import { readonly, ref } from 'vue'

const DETECTION_TIMEOUT_MS = 1000

/** Class on `<html>` that hides the HTML tab bar while the native one is in use. */
const GLASS_MODE_CLASS = 'native-tab-bar'

/** CSS variable with the native bar height, for content that must stay clear of it. */
const HEIGHT_VARIABLE = '--native-tab-bar-height'

const glassMode = ref(false)
const nativeHeight = ref(0)

/**
 * Updates the height the native bar reported, e.g. after new items or a layout change.
 * @param height - Full bar height in points, home indicator area included.
 */
const setNativeHeight = (height: number) => {
  nativeHeight.value = height
  document.documentElement.style.setProperty(HEIGHT_VARIABLE, `${height}px`)
}

/**
 * Decides once at start-up whether the native iOS 26 glass tab bar replaces
 * the HTML one, and switches `html.native-tab-bar` on if so. Call it before
 * the app mounts.
 *
 * Never throws. A shell without the plugin, an unsupported OS, an error or no
 * answer within 1 s all keep the HTML tab bar; a late answer only leaves the
 * native bar created but hidden, since it shows nothing without items.
 */
export const detectNativeTabBar = async (): Promise<void> => {
  if (!Capacitor.isPluginAvailable('NativeTabBar')) return

  let timer: ReturnType<typeof setTimeout> | undefined
  const timeout = new Promise<null>((resolve) => {
    timer = setTimeout(() => resolve(null), DETECTION_TIMEOUT_MS)
  })

  try {
    const result = await Promise.race([NativeTabBar.isSupported(), timeout])
    if (!result?.supported) return

    setNativeHeight(result.height)
    glassMode.value = true
    document.documentElement.classList.add(GLASS_MODE_CLASS)
  } catch (e) {
    console.warn('[useNativeTabBar] Native tab bar detection failed, keeping the HTML tab bar:', e)
  } finally {
    clearTimeout(timer)
  }
}

/**
 * Shared state of the native tab bar. `glassMode` is decided once by
 * `detectNativeTabBar()` before the app mounts and never changes afterwards.
 * @returns Read-only glass mode flag and native bar height, plus a setter for the height.
 */
export const useNativeTabBar = () => ({
  glassMode: readonly(glassMode),
  nativeHeight: readonly(nativeHeight),
  setNativeHeight,
})
