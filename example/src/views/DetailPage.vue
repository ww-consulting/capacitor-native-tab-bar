<template>
  <ion-page>
    <ion-header>
      <ion-toolbar>
        <ion-buttons slot="start">
          <ion-back-button :default-href="`/tabs/${tab}`" />
        </ion-buttons>
        <ion-title>Detail</ion-title>
      </ion-toolbar>
    </ion-header>
    <ion-content>
      <div class="page-body">
        <p>Switch tabs and come back: the tab keeps this page. Tap the selected tab again to return to its root.</p>
      </div>
    </ion-content>
  </ion-page>
</template>

<script setup lang="ts">
import { IonBackButton, IonButtons, IonContent, IonHeader, IonPage, IonTitle, IonToolbar } from '@ionic/vue'

defineProps<{ tab: string }>()
</script>

<style scoped>
.page-body {
  padding: 16px;
}
</style>
