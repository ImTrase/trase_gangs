<script lang="ts">
  import { onMount } from 'svelte';
  import { fade, fly, scale } from 'svelte/transition';
  import { fetchNui } from '../../utils/fetchNui';
  import { locales } from '../../stores/localeStore';
  import { t } from '../../utils/translate';

  // Icons
  import UserPlusIcon from "virtual:icons/mdi/account-plus";
  import SendIcon from "virtual:icons/mdi/send";
  import CloseIcon from "virtual:icons/mdi/close";
  import CheckIcon from "virtual:icons/mdi/check";
  import IdCardIcon from "virtual:icons/mdi/card-account-details";
  import RefreshIcon from "virtual:icons/mdi/refresh";

  interface NearbyPlayer {
    id: number;
    name: string;
    distance: number;
  }

  let nearbyPlayers: NearbyPlayer[] = [
    // { id: 1, name: 'Tommy Jackson', distance: 5.2 },
    // { id: 2, name: 'Marcus Brown', distance: 8.7 },
    // { id: 3, name: 'Lisa Anderson', distance: 12.4 },
    // { id: 4, name: 'David Wilson', distance: 15.8 },
    // { id: 5, name: 'Rachel Green', distance: 18.3 },
    // { id: 6, name: 'James Miller', distance: 22.1 },
    // { id: 7, name: 'Sophie Turner', distance: 25.6 },
    // { id: 8, name: 'Kevin Hart', distance: 29.4 },
  ];

  let showInviteModal = false;
  let showConfirmModal = false;
  let inviteServerId = '';
  let isRefreshing = false;
  let selectedPlayer: NearbyPlayer | null = null;

  onMount(async () => {
    // Fetch nearby players from server
    await refreshNearbyPlayers();
  });

  async function refreshNearbyPlayers() {
    isRefreshing = true;
    try {
      const data = await fetchNui('getNearbyPlayers');
      if (data?.players) {
        nearbyPlayers = data.players;
      }
    } catch (e) {
      console.log('Using mock data for development');
    } finally {
      isRefreshing = false;
    }
  }

  function openInviteModal() {
    inviteServerId = '';
    showInviteModal = true;
  }

  function closeInviteModal() {
    showInviteModal = false;
    inviteServerId = '';
  }

  function openConfirmModal(player: NearbyPlayer) {
    selectedPlayer = player;
    showConfirmModal = true;
  }

  function closeConfirmModal() {
    showConfirmModal = false;
    selectedPlayer = null;
  }

  async function confirmInvite() {
    if (!selectedPlayer) return;

    try {
      const response = await fetchNui('inviteMember', { targetServerId: selectedPlayer.id });
      console.log(`Invited ${selectedPlayer.name}`);
      
      if (response?.success) {
        fetchNui('trase_gangs:notify', {
          title: $locales['invite_sent_title'] || 'Invite Sent',
          description: $locales['invite_sent_desc'] || 'Gang invite has been sent',
          type: 'success'
        });
      } else {
        const errorMessage = response?.result ? ($locales[response.result] || response.result) : ($locales['invite_failed'] || 'Failed to send invite');
        fetchNui('trase_gangs:notify', {
          title: $locales['error'] || 'Error',
          description: errorMessage,
          type: 'error'
        });
      }
      
      closeConfirmModal();
    } catch (e) {
      console.error('Failed to invite player:', e);
      fetchNui('trase_gangs:notify', {
        title: $locales['error'] || 'Error',
        description: $locales['invite_failed'] || 'Failed to send gang invite',
        type: 'error'
      });
      closeConfirmModal();
    }
  }

  async function inviteByServerId() {
    const serverId = parseInt(inviteServerId);
    
    if (isNaN(serverId) || serverId <= 0) {
      fetchNui('trase_gangs:notify', {
        title: $locales['error'] || 'Error',
        description: 'Please enter a valid server ID',
        type: 'error'
      });
      return;
    }

    try {
      const response = await fetchNui('inviteMember', { targetServerId: serverId });
      
      if (response?.success) {
        fetchNui('trase_gangs:notify', {
          title: $locales['invite_sent_title'] || 'Invite Sent',
          description: $locales['invite_sent_desc'] || 'Gang invite has been sent',
          type: 'success'
        });
      } else {
        const errorMessage = response?.result ? ($locales[response.result] || response.result) : ($locales['invite_failed'] || 'Failed to send invite');
        fetchNui('trase_gangs:notify', {
          title: $locales['error'] || 'Error',
          description: errorMessage,
          type: 'error'
        });
      }
      
      closeInviteModal();
    } catch (e) {
      console.error('Failed to invite player by ID:', e);
      fetchNui('trase_gangs:notify', {
        title: $locales['error'] || 'Error',
        description: $locales['invite_failed'] || 'Failed to send gang invite',
        type: 'error'
      });
      closeInviteModal();
    }
  }

  function formatDistance(distance: number): string {
    return `${distance.toFixed(1)}m`;
  }
