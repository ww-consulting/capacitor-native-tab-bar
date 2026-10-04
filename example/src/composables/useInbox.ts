import { computed, ref } from 'vue'

const unreadCount = ref(3)

/**
 * Demo inbox state that drives the badge of the inbox tab.
 * @returns The unread count, its badge text and actions to change it.
 */
export const useInbox = () => ({
  unreadCount,
  badgeText: computed(() => {
    if (unreadCount.value <= 0) return null
    return unreadCount.value > 99 ? '99+' : String(unreadCount.value)
  }),
  receive: () => unreadCount.value++,
  markAllRead: () => (unreadCount.value = 0),
})
