import { IonicVue } from '@ionic/vue'
import { createApp } from 'vue'
import App from './App.vue'
import { detectNativeTabBar } from './composables/useNativeTabBar'
import { router } from './router'

import '@ionic/vue/css/core.css'
import '@ionic/vue/css/normalize.css'
import '@ionic/vue/css/structure.css'
import '@ionic/vue/css/typography.css'
import './theme.css'

const start = async () => {
  // Glass mode must be settled before TabsPage sets up, since it decides once
  // whether the native bar is synced.
  await detectNativeTabBar()

  const app = createApp(App).use(IonicVue).use(router)
  await router.isReady()
  app.mount('#app')
}

void start()
