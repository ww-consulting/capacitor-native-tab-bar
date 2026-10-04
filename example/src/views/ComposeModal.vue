<template>
  <ion-header>
    <ion-toolbar>
      <ion-title>Compose</ion-title>
      <ion-buttons slot="end">
        <ion-button @click="close">Close</ion-button>
      </ion-buttons>
    </ion-toolbar>
  </ion-header>
  <ion-content>
    <div class="page-body">
      <p>The native bar is hidden while an Ionic overlay is open.</p>
      <ion-button @click="send">Send a message to the inbox</ion-button>
    </div>
  </ion-content>
</template>

<script setup lang="ts">
import { IonButton, IonButtons, IonContent, IonHeader, IonTitle, IonToolbar, modalController } from '@ionic/vue'
import { useInbox } from '../composables/useInbox'

const { receive } = useInbox()

const close = () => modalController.dismiss()

const send = async () => {
  receive()
  await close()
}
</script>

<style scoped>
.page-body {
  padding: 16px;
}
</style>
