<template>
  <ion-page>
    <ion-header>
      <ion-toolbar>
        <ion-title>{{ title }}</ion-title>
      </ion-toolbar>
    </ion-header>
    <ion-content>
      <div class="page-body">
        <p>{{ glassMode ? `Native glass bar active, height ${nativeHeight} pt.` : 'HTML tab bar (no iOS 26 or no native shell).' }}</p>
        <ion-button :router-link="`/tabs/${tab}/detail`">Open detail</ion-button>
        <template v-if="tab === 'inbox'">
          <p>Unread: {{ unreadCount }}</p>
          <ion-button fill="outline" @click="markAllRead">Mark all read</ion-button>
        </template>
        <p v-for="n in 30" :key="n" class="filler">Row {{ n }}: content scrolls under the glass bar but ends above it.</p>
      </div>
    </ion-content>
  </ion-page>
</template>

<script setup lang="ts">
import { IonButton, IonContent, IonHeader, IonPage, IonTitle, IonToolbar } from '@ionic/vue'
import { useInbox } from '../composables/useInbox'
import { useNativeTabBar } from '../composables/useNativeTabBar'

defineProps<{ tab: string; title: string }>()

const { glassMode, nativeHeight } = useNativeTabBar()
const { unreadCount, markAllRead } = useInbox()
</script>

<style scoped>
.page-body {
  padding: 16px 16px calc(16px + var(--native-tab-bar-height, 0px));
}

.filler {
  color: #888;
}
</style>
