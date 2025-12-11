<script lang="ts">
  import { fade, scale } from "svelte/transition";
  import { cubicOut } from "svelte/easing";
  import { useNuiEvent } from "../utils/useNuiEvent";
  import { fetchNui } from "../utils/fetchNui";
  import { t } from '../utils/translate';


  import "../theme.css";

  // Icons
  import HomeIcon from "virtual:icons/mdi/home";
  import UsersIcon from "virtual:icons/mdi/account-group";
  import RankIcon from "virtual:icons/mdi/crown";
  import UnlockIcon from "virtual:icons/mdi/lock-open";
  import AuditIcon from "virtual:icons/mdi/file-document";
  import GangIcon from "virtual:icons/mdi/shield-account";
  import CloseIcon from "virtual:icons/mdi/close";
  import CheckCircleIcon from "virtual:icons/mdi/check-circle";
  import AlertCircleIcon from "virtual:icons/mdi/alert-circle";
  import InfoCircleIcon from "virtual:icons/mdi/information";

  // Pages
  import DashboardPage from "./pages/Dashboard.svelte";
  import ManageRanks from "./pages/ManageRanks.svelte";
  import Members from "./pages/Members.svelte";
  import Recruiting from "./pages/Recruiting.svelte";
  import GangWars from "./pages/GangWars.svelte";
  import AuditLog from "./pages/AuditLog.svelte";

  export let open = false;
  let testDriveMode = false;

  type PageKey =
    | "home"
    | "members"
    | "ranks"
    | "unlocks"
    | "gangwars"
    | "auditlog";

  type NotificationType = "success" | "error" | "info";

  interface Notification {
    id: number;
    type: NotificationType;
    title: string;
    description: string;
  }

  let page: PageKey = "home";

  let me = { name: "Trase", tag: "ID: 25", role: "VIP+" };
  $: isVIP = me.role === "VIP" || me.role === "VIP+";

  let notifications: Notification[] = [];
  let notificationId = 0;

  // Gang data
  let gangData = {
    gang: null,
    members: [],
    ranks: [],
    stats: {},
    isOwner: false,
    hasManagePermission: false,
    playerIdentifier: null
  };

  const tabs: Array<{ key: PageKey; labelKey: string; label: string; icon: any; gated?: boolean }> = [
    { key: "home", labelKey: 'dashboard.page_home_title', label: "Dashboard", icon: HomeIcon },
    { key: "ranks", labelKey: 'page.ranks.title', label: "Ranks", icon: RankIcon },
    { key: "members", labelKey: 'page.members.title', label: "Members", icon: UsersIcon },
    { key: "unlocks", labelKey: 'page.recruit.title', label: "Recruiting", icon: UnlockIcon },
    { key: "gangwars", labelKey: 'page.gangwars.title', label: "Gang Wars", icon: GangIcon },
    { key: "auditlog", labelKey: 'page.auditlog.title', label: "Audit Log", icon: AuditIcon }
  ];

  const titles: Record<PageKey, { titleKey: string; title: string; subtitleKey: string; subtitle: string }> = {
    home: { titleKey: 'dashboard.page_home_title', title: 'Dashboard', subtitleKey: 'dashboard.page_home_subtitle', subtitle: 'Gang overview and statistics' },
    members: { titleKey: 'page.members.title', title: 'Members', subtitleKey: 'page.members.subtitle', subtitle: 'Manage gang members' },
    ranks: { titleKey: 'page.ranks.title', title: 'Ranks', subtitleKey: 'page.ranks.subtitle', subtitle: 'Configure gang ranks' },
    unlocks: { titleKey: 'page.recruit.title', title: 'Recruiting', subtitleKey: 'page.recruit.subtitle', subtitle: 'Gang recruitment' },
    gangwars: { titleKey: 'page.gangwars.title', title: 'Gang Wars', subtitleKey: 'page.gangwars.subtitle', subtitle: 'Territory and warfare' },
    auditlog: { titleKey: 'page.auditlog.title', title: 'Audit Log', subtitleKey: 'page.auditlog.subtitle', subtitle: 'Recent gang activity' }
  };

  useNuiEvent("dashboard:open", (data: any) => {
    console.log('[Dashboard] Received data:', data);
    open = true;
    testDriveMode = false;
    page = (data.page as PageKey) ?? "home";
    me = data.me ?? me;
    
    // Store gang data
    if (data.gang) {
      gangData = {
        gang: data.gang,
        members: data.members || [],
        ranks: data.ranks || [],
        stats: data.stats || {},
        isOwner: data.isOwner || false,
        hasManagePermission: data.hasManagePermission || false,
        playerIdentifier: data.playerIdentifier
      };
    }
  });

  useNuiEvent("updateGangData", (data: any) => {
    console.log('[Dashboard] Received gang update:', data);
    if (data && gangData.gang) {
        gangData.gang = { ...gangData.gang, ...data };
        if (data.stats) gangData.stats = data.stats;
        if (data.ranks) gangData.ranks = data.ranks;
        // Trigger reactivity
        gangData = gangData;
    }
  });

  function close() {
    open = false;
    testDriveMode = false;
    fetchNui("dashboard:closeUI");
  }

  useNuiEvent("dealership:openTestDrive", (data: any) => {
    open = false;
    testDriveMode = true;
    me = data.me ?? me;
  });

  useNuiEvent("dashboard:close", () => {
    open = false;
    testDriveMode = false;
    fetchNui("dashboard:closeUI");
  });

  useNuiEvent("notify", (data: any) => {
    console.log('[Dashboard] Notification received:', data);
    if (data && data.type && data.title && data.description) {
      showNotification(data.type, data.title, data.description);
    }
  });

  function showNotification(type: NotificationType, title: string, description: string) {
    const id = notificationId++;
    notifications = [...notifications, { id, type, title, description }];
    
    setTimeout(() => {
      notifications = notifications.filter(n => n.id !== id);
    }, 5000);
  }

  function dismissNotification(id: number) {
    notifications = notifications.filter(n => n.id !== id);
  }

  async function refreshGangData() {
    console.log('[Dashboard] refreshGangData called');
    try {
      const response = await fetchNui('refreshGangData');
      console.log('[Dashboard] refreshGangData response:', response);
      if (response && response.success) {
        const oldRanksCount = gangData.ranks.length;
        // Force Svelte reactivity by creating completely new object references
        gangData = {
          gang: { ...response.data.gang },
          members: [...(response.data.members || [])],
          ranks: [...(response.data.ranks || [])],
          stats: { ...(response.data.stats || {}) },
          isOwner: response.data.isOwner || false,
          hasManagePermission: response.data.hasManagePermission || false,
          playerIdentifier: response.data.playerIdentifier || null
        };
        console.log('[Dashboard] Gang data refreshed - old ranks:', oldRanksCount, 'new ranks:', gangData.ranks.length);
        console.log('[Dashboard] Ranks array:', gangData.ranks);
        console.log('[Dashboard] gangData object reference changed:', gangData);
      } else {
        console.error('[Dashboard] Refresh failed:', response);
      }
    } catch (e) {
      console.error('[Dashboard] Failed to refresh gang data:', e);
    }
  }

  function closeUI() {
    open = false;
    fetchNui("dashboard:closeUI");
  }

  function onKey(e: KeyboardEvent) {
    if (e.key === "Escape" && open) closeUI();
  }

  function selectTab(k: PageKey) {
    page = k;
  }
