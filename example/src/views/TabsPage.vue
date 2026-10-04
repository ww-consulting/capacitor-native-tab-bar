<template>
  <ion-page>
    <ion-tabs @ion-tabs-did-change="syncSelection">
      <ion-router-outlet />
      <ion-tab-bar slot="bottom">
        <ion-tab-button v-for="tab in routableTabs" :key="tab.key" :tab="tab.key" :href="`/tabs/${tab.key}`" :data-tab-key="tab.key">
          <img class="tab-icon" :src="tab.iconUrl ?? ''" alt="" />
          <ion-label>{{ tab.title }}</ion-label>
        </ion-tab-button>
        <button type="button" class="tab-action-button" data-tab-key="compose" @click="openCompose">
          <img class="tab-icon" :src="composeItem.iconUrl ?? ''" alt="" />
          <span>{{ composeItem.title }}</span>
        </button>
      </ion-tab-bar>
    </ion-tabs>
  </ion-page>
</template>

<script setup lang="ts">
import { IonLabel, IonPage, IonRouterOutlet, IonTabBar, IonTabButton, IonTabs, modalController } from '@ionic/vue'
import type { NativeTabBarAppearance, NativeTabBarItem } from '@ww-consulting/capacitor-native-tab-bar'
import { useInbox } from '../composables/useInbox'
import { useNativeTabBarSync } from '../composables/useNativeTabBarSync'
import ComposeModal from './ComposeModal.vue'

/**
 * The native bar loads icons with URLSession, so they have to be served over
 * http(s); bundled web assets (capacitor://localhost) do not work. The PNGs are
 * template images: only the alpha channel counts, the bar tints them itself.
 */
const ICON_BASE_URL = 'https://raw.githubusercontent.com/ww-consulting/capacitor-native-tab-bar/main/example/icons'

const icon = (name: string) => `${ICON_BASE_URL}/${name}.png`

const routableTabs: NativeTabBarItem[] = [
  { key: 'home', title: 'Home', iconUrl: icon('home'), iconScale: 3, kind: 'tab' },
  { key: 'search', title: 'Search', iconUrl: icon('search'), iconScale: 3, kind: 'tab' },
  { key: 'inbox', title: 'Inbox', iconUrl: icon('inbox'), iconScale: 3, kind: 'tab' },
]

const composeItem: NativeTabBarItem = { key: 'compose', title: 'Compose', iconUrl: icon('compose'), iconScale: 3, kind: 'action' }

const items = [...routableTabs, composeItem]

const appearance: NativeTabBarAppearance = { tintColor: '#E5484D', badgeColor: '#E5484D', badgeTextColor: '#FFFFFF', style: 'system' }

const { badgeText } = useInbox()

// The template must not read reactive state: any re-render of ion-tab-bar
// makes Ionic forget each tab's remembered page. Badges and appearance go to
// the native bar through watchers instead.
const { syncSelection } = useNativeTabBarSync(() => items, {
  badges: () => ({ inbox: badgeText.value }),
  appearance: () => appearance,
})

/** An `action` item: opens an overlay instead of switching tabs, the native bar hides meanwhile. */
const openCompose = async () => {
  const modal = await modalController.create({ component: ComposeModal })
  await modal.present()
}
</script>

<style scoped>
.tab-icon {
  width: 25px;
  height: 25px;
  opacity: 0.6;
}

.tab-action-button {
  display: flex;
  flex: 1;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  background: transparent;
  color: #666;
  font-size: 12px;
}
</style>
