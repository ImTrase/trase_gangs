<script lang="ts">
  import { onMount } from 'svelte';
  import { fade, fly, scale } from 'svelte/transition';
  import { fetchNui } from '../../utils/fetchNui';
  import { t } from '../../utils/translate';
  
  // Icons
  import SwordIcon from "virtual:icons/mdi/sword-cross";
  import PlusIcon from "virtual:icons/mdi/plus";
  import TrophyIcon from "virtual:icons/mdi/trophy";
  import SkullIcon from "virtual:icons/mdi/skull";
  import CheckIcon from "virtual:icons/mdi/check";
  import CloseIcon from "virtual:icons/mdi/close";
  import SendIcon from "virtual:icons/mdi/send";
  import InboxIcon from "virtual:icons/mdi/inbox-arrow-down";
  import HistoryIcon from "virtual:icons/mdi/history";
  import CashIcon from "virtual:icons/mdi/currency-usd";

  interface GangWarHistory {
    id: number;
    opponentGang: string;
    result: 'win' | 'loss';
    kills: number;
    deaths: number;
    wager: number;
    date: string;
  }

  interface GangWarRequest {
    id: number;
    fromGang: string;
    killsToWin: number;
    wager: number;
    sentAt: string;
  }

  interface OutgoingGangWarRequest {
    id: number;
    toGang: string;
    toGangId: number;
    killsToWin: number;
    wager: number;
    sentAt: string;
  }

  interface Gang {
    id: number;
    name: string;
    memberCount: number;
  }

  import { locales } from '../../stores/localeStore';
  let activeTab: 'history' | 'requests' | 'outgoing' = 'history';
  
  let gangWarHistory: GangWarHistory[] = [
    // { id: 1, opponentGang: 'The Bloods', result: 'win', kills: 25, deaths: 18, wager: 50000, date: '2024-10-28' },
    // { id: 2, opponentGang: 'Grove Street', result: 'loss', kills: 15, deaths: 25, wager: 0, date: '2024-10-25' },
    // { id: 3, opponentGang: 'Ballas Gang', result: 'win', kills: 30, deaths: 22, wager: 75000, date: '2024-10-20' },
    // { id: 4, opponentGang: 'Vagos', result: 'win', kills: 20, deaths: 15, wager: 25000, date: '2024-10-15' },
  ];

  let incomingRequests: GangWarRequest[] = [
    // { id: 1, fromGang: 'The Families', killsToWin: 25, wager: 100000, sentAt: '2024-11-01 14:30' },
    // { id: 2, fromGang: 'Marabunta', killsToWin: 30, wager: 0, sentAt: '2024-11-01 12:15' },
  ];

  let outgoingRequests: OutgoingGangWarRequest[] = [
    // { id: 1, toGang: 'The Bloods', toGangId: 3, killsToWin: 25, wager: 50000, sentAt: '2024-11-01 13:00' },
  ];

  let availableGangs: Gang[] = [
    // { id: 1, name: 'The Families', memberCount: 15 },
    // { id: 2, name: 'Marabunta', memberCount: 12 },
    // { id: 3, name: 'The Bloods', memberCount: 18 },
    // { id: 4, name: 'Grove Street', memberCount: 20 },
    // { id: 5, name: 'Ballas Gang', memberCount: 14 },
    // { id: 6, name: 'Vagos', memberCount: 16 },
  ];

  let showCreateModal = false;
  let selectedGangId: number | null = null;
  let killsToWin = 25;
  let wagerAmount = '';

  onMount(async () => {
    // Fetch gang war data from server
    try {
      const data = await fetchNui('getGangWarData');
      if (data?.history) {
        gangWarHistory = data.history;
      }
      if (data?.requests) {
        incomingRequests = data.requests;
      }
      if (data?.outgoing) {
        outgoingRequests = data.outgoing;
      }
      if (data?.gangs) {
        availableGangs = data.gangs;
      }
    } catch (e) {
      console.log('Using mock data for development');
    }
  });

  function openCreateModal() {
    selectedGangId = filteredGangs.length > 0 ? filteredGangs[0].id : null;
    killsToWin = 25;
    wagerAmount = '';
    showCreateModal = true;
  }

  function closeCreateModal() {
    showCreateModal = false;
    selectedGangId = null;
    killsToWin = 25;
    wagerAmount = '';
  }

  async function sendGangWarInvite() {
    if (!selectedGangId) {
      fetchNui('trase_gangs:notify', { title: $locales['error'] || 'Error', description: $locales['gangwar_no_gang'] || 'Please select a gang', type: 'error' });
      return;
    }

    if (killsToWin < 1) {
      fetchNui('trase_gangs:notify', { title: $locales['error'] || 'Error', description: $locales['gangwar_invalid_kills'] || 'Kills to win must be at least 1', type: 'error' });
      return;
    }

    const wager = wagerAmount ? parseInt(wagerAmount) : 0;

    try {
      const response = await fetchNui('sendGangWarInvite', {
        gangId: selectedGangId,
        killsToWin,
        wager
      });

      // Add to outgoing requests if response contains the request data
      if (response?.request) {
        outgoingRequests = [...outgoingRequests, response.request];
      }

      // notify
      fetchNui('trase_gangs:notify', {
        title: $locales['gangwar_invite_sent_title'] || 'Invite Sent',
        description: $locales['gangwar_invite_sent_desc'] || 'Gang invite has been sent',
        type: 'success'
      });

      closeCreateModal();
    } catch (e) {
      console.error('Failed to send gang war invite:', e);
      closeCreateModal();
    }
  }

  async function acceptGangWarRequest(request: GangWarRequest) {
    try {
      await fetchNui('acceptGangWarRequest', { requestId: request.id });
      incomingRequests = incomingRequests.filter(r => r.id !== request.id);
    } catch (e) {
      console.error('Failed to accept gang war request:', e);
      incomingRequests = incomingRequests.filter(r => r.id !== request.id);
    }
  }

  async function declineGangWarRequest(request: GangWarRequest) {
    try {
      await fetchNui('declineGangWarRequest', { requestId: request.id });
      incomingRequests = incomingRequests.filter(r => r.id !== request.id);
    } catch (e) {
      console.error('Failed to decline gang war request:', e);
      incomingRequests = incomingRequests.filter(r => r.id !== request.id);
    }
  }

  async function cancelOutgoingRequest(request: OutgoingGangWarRequest) {
    try {
      await fetchNui('cancelGangWarInvite', { requestId: request.id });
      outgoingRequests = outgoingRequests.filter(r => r.id !== request.id);
    } catch (e) {
      console.error('Failed to cancel gang war invite:', e);
      outgoingRequests = outgoingRequests.filter(r => r.id !== request.id);
    }
  }

  function formatDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    });
  }

  function formatDateTime(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleString('en-US', { 
      month: 'short', 
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function formatCurrency(value: number): string {
    if (value === 0) return t('gangwars.no_wager','No wager');
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value);
  }

  $: wins = gangWarHistory.filter(w => w.result === 'win').length;
  $: losses = gangWarHistory.filter(w => w.result === 'loss').length;
  $: totalWars = gangWarHistory.length;
  
  // Filter out gangs that already have pending invites (spam prevention)
  $: filteredGangs = availableGangs.filter(gang => {
    return !outgoingRequests.some(req => req.toGangId === gang.id);
  });
</script>

<div class="gang-wars-page" in:fade={{ duration: 200 }}>
  <!-- Header -->
  <div class="header" in:fly={{ y: -20, duration: 250, delay: 50 }}>
    <div class="header-content">
      <SwordIcon class="header-icon" />
      <div>
        <h2>{t('gangwars.title','Gang Wars')}</h2>
        <p>{wins}W - {losses}L · {totalWars} {t('gangwars.total_wars','total wars')}</p>
      </div>
    </div>
      <button class="create-btn" on:click={openCreateModal} in:scale={{ start: 0.8, duration: 250, delay: 100 }}>
      <PlusIcon />
      <span>{t('gangwars.create_war','Create Gang War')}</span>
    </button>
  </div>

  <!-- Tabs -->
  <div class="tabs" in:fly={{ y: 20, duration: 250, delay: 100 }}>
    <button 
      class="tab" 
      class:active={activeTab === 'history'}
      on:click={() => activeTab = 'history'}
    >
      <HistoryIcon />
      <span>{t('gangwars.tab_history','War History')}</span>
      <span class="badge">{totalWars}</span>
    </button>
    <button 
      class="tab" 
      class:active={activeTab === 'requests'}
      on:click={() => activeTab = 'requests'}
    >
      <InboxIcon />
      <span>{t('gangwars.tab_incoming','Incoming Requests')}</span>
      {#if incomingRequests.length > 0}
        <span class="badge highlight">{incomingRequests.length}</span>
      {/if}
    </button>
    <button 
      class="tab" 
      class:active={activeTab === 'outgoing'}
      on:click={() => activeTab = 'outgoing'}
    >
      <SendIcon />
      <span>{t('gangwars.tab_outgoing','Outgoing Requests')}</span>
      {#if outgoingRequests.length > 0}
        <span class="badge">{outgoingRequests.length}</span>
      {/if}
    </button>
  </div>

  <!-- Content -->
  {#if activeTab === 'history'}
    <div class="table-container" in:fly={{ y: 20, duration: 250, delay: 150 }}>
      <table>
        <thead>
          <tr>
            <th>{t('gangwars.col_result','Result')}</th>
            <th>{t('gangwars.col_opponent','Opponent')}</th>
            <th>{t('gangwars.col_kd','K/D')}</th>
            <th>{t('gangwars.col_wager','Wager')}</th>
            <th>{t('gangwars.col_date','Date')}</th>
          </tr>
        </thead>
        <tbody>
          {#if gangWarHistory.length === 0}
            <tr>
              <td colspan="5" class="empty-state">
                <div class="empty-content">
                  <SwordIcon class="empty-icon" />
                  <p>{t('gangwars.no_wars','No gang wars yet')}</p>
                  <span>{t('gangwars.history_empty','Start a gang war to see your history')}</span>
                </div>
              </td>
            </tr>
          {:else}
            {#each gangWarHistory as war, i (war.id)}
              <tr in:fly={{ y: 20, duration: 250, delay: 200 + (i * 30) }}>
                <td class="result-cell">
                  <div class="result-badge" class:win={war.result === 'win'} class:loss={war.result === 'loss'}>
                    {#if war.result === 'win'}
                      <TrophyIcon />
                      <span>{t('gangwars.result_victory','Victory')}</span>
                    {:else}
                      <SkullIcon />
                      <span>{t('gangwars.result_defeat','Defeat')}</span>
                    {/if}
                  </div>
                </td>
                <td class="opponent-cell">
                  <div class="opponent-name">{war.opponentGang}</div>
                </td>
                <td class="kd-cell">
                  <div class="kd-stats">
                    <span class="kills">{war.kills}</span>
                    <span class="separator">/</span>
                    <span class="deaths">{war.deaths}</span>
                  </div>
                </td>
                <td class="wager-cell">
                  <div class="wager-amount" class:no-wager={war.wager === 0}>
                    {formatCurrency(war.wager)}
                  </div>
                </td>
                <td class="date-cell">
                  <span class="date-text">{formatDate(war.date)}</span>
                </td>
              </tr>
            {/each}
          {/if}
        </tbody>
      </table>
    </div>
  {:else if activeTab === 'requests'}
    <div class="requests-container" in:fly={{ y: 20, duration: 250, delay: 150 }}>
      {#if incomingRequests.length === 0}
        <div class="empty-state-box">
          <InboxIcon class="empty-icon" />
          <p>{t('gangwars.no_incoming','No incoming requests')}</p>
          <span>{t('gangwars.incoming_hint','Gang war invites will appear here')}</span>
        </div>
      {:else}
        <div class="requests-grid">
          {#each incomingRequests as request, i (request.id)}
            <div class="request-card" in:fly={{ y: 20, duration: 250, delay: 200 + (i * 50) }}>
              <div class="request-header">
                <div class="gang-info">
                  <SwordIcon class="gang-icon" />
                  <h3>{request.fromGang}</h3>
                </div>
                <span class="time-badge">{formatDateTime(request.sentAt)}</span>
              </div>
              
              <div class="request-details">
                <div class="detail-item">
                  <span class="detail-label">{t('gangwars.kills_to_win','Kills to Win')}</span>
                  <span class="detail-value">{request.killsToWin}</span>
                </div>
                <div class="detail-item">
                  <span class="detail-label">{t('gangwars.wager_label','Wager')}</span>
                  <span class="detail-value">{formatCurrency(request.wager)}</span>
                </div>
              </div>

              <div class="request-actions">
                <button class="action-btn decline" on:click={() => declineGangWarRequest(request)}>
                  <CloseIcon />
                  <span>{t('invite_decline','Decline')}</span>
                </button>
                <button class="action-btn accept" on:click={() => acceptGangWarRequest(request)}>
                  <CheckIcon />
                  <span>{t('invite_accept','Accept')}</span>
                </button>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {:else}
    <div class="requests-container" in:fly={{ y: 20, duration: 250, delay: 150 }}>
      {#if outgoingRequests.length === 0}
        <div class="empty-state-box">
          <SendIcon class="empty-icon" />
          <p>No outgoing requests</p>
          <span>Gang war invites you send will appear here</span>
        </div>
      {:else}
        <div class="requests-grid">
          {#each outgoingRequests as request, i (request.id)}
            <div class="request-card" in:fly={{ y: 20, duration: 250, delay: 200 + (i * 50) }}>
              <div class="request-header">
                <div class="gang-info">
                  <SwordIcon class="gang-icon" />
                  <h3>{request.toGang}</h3>
                </div>
                <span class="time-badge">{formatDateTime(request.sentAt)}</span>
              </div>
              
              <div class="request-details">
                <div class="detail-item">
                  <span class="detail-label">Kills to Win</span>
                  <span class="detail-value">{request.killsToWin}</span>
                </div>
                <div class="detail-item">
                  <span class="detail-label">Wager</span>
                  <span class="detail-value">{formatCurrency(request.wager)}</span>
                </div>
              </div>

              <div class="request-actions">
                <button class="action-btn decline full-width" on:click={() => cancelOutgoingRequest(request)}>
                  <CloseIcon />
                  <span>{t('gangwars.cancel_invite','Cancel Invite')}</span>
                </button>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}
</div>

<!-- Create Gang War Modal -->
{#if showCreateModal}
  <div class="modal-overlay" on:click={closeCreateModal} transition:fade={{ duration: 200 }}>
    <div class="modal" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="modal-header">
        <h3>{t('gangwars.create_war','Create Gang War')}</h3>
        <button class="close-btn" on:click={closeCreateModal}>
          <CloseIcon />
        </button>
      </div>
      
      <div class="modal-body">
        {#if filteredGangs.length === 0}
          <div class="no-gangs-message">
            <p>No available gangs</p>
            <span>You've already sent invites to all available gangs or there are no other gangs.</span>
          </div>
        {:else}
          <div class="form-group">
            <label for="gang-select">Select Gang</label>
            <select id="gang-select" bind:value={selectedGangId}>
              {#each filteredGangs as gang}
                <option value={gang.id}>{gang.name} ({gang.memberCount} {t('members_label','Members')})</option>
              {/each}
            </select>
          </div>
        {/if}

        {#if filteredGangs.length > 0}
          <div class="form-group">
            <label for="kills-to-win">{t('gangwars.kills_to_win','Kills to Win')}</label>
            <input 
              id="kills-to-win"
              type="number" 
              bind:value={killsToWin} 
              min="1"
              placeholder={t('gangwars.placeholder_kills','25')}
            />
          </div>

          <div class="form-group">
            <label for="wager-amount">
              {t('gangwars.wager_amount','Wager Amount')} <span class="optional">{t('optional','(Optional)')}</span>
            </label>
            <input 
              id="wager-amount"
              type="number" 
              bind:value={wagerAmount} 
              min="0"
              placeholder={t('gangwars.placeholder_wager','Enter wager amount...')}
            />
            <span class="form-hint">{t('gangwars.no_wager_hint','Leave empty for no wager')}</span>
          </div>
        {/if}
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeCreateModal}>Cancel</button>
        <button class="btn btn-primary" on:click={sendGangWarInvite} disabled={filteredGangs.length === 0}>
          <SendIcon />
          <span>Send Invite</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .gang-wars-page {
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
    background: linear-gradient(135deg, rgba(239, 68, 68, 0.15), rgba(220, 38, 38, 0.15));
    border-radius: 12px;
    color: #ef4444;
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

  .create-btn {
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

  .create-btn:hover {
    background: var(--accent-hover);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
  }

  /* Tabs */
  .tabs {
    display: flex;
    gap: 12px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 8px;
  }

  .tab {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 12px 16px;
    background: transparent;
    border: none;
    border-radius: 8px;
    color: var(--text-secondary);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 150ms ease;
    font-family: 'Inter', sans-serif;
  }

  .tab:hover {
    background: rgba(255, 255, 255, 0.05);
    color: var(--text-primary);
  }

  .tab.active {
    background: var(--accent);
    color: white;
  }

  .badge {
    padding: 2px 8px;
    background: rgba(255, 255, 255, 0.2);
    border-radius: 12px;
    font-size: 12px;
    font-weight: 700;
  }

  .badge.highlight {
    background: #ef4444;
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
    background: rgba(239, 68, 68, 0.05);
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
    background: rgba(239, 68, 68, 0.03);
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

  .result-cell {
    width: 150px;
  }

  .result-badge {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 600;
  }

  .result-badge.win {
    background: rgba(34, 197, 94, 0.15);
    border: 1px solid rgba(34, 197, 94, 0.3);
    color: #22c55e;
  }

  .result-badge.loss {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: #ef4444;
  }

  .opponent-cell {
    min-width: 200px;
  }

  .opponent-name {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .kd-cell {
    width: 120px;
  }

  .kd-stats {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 14px;
    font-weight: 600;
  }

  .kills {
    color: #22c55e;
  }

  .separator {
    color: var(--text-dim);
  }

  .deaths {
    color: #ef4444;
  }

  .wager-cell {
    width: 150px;
  }

  .wager-amount {
    font-size: 14px;
    font-weight: 600;
    color: #eab308;
  }

  .wager-amount.no-wager {
    color: var(--text-dim);
    font-style: italic;
  }

  .date-cell {
    width: 130px;
  }

  .date-text {
    font-size: 14px;
    color: var(--text-secondary);
  }

  /* Requests */
  .requests-container {
    min-height: 400px;
  }

  .empty-state-box {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    padding: 80px 20px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
  }

  .requests-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
    gap: 16px;
  }

  .request-card {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    transition: all 200ms ease;
  }

  .request-card:hover {
    border-color: var(--border-light);
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
  }

  .request-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .gang-info {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .gang-icon {
    width: 32px;
    height: 32px;
    padding: 6px;
    background: linear-gradient(135deg, rgba(239, 68, 68, 0.15), rgba(220, 38, 38, 0.15));
    border-radius: 8px;
    color: #ef4444;
  }

  .gang-info h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .time-badge {
    padding: 4px 12px;
    background: rgba(99, 102, 241, 0.15);
    border: 1px solid rgba(99, 102, 241, 0.3);
    border-radius: 6px;
    font-size: 12px;
    font-weight: 600;
    color: var(--accent);
  }

  .request-details {
    display: flex;
    gap: 24px;
    padding: 16px;
    background: var(--bg-base);
    border-radius: 8px;
  }

  .detail-item {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .detail-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .detail-value {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .request-actions {
    display: flex;
    gap: 12px;
  }

  .action-btn {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    padding: 10px 16px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 150ms ease;
    font-family: 'Inter', sans-serif;
  }

  .action-btn.decline {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: #ef4444;
  }

  .action-btn.decline:hover {
    background: rgba(239, 68, 68, 0.25);
    transform: translateY(-1px);
  }

  .action-btn.accept {
    background: linear-gradient(135deg, #22c55e, #16a34a);
    color: white;
  }

  .action-btn.accept:hover {
    transform: translateY(-1px);
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
    max-width: 500px;
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
    display: flex;
    flex-direction: column;
    gap: 20px;
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

  .optional {
    font-weight: 400;
    color: var(--text-dim);
    font-style: italic;
  }

  .form-group select,
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

  .form-group select {
    cursor: pointer;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23888' d='M6 9L1 4h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 12px center;
    padding-right: 40px;
  }

  .form-group select option {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .form-group input[type="number"]::-webkit-inner-spin-button,
  .form-group input[type="number"]::-webkit-outer-spin-button {
    opacity: 1;
    filter: invert(0.6);
  }

  .form-group select:focus,
  .form-group input[type="number"]:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
  }

  .form-hint {
    font-size: 12px;
    color: var(--text-dim);
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

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn:disabled:hover {
    transform: none;
    box-shadow: none;
  }

  .action-btn.full-width {
    flex: 1 1 100%;
  }

  .no-gangs-message {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 40px 20px;
    text-align: center;
  }

  .no-gangs-message p {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .no-gangs-message span {
    font-size: 14px;
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

  @media (max-width: 768px) {
    .header {
      flex-direction: column;
      align-items: flex-start;
    }

    .create-btn {
      width: 100%;
      justify-content: center;
    }

    .tabs {
      flex-direction: column;
    }

    .requests-grid {
      grid-template-columns: 1fr;
    }

    .table-container {
      overflow-x: auto;
    }

    table {
      min-width: 700px;
    }
  }
</style>