</script>

<svelte:window on:keydown={onKey} />

{#if open}
  <div>
    <!-- Dimmed oceanic backdrop -->
    <div
      class="backdrop"
      role="button"
      tabindex="0"
      aria-label={t('close','Close')}
      in:fade={{ duration: 160 }}
      out:fade={{ duration: 160 }}
      on:click={(e) => e.currentTarget === e.target && closeUI()}
      on:keydown={(e) => e.key === "Enter" && closeUI()}
    />

    <!-- Container -->
    <div class="wrap" in:fade={{ duration: 160 }} out:fade={{ duration: 120 }}>
      <div
        class="panel"
        in:scale={{ start: 0.97, duration: 180, easing: cubicOut }}
        out:scale={{ start: 0.97, duration: 140, easing: cubicOut }}
      >
        <!-- Sidebar -->
        <aside class="sidebar">
          <div class="brand">
            <div class="brand-icon-wrapper">
              <GangIcon class="brand-icon" />
            </div>
            <div class="brand-text">
              <strong>{gangData.gang?.label || t('dashboard.gang_manager','Gang Manager')}</strong>
              <span>{gangData.gang ? gangData.members.length + ' ' + t('members_label','members') : t('dashboard.manage_gang_subtitle','Manage and view your gang.')}</span>
            </div>
          </div>

          <div class="nav-section">
            <div class="nav-label">{t('sidebar_nav_overview','Overview')}</div>
            <nav class="nav" aria-label="Primary">
              {#each tabs as tab}
                <button
                  class="nav-item {page === tab.key ? 'active' : ''}"
                  on:click={() => selectTab(tab.key)}
                  aria-pressed={page === tab.key}
                >
                  <svelte:component this={tab.icon} />
                  <span>{t(tab.labelKey, tab.label)}</span>
                </button>
              {/each}
            </nav>
          </div>

          <div class="user-card">
            <div class="user-avatar">{me.name.charAt(0)}</div>
            <div class="user-info">
              <div class="user-name">{me.name}</div>
              <div class="user-role">{me.tag}</div>
            </div>
            <div class="user-id">#{me.tag.split(': ')[1] || '25'}</div>
          </div>
        </aside>

        <!-- Main Content -->
        <div class="main">
          <!-- Top bar -->
          <header class="topbar">
            <h1 class="page-title">{t(titles[page].titleKey, titles[page].title)}</h1>
            <button class="close-btn" on:click={closeUI} aria-label={t('close','Close')}>
              <CloseIcon class="close-icon" />
              <span>{t('close','Close')}</span>
            </button>
          </header>

          <!-- Content area -->
          <main class="content" role="region" aria-live="polite">
            {#if page === "home"}
              <DashboardPage {gangData} />
            {:else if page === "members"}
              <Members {gangData} />
            {:else if page === "ranks"}
              <ManageRanks {gangData} onRefresh={refreshGangData} />
            {:else if page === "unlocks"}
              <Recruiting {gangData} />
            {:else if page === "gangwars"}
              <GangWars {gangData} />
            {:else if page === "auditlog"}
              <AuditLog {gangData} />
            {/if}
          </main>
        </div>
      </div>
    </div>

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
  </div>
{/if}

<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

  /* Color Palette - Blue Theme */
  :root {
    --bg-dark: #0f0f17;
    --bg-panel: #18181f;
    --bg-sidebar: #1a1a22;
    --bg-elevated: #20202a;
    --accent: #6366f1;
    --accent-hover: #7c3aed;
    --accent-light: #818cf8;
    --text-primary: #ffffff;
    --text-secondary: #a0a0ab;
    --text-dim: #71717a;
    --border: #27272f;
    --border-light: #3a3a44;
  }

  * {
    box-sizing: border-box;
  }

  .backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.7);
    z-index: 999;
  }

  .wrap {
    position: fixed;
    inset: 0;
    display: grid;
    place-items: center;
    padding: 3vh 3vw;
    z-index: 1000;
  }

  .panel {
    width: 1400px;
    max-width: 95vw;
    height: 820px;
    max-height: 94vh;
    display: grid;
    grid-template-columns: 240px 1fr;
    background: var(--bg-panel);
    border-radius: 20px;
    overflow: hidden;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    color: var(--text-primary);
  }

  /* Sidebar */
  .sidebar {
    background: var(--bg-sidebar);
    display: flex;
    flex-direction: column;
    padding: 24px 16px;
    gap: 24px;
    border-right: 1px solid var(--border);
  }

  .brand {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 8px;
  }

  .brand-icon-wrapper {
    width: 48px;
    height: 48px;
    background: linear-gradient(135deg, var(--accent), var(--accent-hover));
    border-radius: 12px;
    display: grid;
    place-items: center;
    flex-shrink: 0;
  }

  .brand-icon {
    width: 28px;
    height: 28px;
    color: white;
  }

  .brand-text {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
  }

  .brand-text strong {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    line-height: 1.2;
  }

  .brand-text span {
    font-size: 11px;
    color: var(--text-dim);
    line-height: 1.3;
  }

  .nav-section {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .nav-label {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--text-dim);
    padding: 0 12px 4px;
  }

  .nav {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 12px;
    background: transparent;
    border: none;
    border-radius: 10px;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 150ms ease;
    font-size: 14px;
    font-weight: 500;
    text-align: left;
  }

  .nav-item:hover {
    background: rgba(255, 255, 255, 0.05);
    color: var(--text-primary);
  }

  .nav-item.active {
    background: linear-gradient(135deg, var(--accent), var(--accent-hover));
    color: white;
  }

  .nav-icon {
    width: 20px;
    height: 20px;
    flex-shrink: 0;
    opacity: 0.9;
  }

  .nav-item.active .nav-icon {
    opacity: 1;
  }

  .user-card {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    background: var(--bg-elevated);
    border-radius: 12px;
    border: 1px solid var(--border);
  }

  .user-avatar {
    width: 36px;
    height: 36px;
    background: linear-gradient(135deg, var(--accent), var(--accent-hover));
    border-radius: 10px;
    display: grid;
    place-items: center;
    font-weight: 700;
    font-size: 14px;
    flex-shrink: 0;
  }

  .user-info {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .user-name {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .user-role {
    font-size: 11px;
    color: var(--text-dim);
  }

  .user-id {
    font-size: 11px;
    color: var(--text-dim);
    font-weight: 600;
  }

  /* Main Content */
  .main {
    display: grid;
    grid-template-rows: auto 1fr;
    background: var(--bg-dark);
  }

  .topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20px 32px;
    background: var(--bg-panel);
    border-bottom: 1px solid var(--border);
  }

  .page-title {
    font-size: 24px;
    font-weight: 700;
    margin: 0;
    color: var(--text-primary);
  }

  .close-btn {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 20px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-light);
    border-radius: 8px;
    color: var(--text-primary);
    font-size: 13px;
    font-weight: 500;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    cursor: pointer;
    transition: all 150ms ease;
  }

  .close-icon {
    width: 16px;
    height: 16px;
  }

  .close-btn:hover {
    background: var(--bg-sidebar);
    border-color: var(--border-light);
  }

  .close-btn:active {
    transform: scale(0.98);
  }

  /* Content Area */
  .content {
    padding: 20px;
    overflow-y: auto;
    overflow-x: hidden;
  }

  .content-placeholder {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    gap: 12px;
    color: var(--text-secondary);
  }

  .content-placeholder h2 {
    font-size: 20px;
    font-weight: 600;
    margin: 0;
    color: var(--text-primary);
  }

  .content-placeholder p {
    font-size: 14px;
    margin: 0;
    color: var(--text-dim);
  }

  /* Scrollbar */
  ::-webkit-scrollbar {
    width: 8px;
    height: 8px;
  }

  ::-webkit-scrollbar-track {
    background: transparent;
  }

  ::-webkit-scrollbar-thumb {
    background: var(--border-light);
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb:hover {
    background: #4a4a54;
  }

  /* Responsive */
  @media (max-width: 768px) {
    .panel {
      grid-template-columns: 1fr;
    }

    .sidebar {
      display: none;
    }
  }

  /* Notifications */
  .notifications-container {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 10000;
    display: flex;
    flex-direction: column;
    gap: 12px;
    pointer-events: none;
  }

  .notification {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 16px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
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
    color: var(--text-primary);
    margin-bottom: 4px;
  }

  .notification-description {
    font-size: 13px;
    color: var(--text-secondary);
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
    color: var(--text-secondary);
    flex-shrink: 0;
    transition: all 150ms ease;
  }

  .notification-close:hover {
    background: rgba(255, 255, 255, 0.1);
    color: var(--text-primary);
  }
</style>
