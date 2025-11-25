<script lang="ts">
  import { fade, scale } from "svelte/transition";
  import { cubicOut } from "svelte/easing";
  import { useNuiEvent } from "../utils/useNuiEvent";
  import { fetchNui } from "../utils/fetchNui";
  import { t } from '../utils/translate';

  import "../theme.css";

  // Icons
  import ShieldIcon from "virtual:icons/mdi/shield-plus";
  import ListIcon from "virtual:icons/mdi/format-list-bulleted";
  import TrashIcon from "virtual:icons/mdi/delete";
  import SettingsIcon from "virtual:icons/mdi/cog";
  import CloseIcon from "virtual:icons/mdi/close";
  import SearchIcon from "virtual:icons/mdi/magnify";
  import EditIcon from "virtual:icons/mdi/pencil";
  import UsersIcon from "virtual:icons/mdi/account-group";
  import CrownIcon from "virtual:icons/mdi/crown";
  import CheckCircleIcon from "virtual:icons/mdi/check-circle";
  import AlertCircleIcon from "virtual:icons/mdi/alert-circle";
  import InfoCircleIcon from "virtual:icons/mdi/information";
  import MapMarkerIcon from "virtual:icons/mdi/map-marker";

  export let open = false;

  type PageKey = "create" | "manage";
  type NotificationType = "success" | "error" | "info";

  interface Notification {
    id: number;
    type: NotificationType;
    title: string;
    message: string;
  }

  let searchQuery = "";
  let showDeleteModal = false;
  let showMembersModal = false;
  let showRanksModal = false;
  let showEditModal = false;
  let showCreateModal = false;
  let selectedGang: any = null;
  let notifications: Notification[] = [];
  let notificationId = 0;
  let showStashPrompt = false;
  let createdGangId: number | null = null;

  let gangs = [];

  let newGang = {
    name: "",
    label: "",
    owner: ""
  };

  useNuiEvent("serverManagement:open", (data: any) => {
    console.log('[NUI] serverManagement:open received', data);
    console.log('[NUI] gangs data:', data?.gangs);
    console.log('[NUI] gangs length:', data?.gangs?.length);
    open = true;
    if (data && data.gangs) {
      gangs = data.gangs;
      console.log('[NUI] gangs set to:', gangs);
    } else {
      console.warn('[NUI] No gangs data in payload');
    }
  });

  useNuiEvent("serverManagement:updateGangs", (data: any) => {
    if (data && data.gangs) {
      gangs = data.gangs;
    }
  });

  useNuiEvent("serverManagement:gangCreated", (data: any) => {
    if (data && data.gangId) {
      createdGangId = data.gangId;
      showStashPrompt = true;
    }
  });

  useNuiEvent("serverManagement:notify", (data: any) => {
    if (data && data.type && data.title && data.message) {
      showNotification(data.type, data.title, data.message);
    }
  });

  useNuiEvent("serverManagement:close", () => {
    open = false;
    fetchNui("serverManagement:closeUI");
  });

  function closeUI() {
    open = false;
    fetchNui("serverManagement:closeUI");
  }

  function onKey(e: KeyboardEvent) {
    if (e.key === "Escape" && open) closeUI();
  }

  function showNotification(type: NotificationType, title: string, message: string) {
    const id = notificationId++;
    notifications = [...notifications, { id, type, title, message }];
    
    setTimeout(() => {
      notifications = notifications.filter(n => n.id !== id);
    }, 5000);
  }

  function dismissNotification(id: number) {
    notifications = notifications.filter(n => n.id !== id);
  }

  function createGang() {
    if (newGang.name && newGang.label && newGang.owner) {
      fetchNui("serverManagement:createGang", newGang).then(() => {
        newGang = { name: "", label: "", owner: "" };
        showCreateModal = false;
      });
    } else {
      showNotification("error", t('missing_info_title','Missing Information'), t('missing_info_desc','Please fill in all fields.'));
    }
  }

  function deleteGang(gangId: number) {
    fetchNui("serverManagement:deleteGang", { gangId });
    showDeleteModal = false;
  }

  function viewGangDetails(gang: any) {
    selectedGang = gang;
    showEditModal = true;
  }

  function viewMembers(gang: any) {
    selectedGang = gang;
    showMembersModal = true;
  }

  function viewRanks(gang: any) {
    selectedGang = gang;
    showRanksModal = true;
  }

  function formatDate(val: any) {
    if (!val) return t('unknown','Unknown');
    // If it's a number or a string of digits, treat as timestamp
    if (typeof val === 'number' || (typeof val === 'string' && /^\d+$/.test(val))) {
        return new Date(Number(val)).toLocaleDateString();
    }
    // Otherwise try standard date parsing
    const d = new Date(val);
    return isNaN(d.getTime()) ? t('unknown','Unknown') : d.toLocaleDateString();
  }

  $: filteredGangs = gangs.filter(g => 
    g.label.toLowerCase().includes(searchQuery.toLowerCase()) ||
    g.owner.toLowerCase().includes(searchQuery.toLowerCase())
  );