</script>

<div class="recruiting-page" in:fade={{ duration: 200 }}>
  <!-- Header -->
  <div class="header" in:fly={{ y: -20, duration: 250, delay: 50 }}>
    <div class="header-content">
      <UserPlusIcon class="header-icon" />
      <div>
        <h2>{t('recruit.title','Recruit Members')}</h2>
        <p>{nearbyPlayers.length} {t('recruit.nearby_players','nearby players')}</p>
      </div>
    </div>
    <div class="header-actions">
        <button 
        class="action-btn refresh-btn" 
        on:click={refreshNearbyPlayers}
        disabled={isRefreshing}
        title={t('recruit.refresh_title','Refresh nearby players')}
      >
        <span class="refresh-icon" class:spinning={isRefreshing}>
          <RefreshIcon />
        </span>
        <span>{t('refresh','Refresh')}</span>
      </button>
      <button class="invite-btn" on:click={openInviteModal}>
        <IdCardIcon />
        <span>{t('recruit.invite_via_id','Invite via ID')}</span>
      </button>
    </div>
  </div>

  <!-- Nearby Players Table -->
  <div class="table-container" in:fly={{ y: 20, duration: 250, delay: 150 }}>
    <table>
      <thead>
        <tr>
          <th>{t('server_id','Server ID')}</th>
          <th>{t('player_name','Player Name')}</th>
          <th>{t('distance_label','Distance')}</th>
          <th>{t('action_label','Action')}</th>
        </tr>
      </thead>
      <tbody>
        {#if nearbyPlayers.length === 0}
          <tr>
            <td colspan="4" class="empty-state">
              <div class="empty-content">
                <UserPlusIcon class="empty-icon" />
                <p>{t('recruit.empty_title','No nearby players found')}</p>
                <span>{t('recruit.empty_action','Try refreshing or invite by server ID')}</span>
              </div>
            </td>
          </tr>
        {:else}
          {#each nearbyPlayers as player, i (player.id)}
            <tr in:fly={{ y: 20, duration: 250, delay: 200 + (i * 30) }}>
              <td class="id-cell">
                <div class="player-id">#{player.id}</div>
              </td>
              <td class="name-cell">
                <div class="player-name">{player.name}</div>
              </td>
              <td class="distance-cell">
                <div class="distance-badge">
                  {formatDistance(player.distance)}
                </div>
              </td>
              <td class="action-cell">
                <button 
                  class="invite-player-btn" 
                  on:click={() => openConfirmModal(player)}
                  title={t('recruit.send_invite_title','Send gang invite')}
                >
                  <SendIcon />
                  <span>{t('invite_btn','Invite')}</span>
                </button>
              </td>
            </tr>
          {/each}
        {/if}
      </tbody>
    </table>
  </div>
</div>

<!-- Confirm Invite Modal -->
{#if showConfirmModal && selectedPlayer}
  <div class="modal-overlay" on:click={closeConfirmModal} transition:fade={{ duration: 200 }}>
    <div class="modal confirm-modal" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="modal-header">
        <h3>{t('recruit.confirm_invite_title','Confirm Invite')}</h3>
        <button class="close-btn" on:click={closeConfirmModal}>
          <CloseIcon />
        </button>
      </div>
      
      <div class="modal-body">
        <div class="confirm-content">
          <UserPlusIcon class="confirm-icon" />
          <p class="modal-description">
            {t('recruit.confirm_invite_prefix','Are you sure you want to invite')} <strong>{selectedPlayer.name}</strong> {t('recruit.confirm_invite_suffix','to your gang?')}
          </p>
          <div class="player-info">
            <span class="info-label">Server ID:</span>
            <span class="info-value">#{selectedPlayer.id}</span>
          </div>
          <div class="player-info">
            <span class="info-label">Distance:</span>
            <span class="info-value">{formatDistance(selectedPlayer.distance)}</span>
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeConfirmModal}>{t('cancel','Cancel')}</button>
        <button class="btn btn-primary" on:click={confirmInvite}>
          <SendIcon />
          <span>{t('send_invite','Send Invite')}</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Invite by ID Modal -->
{#if showInviteModal}
  <div class="modal-overlay" on:click={closeInviteModal} transition:fade={{ duration: 200 }}>
    <div class="modal" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="modal-header">
        <h3>{t('recruit.invite_by_id_title','Invite via Server ID')}</h3>
        <button class="close-btn" on:click={closeInviteModal}>
          <CloseIcon />
        </button>
      </div>
      
      <div class="modal-body">
        <p class="modal-description">
          {t('recruit.invite_by_id_desc','Enter the server ID of the player you want to invite to your gang.')}
        </p>
        
        <div class="form-group">
            <label for="server-id">{t('server_id','Server ID')}</label>
          <input 
            id="server-id"
            type="number" 
            bind:value={inviteServerId} 
            placeholder={t('recruit.placeholder_server_id','Enter server ID...')}
            min="1"
            autofocus
          />
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeInviteModal}>{t('cancel','Cancel')}</button>
        <button class="btn btn-primary" on:click={inviteByServerId}>
          <SendIcon />
          <span>{t('send_invite','Send Invite')}</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .recruiting-page {
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
    gap: 16px;
    flex-wrap: wrap;
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
    background: linear-gradient(135deg, rgba(34, 197, 94, 0.15), rgba(22, 163, 74, 0.15));
    border-radius: 12px;
    color: #22c55e;
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

  .header-actions {
    display: flex;
    gap: 12px;
  }

  .action-btn {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 20px;
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-primary);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 200ms ease;
    font-family: 'Inter', sans-serif;
  }

  .action-btn:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.05);
    border-color: var(--border-light);
    transform: translateY(-2px);
  }

  .action-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .refresh-btn:hover:not(:disabled) {
    border-color: #3b82f6;
    color: #3b82f6;
  }

  .refresh-icon {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .spinning {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }

  .invite-btn {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 24px;
    background: var(--accent);
    border: none;
    border-radius: 8px;
    color: white;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 200ms ease;
    font-family: 'Inter', sans-serif;
  }

  .invite-btn:hover {
    background: var(--accent-hover);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
  }

  /* Table */
  .table-container {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
    overflow: hidden;
  }

  table {
    width: 100%;
    border-collapse: collapse;
  }

  thead {
    background: rgba(34, 197, 94, 0.05);
    border-bottom: 1px solid var(--border);
  }

  th {
    padding: 16px;
    text-align: left;
    font-size: 13px;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  tbody tr {
    border-bottom: 1px solid var(--border);
    transition: background 150ms ease;
  }

  tbody tr:last-child {
    border-bottom: none;
  }

  tbody tr:hover {
    background: rgba(34, 197, 94, 0.03);
  }

  td {
    padding: 16px;
    color: var(--text-primary);
  }

  .empty-state {
    padding: 60px 20px !important;
    text-align: center;
  }

  .empty-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }

  .empty-icon {
    width: 64px;
    height: 64px;
    color: var(--text-dim);
    opacity: 0.5;
  }

  .empty-content p {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .empty-content span {
    font-size: 14px;
    color: var(--text-dim);
  }

  .id-cell {
    width: 120px;
  }

  .player-id {
    display: inline-flex;
    align-items: center;
    padding: 6px 12px;
    background: rgba(99, 102, 241, 0.1);
    border: 1px solid rgba(99, 102, 241, 0.3);
    border-radius: 6px;
    font-size: 14px;
    font-weight: 600;
    color: var(--accent);
  }

  .name-cell {
    min-width: 200px;
  }

  .player-name {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .distance-cell {
    width: 150px;
  }

  .distance-badge {
    display: inline-flex;
    align-items: center;
    padding: 6px 12px;
    background: rgba(34, 197, 94, 0.1);
    border: 1px solid rgba(34, 197, 94, 0.3);
    border-radius: 6px;
    font-size: 13px;
    font-weight: 600;
    color: #22c55e;
  }

  .action-cell {
    width: 150px;
  }

  .invite-player-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    background: linear-gradient(135deg, #22c55e, #16a34a);
    border: none;
    border-radius: 6px;
    color: white;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 150ms ease;
    font-family: 'Inter', sans-serif;
  }

  .invite-player-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(34, 197, 94, 0.3);
  }

  /* Modal */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.7);
    display: grid;
    place-items: center;
    z-index: 1000;
    padding: 20px;
  }

  .modal {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 16px;
    width: 100%;
    max-width: 450px;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 24px;
    border-bottom: 1px solid var(--border);
  }

  .modal-header h3 {
    margin: 0;
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .close-btn {
    width: 32px;
    height: 32px;
    display: grid;
    place-items: center;
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 6px;
    cursor: pointer;
    transition: all 150ms ease;
    color: var(--text-secondary);
  }

  .close-btn:hover {
    background: rgba(239, 68, 68, 0.1);
    border-color: #ef4444;
    color: #ef4444;
  }

  .modal-body {
    padding: 24px;
  }

  .modal-description {
    margin: 0 0 20px 0;
    font-size: 14px;
    color: var(--text-secondary);
    line-height: 1.6;
  }

  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
    padding: 24px;
    border-top: 1px solid var(--border);
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .form-group label {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .form-group input[type="number"] {
    padding: 12px 16px;
    background: var(--bg-base);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-primary);
    font-size: 14px;
    font-family: 'Inter', sans-serif;
    transition: all 150ms ease;
  }

  .form-group input[type="number"]::-webkit-inner-spin-button,
  .form-group input[type="number"]::-webkit-outer-spin-button {
    opacity: 1;
    filter: invert(0.6);
  }

  .form-group input[type="number"]:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
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

  .btn-primary {
    background: var(--accent);
    color: white;
  }

  .btn-primary:hover {
    background: var(--accent-hover);
    transform: translateY(-1px);
  }

  .btn-secondary {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--text-primary);
  }

  .btn-secondary:hover {
    background: rgba(255, 255, 255, 0.05);
  }

  /* Confirm Modal */
  .confirm-modal {
    max-width: 450px;
  }

  .confirm-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    text-align: center;
  }

  .confirm-icon {
    width: 56px;
    height: 56px;
    padding: 14px;
    background: rgba(34, 197, 94, 0.15);
    border: 2px solid rgba(34, 197, 94, 0.3);
    border-radius: 50%;
    color: #22c55e;
  }

  .modal-description strong {
    color: var(--text-primary);
    font-weight: 600;
  }

  .player-info {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    background: var(--bg-base);
    border: 1px solid var(--border);
    border-radius: 8px;
    width: 100%;
    justify-content: space-between;
  }

  .info-label {
    font-size: 13px;
    color: var(--text-secondary);
    font-weight: 500;
  }

  .info-value {
    font-size: 14px;
    color: var(--text-primary);
    font-weight: 600;
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

  @media (max-width: 768px) {
    .header {
      flex-direction: column;
      align-items: flex-start;
    }

    .header-actions {
      width: 100%;
      flex-direction: column;
    }

    .action-btn,
    .invite-btn {
      width: 100%;
      justify-content: center;
    }

    .table-container {
      overflow-x: auto;
    }

    table {
      min-width: 600px;
    }
  }
</style>
