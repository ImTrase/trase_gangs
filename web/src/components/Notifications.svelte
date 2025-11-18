<script lang="ts">
  import { scale } from 'svelte/transition';
  import { useNuiEvent } from "../utils/useNuiEvent";
  
  // Icons
  import CheckCircleIcon from "virtual:icons/mdi/check-circle";
  import AlertCircleIcon from "virtual:icons/mdi/alert-circle";
  import InfoCircleIcon from "virtual:icons/mdi/information";
  import CloseIcon from "virtual:icons/mdi/close";

  type NotificationType = "success" | "error" | "info";

  interface Notification {
    id: number;
    type: NotificationType;
    title: string;
    description: string;
  }

  let notifications: Notification[] = [];
  let notificationId = 0;

  // Listen for notification events from Lua
  useNuiEvent("notify", (data: any) => {
    console.log('[Notifications] Received:', data);
    if (data && data.type && data.title && data.description) {
      showNotification(data.type, data.title, data.description);
    }
  });

  function showNotification(type: NotificationType, title: string, description: string) {
    console.log('[Notifications] Showing:', type, title, description);
    const id = notificationId++;
    notifications = [...notifications, { id, type, title, description }];
    
    setTimeout(() => {
      notifications = notifications.filter(n => n.id !== id);
    }, 5000);
  }

  function dismissNotification(id: number) {
    notifications = notifications.filter(n => n.id !== id);
  }
</script>

<!-- Notifications Container -->
<div class="notifications-container">
  {#each notifications as notification (notification.id)}
    <div class="notification notification-{notification.type}" transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="notification-icon">
        {#if notification.type === 'success'}
          <CheckCircleIcon />
        {:else if notification.type === 'error'}
          <AlertCircleIcon />
        {:else}
          <InfoCircleIcon />
        {/if}
      </div>
      <div class="notification-content">
        <div class="notification-title">{notification.title}</div>
        <div class="notification-description">{notification.description}</div>
      </div>
      <button class="notification-close" on:click={() => dismissNotification(notification.id)}>
        <CloseIcon />
      </button>
    </div>
  {/each}
</div>

<style>
  .notifications-container {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 10000;
    display: flex;
    flex-direction: column;
    gap: 12px;
    pointer-events: none;
    font-family: 'MaisonNeue', sans-serif;
  }

  .notification {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 16px;
    background: #20202a;
    border: 1px solid #27272f;
    border-radius: 12px;
    min-width: 350px;
    max-width: 420px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    pointer-events: all;
  }

  .notification-success {
    border-left: 4px solid #22c55e;
  }

  .notification-error {
    border-left: 4px solid #ef4444;
  }

  .notification-info {
    border-left: 4px solid #3b82f6;
  }

  .notification-icon {
    width: 24px;
    height: 24px;
    flex-shrink: 0;
  }

  .notification-success .notification-icon {
    color: #22c55e;
  }

  .notification-error .notification-icon {
    color: #ef4444;
  }

  .notification-info .notification-icon {
    color: #3b82f6;
  }

  .notification-content {
    flex: 1;
  }

  .notification-title {
    font-size: 14px;
    font-weight: 600;
    color: #ffffff;
    margin-bottom: 4px;
  }

  .notification-description {
    font-size: 13px;
    font-weight: 400;
    color: #a0a0ab;
    line-height: 1.4;
  }

  .notification-close {
    width: 20px;
    height: 20px;
    display: grid;
    place-items: center;
    background: transparent;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    color: #a0a0ab;
    flex-shrink: 0;
    transition: all 150ms ease;
  }

  .notification-close:hover {
    background: rgba(255, 255, 255, 0.1);
    color: #ffffff;
  }
</style>
