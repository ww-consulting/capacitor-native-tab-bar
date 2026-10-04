import { createRouter, createWebHistory } from '@ionic/vue-router'
import DemoPage from './views/DemoPage.vue'
import DetailPage from './views/DetailPage.vue'
import TabsPage from './views/TabsPage.vue'

const tabRoutes = (tab: string, title: string) => [
  { path: tab, component: DemoPage, props: { tab, title } },
  { path: `${tab}/detail`, component: DetailPage, props: { tab } },
]

export const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', redirect: '/tabs/home' },
    {
      path: '/tabs/',
      component: TabsPage,
      children: [
        { path: '', redirect: '/tabs/home' },
        ...tabRoutes('home', 'Home'),
        ...tabRoutes('search', 'Search'),
        ...tabRoutes('inbox', 'Inbox'),
      ],
    },
  ],
})
