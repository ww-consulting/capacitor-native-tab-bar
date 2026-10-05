# @ww-consulting/capacitor-native-tab-bar

Capacitor plugin that renders the app's tab bar as a native iOS 26 **Liquid Glass** `UITabBar` on top of the web view.

The web layer stays in charge: it hands the plugin the items, the selection, badges and colors, and the plugin reports taps back. There is deliberately no web or Android implementation — on those platforms, on iOS < 26 and on shells built without the plugin, `Capacitor.isPluginAvailable('NativeTabBar')` or `isSupported()` tells the app to keep its HTML tab bar.

- iOS only, glass bar on iOS 26+ (apps that set `UIDesignRequiresCompatibility` get `supported: false`)
- Capacitor 8
- CocoaPods and Swift Package Manager

## Install

```bash
pnpm add @ww-consulting/capacitor-native-tab-bar
npx cap sync ios
```

## API

```ts
import { NativeTabBar } from '@ww-consulting/capacitor-native-tab-bar'

const { supported, height } = await NativeTabBar.isSupported() // creates the bar hidden

await NativeTabBar.setAppearance({ tintColor: '#E5484D', style: 'system' })
await NativeTabBar.setItems({
  items: [
    { key: 'home', title: 'Home', iconUrl: 'https://example.com/home@3x.png', iconScale: 3, kind: 'tab' },
    { key: 'compose', title: 'Compose', iconUrl: null, kind: 'action' },
  ],
  selectedKey: 'home',
})

await NativeTabBar.addListener('tabSelect', ({ key, reselect }) => {})
await NativeTabBar.addListener('actionTap', ({ key }) => {})
await NativeTabBar.addListener('heightChange', ({ height }) => {})

await NativeTabBar.select({ key: 'home' }) // no tabSelect event
await NativeTabBar.setBadge({ key: 'home', value: '3' })
await NativeTabBar.setHidden({ hidden: true })
```

All types are documented in [`src/index.ts`](src/index.ts).

| Method | Purpose |
| --- | --- |
| `isSupported()` | Checks for iOS 26+, creates the bar hidden, returns its height |
| `setItems({ items, selectedKey })` | Replaces the items (diffed by `key`); an empty list hides the bar |
| `select({ key })` | Changes the selection without emitting `tabSelect` |
| `setBadge({ key, value })` | Sets or removes (`null`) a badge |
| `setAppearance(appearance)` | Tint, badge colors and light/dark/system style. There is no background color on purpose — it would replace the glass |
| `setHidden({ hidden, animated })` | Hides the bar, e.g. while a web overlay is open |
| `getHeight()` | Full bar height in points, home indicator area included |

Item kinds:

- `tab` becomes the selected item and is reported through `tabSelect` (`reselect: true` when it already was selected).
- `action` keeps the current selection and is reported through `actionTap` — for items that open a modal or run an action.

### Icons

`iconUrl` must be a PNG served over **http(s)** or a base64 **`data:`** URL (`data:image/png;base64,...`). Bundled web assets (`capacitor://localhost/...`) do not work, since the plugin loads remote icons with `URLSession`. The PNG is used as a template image: only its alpha channel counts, the bar tints it. Render it at `iconScale` (default 3, i.e. 75×75 px for a 25 pt icon).

- **http(s)**: cached on disk per URL and never revalidated, so change the URL when an icon changes. The very first start without a network shows empty icon slots.
- **`data:`**: decoded in place, without network or cache. Use it for icons shipped with the app, e.g. a PNG imported with Vite's `?inline` suffix.

## Using it with Ionic Vue

The [`example/`](example) app shows the integration we use in production:

- **`useNativeTabBar.ts`** — `detectNativeTabBar()` runs once before the app mounts. In glass mode it sets `html.native-tab-bar` (CSS hides `ion-tab-bar`) and keeps `--native-tab-bar-height` up to date, which content uses as bottom padding, since the native bar floats above the web view.
- **`useNativeTabBarSync.ts`** — called from the tabs page. The HTML `ion-tab-bar` stays in the DOM as the single source of truth: native taps are forwarded as clicks to its buttons (found via `data-tab-key`), so Ionic's routing, tab stacks and reselect-to-root keep working unchanged. It mirrors the selection back after route changes and hides the native bar while any Ionic overlay is open, because the native bar is drawn above every web overlay.
- **`TabsPage.vue`** — the template must not read reactive state: every re-render of `ion-tab-bar` makes Ionic forget each tab's remembered page. Badges and colors go to the native bar through watchers instead.

Run it:

```bash
pnpm install && pnpm build   # in the repo root, builds the plugin
cd example
pnpm install
pnpm build && npx cap add ios   # first time only; ios/ is not committed
pnpm ios                        # vite build, cap sync ios, opens Xcode
```

Pick an iOS 26+ simulator. On older iOS or in the browser (`pnpm dev`) the example shows the HTML tab bar.

## Development

```bash
pnpm install
pnpm typecheck && pnpm lint && pnpm build
```

The Swift sources live in `ios/Sources/NativeTabBarPlugin`. The example links the plugin from the repo root, so `pnpm build` plus `npx cap sync ios` in `example/` picks up changes.

## Release

1. Bump `version` in `package.json` and commit.
2. `git tag v<version> && git push --tags`
3. `pnpm publish` (runs typecheck, lint and build first)

## License

MIT