</script>

<svelte:window on:keydown={onKey} />

{#if open}
  <div>
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

    <div class="wrap" in:fade={{ duration: 160 }} out:fade={{ duration: 120 }}>
      <div
        class="panel"
        in:scale={{ start: 0.97, duration: 180, easing: cubicOut }}
        out:scale={{ start: 0.97, duration: 140, easing: cubicOut }}
      >
        <!-- Main Content -->
        <div class="main">
          <header class="topbar">
            <h1 class="page-title">{t('serverManagement.title', 'Manage Gangs')}</h1>
            <div class="header-actions">
              <button class="btn btn-primary" on:click={() => showCreateModal = true}>
                <ShieldIcon class="btn-icon" />
                {t('serverManagement.new_gang', 'New Gang')}
              </button>
              <button class="close-btn" on:click={closeUI} aria-label={t('close','Close')}>
                <CloseIcon class="close-icon" />
                <span>{t('close','Close')}</span>
              </button>
            </div>
          </header>

          <main class="content" role="region" aria-live="polite">
            <div class="manage-container">
              <div class="search-bar">
                <div class="search-icon">
                  <SearchIcon />
                </div>
                <input
                  type="text"
                  placeholder={t('serverManagement.search_placeholder','Search gangs...')}
                  bind:value={searchQuery}
                  class="search-input"
                />
              </div>

              <div class="gang-list">
                {#each filteredGangs as gang}
                  <div class="gang-card">
                    <div class="gang-header">
                      <div class="gang-name-section">
                        <h3 class="gang-name">{gang.label}</h3>
                        <span class="gang-id">{t('serverManagement.id_label', 'ID')}: {gang.id}</span>
                      </div>
                      <button class="btn-icon-only" on:click={() => viewGangDetails(gang)}>
                        <EditIcon />
                      </button>
                    </div>

                    <div class="gang-details">
                      <div class="detail-item">
                        <UsersIcon class="detail-icon" />
                        <span class="detail-label">{t('owner_label', 'Owner')}:</span>
                        <span class="detail-value">{gang.owner}</span>
                      </div>
                      <div class="detail-item">
                        <UsersIcon class="detail-icon" />
                        <span class="detail-label">{t('members_label', 'Members')}:</span>
                        <span class="detail-value">{gang.members}</span>
                      </div>
                      <div class="detail-item">
                        <CrownIcon class="detail-icon" />
                        <span class="detail-label">{t('ranks_label', 'Ranks')}:</span>
                        <span class="detail-value">{gang.ranks}</span>
                      </div>
                      <div class="detail-item">
                        <span class="detail-label">{t('created_label', 'Created')}:</span>
                        <span class="detail-value">{formatDate(gang.created)}</span>
                      </div>
                    </div>

                    <div class="gang-actions">
                      <button class="btn btn-secondary btn-sm" on:click={() => viewMembers(gang)}>{t('view_members','View Members')}</button>
                      <button class="btn btn-secondary btn-sm" on:click={() => viewRanks(gang)}>{t('view_ranks','View Ranks')}</button>
                      <button class="btn btn-danger btn-sm" on:click={() => {
                        selectedGang = gang;
                        showDeleteModal = true;
                      }}>
                        <TrashIcon class="btn-icon-sm" />
                        {t('delete','Delete')}
                      </button>
                    </div>
                  </div>
                {/each}
              </div>
            </div>
          </main>
        </div>
      </div>
    </div>

    <!-- Notification Container -->
    <div class="notification-container">
      {#each notifications as notification (notification.id)}
        <div 
          class="notification notification-{notification.type}"
          in:scale={{ start: 0.9, duration: 200 }}
          out:scale={{ start: 0.9, duration: 150 }}
        >
          <div class="notification-icon">
            {#if notification.type === "success"}
              <CheckCircleIcon class="icon" />
            {:else if notification.type === "error"}
              <AlertCircleIcon class="icon" />
            {:else}
              <InfoCircleIcon class="icon" />
            {/if}
          </div>
          <div class="notification-content">
            <div class="notification-title">{notification.title}</div>
            <div class="notification-message">{notification.message}</div>
          </div>
          <button 
            class="notification-close" 
            on:click={() => dismissNotification(notification.id)}
            aria-label={t('notification_close','Close notification')}
          >
            <CloseIcon class="close-icon-sm" />
          </button>
        </div>
      {/each}
    </div>

    <!-- Create Gang Modal -->
    {#if showCreateModal}
      <div class="modal-backdrop" on:click={() => showCreateModal = false}>
        <div class="modal" on:click|stopPropagation>
          <div class="modal-header">
            <h3>{t('create_gang_title','Create New Gang')}</h3>
            <button class="btn-icon-only" on:click={() => showCreateModal = false}>
              <CloseIcon />
            </button>
          </div>
          
          <div class="modal-content">
            <div class="form-group">
              <label>{t('create_gang_internal','Gang Name (Internal)')}</label>
              <input
                type="text"
                bind:value={newGang.name}
                class="form-input"
                placeholder={t('example_internal','e.g. ballas')}
              />
            </div>
            <div class="form-group">
              <label>{t('create_gang_label','Gang Label (Display Name)')}</label>
              <input
                type="text"
                bind:value={newGang.label}
                class="form-input"
                placeholder={t('example_display','e.g. Ballas')}
              />
            </div>
            <div class="form-group">
              <label>{t('create_gang_owner','Owner Server ID')}</label>
              <input
                type="text"
                bind:value={newGang.owner}
                class="form-input"
                placeholder={t('example_owner','e.g. 1')}
              />
            </div>
            
            <div class="info-card" style="margin-top: 16px;">
              <h3>{t('important_notes','Important Notes')}</h3>
              <ul>
                <li>{t('note_name_unique','Gang name must be unique and lowercase')}</li>
                <li>{t('note_owner_online','Owner must be online to create the gang')}</li>
                <li>{t('note_default_ranks','Default ranks will be created automatically')}</li>
              </ul>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn btn-secondary" on:click={() => showCreateModal = false}>
              {t('cancel','Cancel')}
            </button>
            <button class="btn btn-primary" on:click={createGang}>
              {t('create_gang_action','Create Gang')}
            </button>
          </div>
        </div>
      </div>
    {/if}

    {#if showStashPrompt}
      <div class="modal-backdrop">
        <div class="modal" on:click|stopPropagation>
          <h3>{t('gang_created','Gang Created!')}</h3>
          <p>{t('place_stash_prompt','Do you want to place the gang stash now?')}</p>
          <div class="modal-actions">
            <button class="btn btn-secondary" on:click={() => showStashPrompt = false}>
              {t('later','Later')}
            </button>
            <button class="btn btn-primary" on:click={() => {
              fetchNui("serverManagement:placeStash", { gangId: createdGangId });
              showStashPrompt = false;
              closeUI();
            }}>
              {t('place_stash_now','Place Stash Now')}
            </button>
          </div>
        </div>
      </div>
    {/if}

    {#if showDeleteModal && selectedGang}
      <div class="modal-backdrop" on:click={() => showDeleteModal = false}>
        <div class="modal" on:click|stopPropagation>
          <h3>{t('confirm_delete_title','Confirm Deletion')}</h3>
          <p>{t('confirm_delete_msg','Are you sure you want to delete')} <strong>{selectedGang.label}</strong>?</p>
          <p class="warning-text">{t('confirm_delete_warning','This action cannot be undone!')}</p>
          <div class="modal-actions">
            <button class="btn btn-secondary" on:click={() => showDeleteModal = false}>
              {t('cancel','Cancel')}
            </button>
            <button class="btn btn-danger" on:click={() => deleteGang(selectedGang.id)}>
              {t('delete_gang','Delete Gang')}
            </button>
          </div>
        </div>
      </div>
    {/if}

    <!-- Members Modal -->
    {#if showMembersModal && selectedGang}
      <div class="modal-backdrop" on:click={() => showMembersModal = false}>
        <div class="modal modal-large" on:click|stopPropagation>
          <div class="modal-header">
            <h3>{selectedGang.label} - {t('members_label','Members')}</h3>
            <button class="btn-icon-only" on:click={() => showMembersModal = false}>
              <CloseIcon />
            </button>
          </div>
          
          <div class="modal-content">
            <div class="members-table">
              <div class="table-header">
                <div class="th">{t('name_label','Name')}</div>
                <div class="th">{t('rank_label','Rank')}</div>
                <div class="th">{t('status_label','Status')}</div>
                <div class="th">{t('joined_label','Joined')}</div>
              </div>
              {#each selectedGang.membersList as member}
                <div class="table-row">
                  <div class="td">{member.name}</div>
                  <div class="td">
                    <span class="rank-badge">{member.rank}</span>
                  </div>
                  <div class="td">
                      <span class="status-badge {member.online ? 'online' : 'offline'}">
                      {member.online ? t('online','Online') : t('offline','Offline')}
                    </span>
                  </div>
                  <div class="td">{formatDate(member.joined)}</div>
                </div>
              {/each}
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn btn-secondary" on:click={() => showMembersModal = false}>
              {t('close','Close')}
            </button>
          </div>
        </div>
      </div>
    {/if}

    <!-- Ranks Modal -->
    {#if showRanksModal && selectedGang}
      <div class="modal-backdrop" on:click={() => showRanksModal = false}>
        <div class="modal modal-large" on:click|stopPropagation>
          <div class="modal-header">
            <h3>{selectedGang.label} - {t('ranks_label','Ranks')}</h3>
            <button class="btn-icon-only" on:click={() => showRanksModal = false}>
              <CloseIcon />
            </button>
          </div>
          
          <div class="modal-content">
            <div class="ranks-grid">
              {#each selectedGang.ranksList as rank}
                <div class="rank-card">
                  <div class="rank-header">
                    <div class="rank-info">
                      <h4 class="rank-name">{rank.name}</h4>
                      <span class="rank-grade">Grade {rank.grade}</span>
                    </div>
                    <div class="rank-count">{rank.members} {t('members_label','Members')}</div>
                  </div>
                  
                  <div class="rank-permissions">
                    <div class="permissions-label">{t('permissions_label','Permissions:')}</div>
                    <div class="permissions-list">
                      {#if rank.permissions.length === 0}
                        <span class="permission-badge empty">{t('permissions_none','None')}</span>
                      {:else if rank.permissions.includes("All")}
                        <span class="permission-badge all">{t('permissions_all','All Permissions')}</span>
                      {:else}
                        {#each rank.permissions as permission}
                          <span class="permission-badge">{permission}</span>
                        {/each}
                      {/if}
                    </div>
                  </div>
                </div>
              {/each}
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn btn-secondary" on:click={() => showRanksModal = false}>
              {t('close','Close')}
            </button>
          </div>
        </div>
      </div>
    {/if}

    <!-- Edit Gang Modal -->
    {#if showEditModal && selectedGang}
      <div class="modal-backdrop" on:click={() => showEditModal = false}>
        <div class="modal modal-large" on:click|stopPropagation>
          <div class="modal-header">
            <h3>{t('edit_gang_title','Edit Gang')} - {selectedGang.label}</h3>
            <button class="btn-icon-only" on:click={() => showEditModal = false}>
              <CloseIcon />
            </button>
          </div>
          
          <div class="modal-content">
            <div class="edit-gang-grid">
              <div class="edit-section">
                <h4 class="section-title">{t('gang_info_title','Gang Information')}</h4>
                <div class="form-group">
                  <label>{t('gang_name_label','Gang Name')}</label>
                  <input
                    type="text"
                    value={selectedGang.name}
                    class="form-input"
                    placeholder="Gang name..."
                  />
                </div>
                <div class="form-group">
                  <label>{t('gang_label_label','Gang Label')}</label>
                  <input
                    type="text"
                    value={selectedGang.label}
                    class="form-input"
                    placeholder="Gang label..."
                  />
                </div>
                <div class="form-group">
                  <label>{t('owner_label','Owner')}</label>
                  <input
                    type="text"
                    value={selectedGang.owner}
                    class="form-input"
                    placeholder="Owner name..."
                    disabled
                  />
                </div>
              </div>

              <div class="edit-section">
                <h4 class="section-title">{t('gang_stats_title','Gang Statistics')}</h4>
                <div class="stats-display">
                  <div class="stat-item">
                    <span class="stat-label">{t('total_members','Total Members')}</span>
                    <span class="stat-value">{selectedGang.members}</span>
                  </div>
                  <div class="stat-item">
                    <span class="stat-label">{t('total_ranks','Total Ranks')}</span>
                    <span class="stat-value">{selectedGang.ranks}</span>
                  </div>
                  <div class="stat-item">
                    <span class="stat-label">{t('created_label','Created')}</span>
                    <span class="stat-value">{formatDate(selectedGang.created)}</span>
                  </div>
                  <div class="stat-item">
                    <span class="stat-label">{t('gang_id_label','Gang ID')}</span>
                    <span class="stat-value">#{selectedGang.id}</span>
                  </div>
                </div>
              </div>

              <div class="edit-section full-width">
                <h4 class="section-title">{t('quick_actions','Quick Actions')}</h4>
                <div class="quick-actions">
                  <button class="btn btn-secondary" on:click={() => {
                    showEditModal = false;
                    viewMembers(selectedGang);
                  }}>
                    <UsersIcon class="btn-icon" />
                    {t('view_members','View Members')}
                  </button>
                  <button class="btn btn-secondary" on:click={() => {
                    showEditModal = false;
                    viewRanks(selectedGang);
                  }}>
                    <CrownIcon class="btn-icon" />
                    {t('view_ranks','View Ranks')}
                  </button>
                  <button class="btn btn-secondary" on:click={() => {
                    fetchNui("serverManagement:placeStash", { gangId: selectedGang.id });
                    showEditModal = false;
                    closeUI();
                  }}>
                    <MapMarkerIcon class="btn-icon" />
                    {t('place_stash','Place Stash')}
                  </button>
                  <button class="btn btn-danger" on:click={() => {
                    showEditModal = false;
                    showDeleteModal = true;
                  }}>
                    <TrashIcon class="btn-icon" />
                    {t('delete_gang','Delete Gang')}
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn btn-secondary" on:click={() => showEditModal = false}>
              {t('cancel','Cancel')}
            </button>
            <button class="btn btn-primary" on:click={() => {
              fetchNui("serverManagement:updateGang", selectedGang);
              showEditModal = false;
            }}>
              {t('save_changes','Save Changes')}
            </button>
          </div>
        </div>
      </div>
    {/if}
  </div>
{/if}

<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

  :root {
    --bg-dark: #0f0f17;
    --bg-panel: #18181f;
    --bg-sidebar: #1a1a22;
    --bg-elevated: #20202a;
    --accent: #3b82f6;
    --accent-hover: #2563eb;
    --accent-light: #60a5fa;
    --danger: #ef4444;
    --danger-hover: #dc2626;
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
    display: flex;
    flex-direction: column;
    background: var(--bg-panel);
    border-radius: 20px;
    overflow: hidden;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    color: var(--text-primary);
  }

  /* Main Content */
  .main {
    flex: 1;
    display: flex;
    flex-direction: column;
    background: var(--bg-dark);
    overflow: hidden;
    padding-bottom: 10px;
  }

  .topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20px 32px;
    background: var(--bg-panel);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 12px;
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
    font-family: 'Inter', sans-serif;
    cursor: pointer;
    transition: all 150ms ease;
  }

  .close-icon {
    width: 16px;
    height: 16px;
  }

  .close-btn:hover {
    background: var(--bg-sidebar);
  }

  .close-btn:active {
    transform: scale(0.98);
  }

  /* Content */
  .content {
    flex: 1;
    padding: 24px;
    overflow-y: auto;
  }

  .manage-container {
    display: flex;
    flex-direction: column;
    gap: 20px;
    min-height: 0; /* Important for flex scrolling */
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .form-group label {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-secondary);
  }

  .form-input {
    padding: 10px 14px;
    background: var(--bg-sidebar);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-primary);
    font-size: 14px;
    font-family: 'Inter', sans-serif;
    transition: all 150ms ease;
  }

  .form-input:focus {
    outline: none;
    border-color: var(--accent);
  }

  .form-input:disabled {
    background: var(--bg-dark);
    color: var(--text-dim);
    cursor: not-allowed;
    opacity: 0.6;
  }

  .info-card {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px;
  }

  .info-card h3 {
    font-size: 14px;
    font-weight: 600;
    margin: 0 0 12px 0;
    color: var(--text-primary);
  }

  .info-card ul {
    margin: 0;
    padding-left: 20px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .info-card li {
    font-size: 12px;
    color: var(--text-secondary);
    line-height: 1.5;
  }

  /* Buttons */
  .btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 10px 20px;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    font-family: 'Inter', sans-serif;
    cursor: pointer;
    transition: all 150ms ease;
    border: none;
  }

  .btn-primary {
    background: linear-gradient(135deg, var(--accent), var(--accent-hover));
    color: white;
  }

  .btn-primary:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
  }

  .btn-secondary {
    background: var(--bg-elevated);
    color: var(--text-primary);
    border: 1px solid var(--border-light);
  }

  .btn-secondary:hover {
    background: var(--bg-sidebar);
  }

  .btn-danger {
    background: var(--danger);
    color: white;
  }

  .btn-danger:hover {
    background: var(--danger-hover);
  }

  .btn-sm {
    padding: 6px 12px;
    font-size: 12px;
  }

  .btn-icon {
    width: 18px;
    height: 18px;
  }

  .btn-icon-sm {
    width: 14px;
    height: 14px;
  }

  .btn-icon-only {
    width: 32px;
    height: 32px;
    padding: 0;
    display: grid;
    place-items: center;
    background: var(--bg-sidebar);
    border: 1px solid var(--border);
    border-radius: 6px;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 150ms ease;
  }

  .btn-icon-only:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .search-bar {
    position: relative;
    max-width: 500px;
    display: flex;
    align-items: center;
  }

  .search-icon {
    position: absolute;
    left: 14px;
    width: 18px;
    height: 18px;
    color: var(--text-dim);
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    padding: 10px 14px 10px 42px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-primary);
    font-size: 14px;
    font-family: 'Inter', sans-serif;
  }

  .search-input:focus {
    outline: none;
    border-color: var(--accent);
  }

  .gang-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .gang-card {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .gang-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .gang-name-section {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .gang-name {
    font-size: 16px;
    font-weight: 600;
    margin: 0;
    color: var(--text-primary);
  }

  .gang-id {
    font-size: 11px;
    color: var(--text-dim);
    background: var(--bg-sidebar);
    padding: 2px 6px;
    border-radius: 4px;
  }

  .gang-details {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
  }

  .detail-item {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
  }

  .detail-icon {
    width: 16px;
    height: 16px;
    color: var(--text-dim);
  }

  .detail-label {
    color: var(--text-secondary);
  }

  .detail-value {
    color: var(--text-primary);
    font-weight: 500;
  }

  .gang-actions {
    display: flex;
    gap: 8px;
    padding-top: 8px;
    border-top: 1px solid var(--border);
  }

  /* Stats Grid */
  .stat-label {
    font-size: 13px;
    color: var(--text-dim);
    font-weight: 500;
  }

  /* Modal */
  .modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.8);
    display: grid;
    place-items: center;
    z-index: 2000;
  }

  .modal {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 24px;
    max-width: 400px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .modal-large {
    max-width: 800px;
    width: 90vw;
  }

  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--border);
  }

  .modal-content {
    max-height: 60vh;
    overflow-y: auto;
    padding: 4px;
  }

  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
    padding-top: 16px;
    border-top: 1px solid var(--border);
  }

  .modal h3 {
    font-size: 18px;
    font-weight: 600;
    margin: 0;
    color: var(--text-primary);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .modal p {
    font-size: 14px;
    color: var(--text-secondary);
    margin: 0;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .warning-text {
    color: var(--danger);
    font-weight: 500;
  }

  .modal-actions {
    display: flex;
    gap: 12px;
    margin-top: 8px;
  }

  /* Members Table */
  .members-table {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .table-header {
    display: grid;
    grid-template-columns: 2fr 1.5fr 1fr 1.5fr;
    gap: 12px;
    padding: 12px 16px;
    background: var(--bg-sidebar);
    border-radius: 8px;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .table-row {
    display: grid;
    grid-template-columns: 2fr 1.5fr 1fr 1.5fr;
    gap: 12px;
    padding: 14px 16px;
    background: var(--bg-dark);
    border-radius: 8px;
    font-size: 14px;
    color: var(--text-primary);
    transition: all 150ms ease;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .table-row:hover {
    background: var(--bg-sidebar);
  }

  .th, .td {
    display: flex;
    align-items: center;
  }

  .rank-badge {
    padding: 4px 12px;
    background: linear-gradient(135deg, var(--accent), var(--accent-hover));
    color: white;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    display: inline-block;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .status-badge {
    padding: 4px 12px;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    display: inline-block;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .status-badge.online {
    background: rgba(34, 197, 94, 0.15);
    color: #22c55e;
    border: 1px solid rgba(34, 197, 94, 0.3);
  }

  .status-badge.offline {
    background: rgba(107, 114, 128, 0.15);
    color: #9ca3af;
    border: 1px solid rgba(107, 114, 128, 0.3);
  }

  /* Ranks Grid */
  .ranks-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
  }

  .rank-card {
    background: var(--bg-dark);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    transition: all 150ms ease;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .rank-card:hover {
    border-color: var(--border-light);
    transform: translateY(-2px);
  }

  .rank-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--border);
  }

  .rank-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .rank-name {
    font-size: 16px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .rank-grade {
    font-size: 12px;
    color: var(--text-dim);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .rank-count {
    font-size: 14px;
    font-weight: 600;
    color: var(--accent);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .rank-permissions {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .permissions-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .permissions-list {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .permission-badge {
    padding: 4px 10px;
    background: rgba(99, 102, 241, 0.15);
    color: var(--accent-light);
    border: 1px solid rgba(99, 102, 241, 0.3);
    border-radius: 6px;
    font-size: 11px;
    font-weight: 500;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .permission-badge.all {
    background: linear-gradient(135deg, rgba(34, 197, 94, 0.2), rgba(16, 185, 129, 0.2));
    color: #22c55e;
    border: 1px solid rgba(34, 197, 94, 0.4);
  }

  .permission-badge.empty {
    background: rgba(107, 114, 128, 0.15);
    color: var(--text-dim);
    border: 1px solid rgba(107, 114, 128, 0.3);
  }

  /* Edit Gang Modal */
  .edit-gang-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
  }

  .edit-section {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .edit-section.full-width {
    grid-column: 1 / -1;
  }

  .section-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .stats-display {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  .stat-item {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 12px;
    background: var(--bg-dark);
    border: 1px solid var(--border);
    border-radius: 8px;
  }

  .stat-item .stat-label {
    font-size: 11px;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-weight: 600;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .stat-item .stat-value {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .quick-actions {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
  }

  /* Scrollbar */
  ::-webkit-scrollbar {
    width: 8px;
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

  /* Notifications */
  .notification-container {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 3000;
    display: flex;
    flex-direction: column;
    gap: 12px;
    pointer-events: none;
  }

  .notification {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    min-width: 320px;
    max-width: 420px;
    padding: 16px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-light);
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
    pointer-events: auto;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .notification-success {
    border-left: 4px solid #22c55e;
  }

  .notification-error {
    border-left: 4px solid var(--danger);
  }

  .notification-info {
    border-left: 4px solid var(--accent);
  }

  .notification-icon {
    width: 24px;
    height: 24px;
    flex-shrink: 0;
    display: grid;
    place-items: center;
    margin-top: 2px;
  }

  .notification-success :global(.icon) {
    color: #22c55e;
    width: 24px;
    height: 24px;
  }

  .notification-error :global(.icon) {
    color: var(--danger);
    width: 24px;
    height: 24px;
  }

  .notification-info :global(.icon) {
    color: var(--accent);
    width: 24px;
    height: 24px;
  }

  .notification-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .notification-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    line-height: 1.4;
  }

  .notification-message {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.4;
  }

  .notification-close {
    width: 20px;
    height: 20px;
    padding: 0;
    display: grid;
    place-items: center;
    background: transparent;
    border: none;
    color: var(--text-dim);
    cursor: pointer;
    border-radius: 4px;
    transition: all 150ms ease;
    flex-shrink: 0;
  }

  .notification-close:hover {
    background: var(--bg-sidebar);
    color: var(--text-primary);
  }

  .close-icon-sm {
    width: 16px;
    height: 16px;
  }
</style>
