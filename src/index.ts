import { registerPlugin, type PluginListenerHandle } from '@capacitor/core';

/**
 * How the native bar treats a tap on an item.
 *
 * - `tab`: becomes the selected item and is reported through `tabSelect`.
 * - `action`: keeps the current selection and is reported through `actionTap`.
 */
export type NativeTabBarItemKind = 'tab' | 'action';

/** One item of the native tab bar. */
export interface NativeTabBarItem {
  /** Stable identifier; items are diffed by it and every event reports it. */
  key: string;
  /** Label shown below the icon. */
  title: string;
  /** http(s) or base64 `data:` URL of a PNG rendered as template image, null for a title-only item. */
  iconUrl: string | null;
  /** Pixel scale the PNG was rendered at (defaults to 3). */
  iconScale?: number;
  /** Whether a tap selects the item or only triggers an action. */
  kind: NativeTabBarItemKind;
}

/**
 * Colors and appearance of the native bar.
 *
 * There is deliberately no background color: setting one would replace the
 * Liquid Glass material of iOS 26.
 */
export interface NativeTabBarAppearance {
  /** Hex color (`#RRGGBB` or `#RRGGBBAA`) of the selected item. */
  tintColor: string;
  /** Hex color of the badge background, system default when absent. */
  badgeColor?: string;
  /** Hex color of the badge text, system default when absent. */
  badgeTextColor?: string;
  /** Interface style the glass is rendered with, `system` follows the device setting. */
  style: 'light' | 'dark' | 'system';
}

/** Payload of the `tabSelect` event. */
export interface NativeTabBarTabSelectEvent {
  /** Key of the tapped tab item. */
  key: string;
  /** True when the tapped item was already selected (e.g. pop to tab root). */
  reselect: boolean;
}

/** Payload of the `actionTap` event. */
export interface NativeTabBarActionTapEvent {
  /** Key of the tapped action item. */
  key: string;
}

/** Payload of the `heightChange` event and result of the height-reporting methods. */
export interface NativeTabBarHeight {
  /** Full height of the bar in points, including the home indicator area. */
  height: number;
}

/** Native interface of the NativeTabBar plugin. */
export interface NativeTabBarPlugin {
  /**
   * Checks whether the native glass bar can be used and, if so, creates it hidden.
   * @returns `supported` is true only on iOS 26+ without the compatibility opt-out; `height` is the laid-out bar height (0 when unsupported).
   */
  isSupported(): Promise<{ supported: boolean; height: number }>;

  /**
   * Replaces the items of the bar. The bar is hidden while the list is empty.
   * @param options The new item list and selection.
   * @param options.items Items in display order.
   * @param options.selectedKey Key of the selected item, null for no selection.
   * @returns The bar height after the items were laid out.
   */
  setItems(options: { items: NativeTabBarItem[]; selectedKey: string | null }): Promise<NativeTabBarHeight>;

  /**
   * Selects an item without emitting `tabSelect`.
   * @param options The selection.
   * @param options.key Key of the item to select, null to clear the selection (route without a tab).
   */
  select(options: { key: string | null }): Promise<void>;

  /**
   * Sets the badge of an item.
   * @param options The badge to set.
   * @param options.key Key of the item; a badge for an unknown key is applied once the item appears.
   * @param options.value Badge text, null to remove the badge.
   */
  setBadge(options: { key: string; value: string | null }): Promise<void>;

  /**
   * Applies colors and interface style.
   * @param options The appearance to apply.
   */
  setAppearance(options: NativeTabBarAppearance): Promise<void>;

  /**
   * Hides or shows the bar, e.g. while a web overlay is presented.
   * @param options The requested visibility.
   * @param options.hidden Whether the web layer wants the bar hidden.
   * @param options.animated Whether to animate the change (defaults to true).
   */
  setHidden(options: { hidden: boolean; animated?: boolean }): Promise<void>;

  /**
   * Reads the current bar height.
   * @returns The full bar height in points, 0 when the bar does not exist.
   */
  getHeight(): Promise<NativeTabBarHeight>;

  /**
   * Fires when a `tab` item is tapped.
   * @param eventName The event name.
   * @param listenerFunc Receives the tapped key and whether it was already selected.
   */
  addListener(eventName: 'tabSelect', listenerFunc: (event: NativeTabBarTabSelectEvent) => void): Promise<PluginListenerHandle>;

  /**
   * Fires when an `action` item is tapped; the selection stays unchanged.
   * @param eventName The event name.
   * @param listenerFunc Receives the tapped key.
   */
  addListener(eventName: 'actionTap', listenerFunc: (event: NativeTabBarActionTapEvent) => void): Promise<PluginListenerHandle>;

  /**
   * Fires when the laid-out bar height changes (rotation, safe area, item changes).
   * @param eventName The event name.
   * @param listenerFunc Receives the new height.
   */
  addListener(eventName: 'heightChange', listenerFunc: (event: NativeTabBarHeight) => void): Promise<PluginListenerHandle>;

  /** Removes every listener registered on this plugin. */
  removeAllListeners(): Promise<void>;
}

/**
 * The NativeTabBar plugin.
 *
 * iOS only — there is deliberately no web or Android implementation, so
 * `Capacitor.isPluginAvailable('NativeTabBar')` is false there and on shells
 * built before the plugin existed, and the web layer keeps its HTML tab bar.
 */
export const NativeTabBar = registerPlugin<NativeTabBarPlugin>('NativeTabBar');
