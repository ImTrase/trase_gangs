<script context="module" lang="ts">
  export type NavItem = { key: string; label: string; icon: any };
</script>

<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from '../utils/translate';
  import ListIcon from "virtual:icons/mdi/view-dashboard";

  export let items: NavItem[] = [];
  export let active = "dashboard";
  export let me = { name: "Trase", tag: "#20", role: "Cartel", icon: "https://i.pravatar.cc/300" };
  export let isVIP = false;
  
  const dispatch = createEventDispatcher();
  const click = (key: string) => {
    // Prevent navigation to VIP if user is not VIP
    if (key === 'vip' && !isVIP) return;
    dispatch('select', key);
  };
</script>

<aside class="sidebar">
  <div class="brand">
    <div class="brand-ico"><ListIcon /></div>
    <div>
      <h3>{t('sidebar_brand_title', 'Dashboard')}</h3>
      <p>{t('sidebar_brand_subtitle', 'Manage your settings.')}</p>
    </div>
  </div>

  <div>
    <p class="nav-head">{t('sidebar_nav_overview', 'Overview')}</p>
    {#each items as n}
      <button
        class="nav-item {active === n.key ? 'active' : ''}"
        class:disabled={n.key === 'vip' && !isVIP}
        disabled={n.key === 'vip' && !isVIP}
        on:click={() => click(n.key)}
      >
        <span class="ico"><svelte:component this={n.icon} /></span>
        <span>{n.label}</span>
        {#if n.key === 'vip' && !isVIP}
          <span class="vip-badge">{t('sidebar_vip_only', 'VIP Only')}</span>
        {/if}
      </button>
    {/each}
  </div>

  <div class="profile">
    <div class="ava">
      <img src={me.icon} alt="Avatar" style="width:100%; height:100%; border-radius:8px;" />
    </div>
    <div>
      <div class="name">{me.name}</div>
      <div class="role">{me.role}</div>
    </div>
    <span class="muted">{me.tag}</span>
  </div>
</aside>

<style>
  .sidebar {
    background: #0f0d14aa;
    border-right: 1px solid var(--border);
    padding: 16px;
    display: grid;
    grid-template-rows: auto 1fr auto;
    gap: 16px;
  }
  .brand {
    display: flex;
    gap: 10px;
    align-items: center;
  }
  .brand-ico {
    width: 44px;
    height: 44px;
    display: grid;
    place-items: center;
    border-radius: 12px;
    background: #7a3cff20;
    border: 1px solid #7a3cff40;
  }
  .brand h3 {
    margin: 0;
    font-size: 18px;
  }
  .brand p {
    margin: 0;
    color: var(--muted);
    font-size: 12px;
  }
  .nav-head {
    margin: 16px 0 6px;
    color: var(--muted);
    font-size: 12px;
  }
  .nav-item {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    padding: 10px 12px;
    border-radius: 10px;
    border: 1px solid transparent;
    background: transparent;
    color: var(--text);
    cursor: pointer;
    margin-top: 5px;
    font-family: 'MaisonNeue', Courier, monospace;
  }
  .nav-item .ico {
    display: grid;
    place-items: center;
    opacity: 0.9;
  }
  .nav-item:hover {
    background: #ffffff10;
    border: none;
  }
  .nav-item.active {
    background: #7a3cff22;
    border: 1px solid #7a3cff44;
  }
  
  .nav-item.disabled {
    opacity: 0.5;
    cursor: not-allowed;
    color: var(--text-muted);
  }
  
  .nav-item.disabled:hover {
    background: transparent;
    border: 1px solid transparent;
  }
  
  .vip-badge {
    margin-left: auto;
    font-size: 10px;
    padding: 2px 6px;
    border-radius: 4px;
    background: rgba(255, 215, 0, 0.15);
    border: 1px solid rgba(255, 215, 0, 0.3);
    color: #FFD700;
    font-weight: 600;
  }
  
  .profile {
    margin-top: 6px;
    display: grid;
    grid-template-columns: 34px 1fr auto;
    gap: 8px;
    align-items: center;
    padding: 10px;
    border: 1px solid var(--border);
    border-radius: 12px;
    background: #0b0a10;
  }
  .profile .ava {
    width: 34px;
    height: 34px;
    border-radius: 10px;
    background: #ffffff12;
    border: 1px solid var(--border);
  }
  .profile .name {
    font-weight: 700;
    font-size: 13px;
  }
  .profile .role {
    font-size: 12px;
    color: var(--muted);
  }
</style>
