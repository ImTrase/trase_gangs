<script lang="ts">
  import { onMount } from 'svelte';
  import { fade, fly } from 'svelte/transition';
  import { fetchNui } from '../../utils/fetchNui';
  
  // Icons
  import FileIcon from "virtual:icons/mdi/file-document-outline";
  import ClockIcon from "virtual:icons/mdi/clock-outline";
  import AccountIcon from "virtual:icons/mdi/account";
  import ShieldIcon from "virtual:icons/mdi/shield-account";
  import PlusIcon from "virtual:icons/mdi/plus";
  import MinusIcon from "virtual:icons/mdi/minus";
  import PencilIcon from "virtual:icons/mdi/pencil";
  import CrownIcon from "virtual:icons/mdi/crown";
  import TrashIcon from "virtual:icons/mdi/delete";

  export let gangData: any = {
    gang: null,
    members: [],
    ranks: [],
    stats: {},
    isOwner: false,
    hasManagePermission: false,
    playerIdentifier: null
  };

  interface AuditLog {
    id: number;
    gang_id: number;
    actor_identifier: string;
    action: string;
    target_identifier: string;
    details: string;
    created_at: string;
  }

  let logs: AuditLog[] = [];
  let loading = true;
  let limit = 50;

  onMount(async () => {
    await loadAuditLogs();
  });

  async function loadAuditLogs() {
    loading = true;
    try {
      console.log('[AuditLog] Fetching logs with limit:', limit);
      const response = await fetchNui('getAuditLogs', { limit });
      console.log('[AuditLog] Raw response:', response);
      console.log('[AuditLog] Response type:', typeof response);
      console.log('[AuditLog] Is array?', Array.isArray(response));
      
      if (response && Array.isArray(response)) {
        logs = response;
        console.log('[AuditLog] Loaded', logs.length, 'logs');
        if (logs.length > 0) {
          console.log('[AuditLog] First log:', logs[0]);
        }
      } else {
        console.error('[AuditLog] Response is not an array:', response);
      }
    } catch (e) {
      console.error('[AuditLog] Failed to load audit logs:', e);
    } finally {
      loading = false;
    }
  }

  function formatDate(dateString: string): string {
    if (!dateString) return 'Unknown';
    const date = new Date(dateString);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d ago`;
    if (hours > 0) return `${hours}h ago`;
    if (minutes > 0) return `${minutes}m ago`;
    return `${seconds}s ago`;
  }

  function getActionIcon(action: string) {
    if (action.includes('created') || action.includes('invited') || action.includes('added')) return PlusIcon;
    if (action.includes('deleted') || action.includes('removed') || action.includes('kicked')) return MinusIcon;
    if (action.includes('updated') || action.includes('changed') || action.includes('renamed')) return PencilIcon;
    if (action.includes('rank')) return CrownIcon;
    return FileIcon;
  }

  function getActionColor(action: string): string {
    if (action.includes('created') || action.includes('invited') || action.includes('added')) return 'success';
    if (action.includes('deleted') || action.includes('removed') || action.includes('kicked')) return 'danger';
    if (action.includes('updated') || action.includes('changed') || action.includes('renamed')) return 'warning';
    return 'info';
  }

  function formatAction(action: string): string {
    return action
      .split('_')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  function getActorName(identifier: string): string {
    const member = gangData.members.find((m: any) => m.identifier === identifier);
    return member ? member.name : identifier;
  }

  async function loadMore() {
    limit += 50;
    await loadAuditLogs();
  }

  $: sortedLogs = [...logs].sort((a, b) => 
    new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  );
</script>

<div class="audit-log-page" in:fade={{ duration: 200 }}>
  <!-- Header -->
  <div class="header" in:fly={{ y: -20, duration: 250, delay: 50 }}>
    <div class="header-content">
      <FileIcon class="header-icon" />
      <div>
        <h2>Audit Log</h2>
        <p>{logs.length} recent activities</p>
      </div>
    </div>
  </div>

  <!-- Timeline -->
  {#if loading}
    <div class="loading" in:fade={{ duration: 200 }}>
      <div class="spinner"></div>
      <p>Loading audit logs...</p>
    </div>
  {:else if logs.length === 0}
    <div class="empty-state" in:fly={{ y: 20, duration: 250, delay: 150 }}>
      <FileIcon class="empty-icon" />
      <h3>No Activity Yet</h3>
      <p>Gang activity will appear here</p>
    </div>
  {:else}
    <div class="timeline" in:fly={{ y: 20, duration: 250, delay: 150 }}>
      {#each sortedLogs as log, i (log.id)}
        <div class="timeline-item" in:fly={{ y: 20, duration: 250, delay: 200 + (i * 20) }}>
          <div class="timeline-marker" class:success={getActionColor(log.action) === 'success'}
               class:danger={getActionColor(log.action) === 'danger'}
               class:warning={getActionColor(log.action) === 'warning'}
               class:info={getActionColor(log.action) === 'info'}>
            <svelte:component this={getActionIcon(log.action)} />
          </div>
          
          <div class="timeline-content">
            <div class="timeline-header">
              <div class="timeline-action">
                <span class="action-text">{formatAction(log.action)}</span>
                {#if log.details}
                  <span class="action-details">· {log.details}</span>
                {/if}
              </div>
              <div class="timeline-time">
                <ClockIcon />
                <span>{formatDate(log.created_at)}</span>
              </div>
            </div>
            
            <div class="timeline-actors">
              <div class="actor">
                <AccountIcon />
                <span>{getActorName(log.actor_identifier)}</span>
              </div>
              {#if log.target_identifier && log.target_identifier !== ''}
                <span class="arrow">→</span>
                <div class="actor target">
                  <AccountIcon />
                  <span>{getActorName(log.target_identifier)}</span>
                </div>
              {/if}
            </div>
          </div>
        </div>
      {/each}
    </div>

    {#if logs.length >= limit}
      <div class="load-more">
        <button class="btn btn-secondary" on:click={loadMore}>
          Load More
        </button>
      </div>
    {/if}
  {/if}
</div>

<style>
  .audit-log-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
    padding: 12px;
  }

  /* Header */
  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .header-content {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .header-icon {
    width: 48px;
    height: 48px;
    padding: 12px;
    background: linear-gradient(135deg, rgba(59, 130, 246, 0.15), rgba(37, 99, 235, 0.15));
    border-radius: 12px;
    color: #3b82f6;
  }

  .header h2 {
    margin: 0;
    font-size: 28px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .header p {
    margin: 4px 0 0 0;
    font-size: 14px;
    color: var(--text-secondary);
  }

  /* Loading */
  .loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    gap: 16px;
  }

  .spinner {
    width: 40px;
    height: 40px;
    border: 3px solid var(--border);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .loading p {
    color: var(--text-secondary);
    font-size: 14px;
  }

  /* Empty State */
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    gap: 16px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
  }

  .empty-icon {
    width: 64px;
    height: 64px;
    padding: 16px;
    background: rgba(59, 130, 246, 0.1);
    border-radius: 50%;
    color: #3b82f6;
  }

  .empty-state h3 {
    margin: 0;
    font-size: 20px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .empty-state p {
    margin: 0;
    font-size: 14px;
    color: var(--text-secondary);
  }

  /* Timeline */
  .timeline {
    display: flex;
    flex-direction: column;
    gap: 0;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 24px;
    max-height: 550px;
    overflow-y: auto;

    /* Scrollbar to match the UI */
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* Scrollbar to match the UI */
    .timeline::-webkit-scrollbar {
        width: 8px;
    }

    .timeline::-webkit-scrollbar-thumb {
        /* blue to match the UI */
        background-color: rgb(5, 105, 255);
        border-radius: 4px;
    }

    /* hover */
    .timeline::-webkit-scrollbar-thumb:hover {
        background-color: rgb(3, 80, 204);
    }

  .timeline-item {
    display: flex;
    gap: 16px;
    padding: 16px 0;
    border-bottom: 1px solid var(--border);
    position: relative;
  }

  .timeline-item:last-child {
    border-bottom: none;
  }

  .timeline-item:not(:last-child)::after {
    content: '';
    position: absolute;
    left: 19px;
    top: 56px;
    bottom: -16px;
    width: 2px;
    background: var(--border);
  }

  .timeline-marker {
    flex-shrink: 0;
    width: 40px;
    height: 40px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    border: 2px solid var(--border);
    background: var(--bg-base);
    color: var(--text-secondary);
    position: relative;
    z-index: 1;
  }

  .timeline-marker.success {
    background: rgba(34, 197, 94, 0.1);
    border-color: #22c55e;
    color: #22c55e;
  }

  .timeline-marker.danger {
    background: rgba(239, 68, 68, 0.1);
    border-color: #ef4444;
    color: #ef4444;
  }

  .timeline-marker.warning {
    background: rgba(234, 179, 8, 0.1);
    border-color: #eab308;
    color: #eab308;
  }

  .timeline-marker.info {
    background: rgba(59, 130, 246, 0.1);
    border-color: #3b82f6;
    color: #3b82f6;
  }

  .timeline-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .timeline-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
  }

  .timeline-action {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .action-text {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .action-details {
    font-size: 14px;
    color: var(--text-secondary);
  }

  .timeline-time {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    color: var(--text-dim);
    white-space: nowrap;
  }

  .timeline-time :global(svg) {
    width: 14px;
    height: 14px;
  }

  .timeline-actors {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .actor {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    background: var(--bg-base);
    border: 1px solid var(--border);
    border-radius: 6px;
    font-size: 13px;
    color: var(--text-secondary);
  }

  .actor :global(svg) {
    width: 14px;
    height: 14px;
  }

  .actor.target {
    background: rgba(59, 130, 246, 0.05);
    border-color: rgba(59, 130, 246, 0.2);
  }

  .arrow {
    color: var(--text-dim);
    font-size: 14px;
  }

  /* Load More */
  .load-more {
    display: flex;
    justify-content: center;
    padding: 16px;
  }

  .btn {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 20px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 150ms ease;
    font-family: 'Inter', sans-serif;
  }

  .btn-secondary {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--text-primary);
  }

  .btn-secondary:hover {
    background: rgba(255, 255, 255, 0.05);
    transform: translateY(-1px);
  }

  @media (max-width: 768px) {
    .timeline-header {
      flex-direction: column;
      align-items: flex-start;
    }

    .timeline-actors {
      flex-direction: column;
      align-items: flex-start;
    }
  }
</style>
