<script lang="ts">
  import { onMount } from 'svelte';
  import { fade, fly, scale } from 'svelte/transition';
  import { fetchNui } from '../../utils/fetchNui';
  import { locales } from '../../stores/localeStore';
  
  // Icons
  import PlusIcon from "virtual:icons/mdi/plus";
  import PencilIcon from "virtual:icons/mdi/pencil";
  import TrashIcon from "virtual:icons/mdi/delete";
  import CheckIcon from "virtual:icons/mdi/check";
  import CloseIcon from "virtual:icons/mdi/close";
  import ShieldIcon from "virtual:icons/mdi/shield-account";
  import ChevronDownIcon from "virtual:icons/mdi/chevron-down";
  import ChevronUpIcon from "virtual:icons/mdi/chevron-up";

  // Accept gangData prop from parent
  export let gangData: any = {
    gang: null,
    members: [],
    ranks: [],
    stats: {},
    isOwner: false,
    hasManagePermission: false,
    playerIdentifier: null
  };
  export let onRefresh: () => Promise<void>;

  interface Rank {
    id: number;
    name: string;
    grade: number;
    permissions: any;
  }

  // Use real data from prop
  $: ranks = gangData?.ranks || [];
  $: console.log('[ManageRanks] Ranks updated, count:', ranks.length, ranks);

  // Available permissions
  const availablePermissions = [
    { id: 'invite_members', label: 'Invite Members', description: 'Can invite new members to the gang' },
    { id: 'kick_members', label: 'Kick Members', description: 'Can remove members from the gang' },
    { id: 'promote_members', label: 'Promote Members', description: 'Can promote members to higher ranks' },
    { id: 'demote_members', label: 'Demote Members', description: 'Can demote members to lower ranks' },
    { id: 'manage_ranks', label: 'Manage Ranks', description: 'Can create, edit, and delete ranks' },
    { id: 'manage_permissions', label: 'Manage Permissions', description: 'Can modify rank permissions' },
    { id: 'access_stash', label: 'Access Stash', description: 'Can access the gang stash' },
    { id: 'view_audit_log', label: 'View Audit Log', description: 'Can view gang activity logs' },
    { id: 'manage_unlocks', label: 'Manage Unlocks', description: 'Can purchase gang unlocks' },
    { id: 'start_gangwar', label: 'Start Gang War', description: 'Can initiate gang wars' },
    { id: 'withdraw_money', label: 'Withdraw Money', description: 'Can withdraw from gang treasury' },
    { id: 'deposit_money', label: 'Deposit Money', description: 'Can deposit to gang treasury' },
    { id: 'view_stats', label: 'View Statistics', description: 'Can view gang statistics' },
    { id: 'manage_settings', label: 'Manage Settings', description: 'Can modify gang settings' },
  ];

  let showCreateModal = false;
  let showRenameModal = false;
  let showDeleteConfirm = false;
  let expandedRankId: number | null = null;
  
  let selectedRank: Rank | null = null;
  let newRankName = '';
  let newRankPermissions: string[] = [];
  let renameValue = '';
  let editingPermissions: string[] = [];

  onMount(async () => {
    console.log('[ManageRanks] Received gangData:', gangData);
  });

  function openCreateModal() {
    newRankName = '';
    newRankPermissions = [];
    showCreateModal = true;
  }

  function closeCreateModal() {
    showCreateModal = false;
    newRankName = '';
    newRankPermissions = [];
  }

  function togglePermission(permissionId: string) {
    if (newRankPermissions.includes(permissionId)) {
      newRankPermissions = newRankPermissions.filter(p => p !== permissionId);
    } else {
      newRankPermissions = [...newRankPermissions, permissionId];
    }
  }

  async function createRank() {
    if (!newRankName.trim()) {
      fetchNui('trase_gangs:notify', {
        title: 'Create Rank',
        description: 'Please enter a rank name',
        type: 'error'
      });
      return;
    }

    try {
      console.log('[createRank] Sending request with:', { name: newRankName, permissions: newRankPermissions });
      const response = await fetchNui('createRank', { 
        name: newRankName, 
        permissions: newRankPermissions 
      });
      
      console.log('[createRank] Response:', response);
      
      if (response && response.success) {
        console.log('[createRank] Success! Closing modal and showing notification');
        closeCreateModal();
        
        // Show success notification
        fetchNui('trase_gangs:notify', {
          title: 'Create Rank',
          description: 'Rank created successfully',
          type: 'success'
        });
        
        // Try to refresh from server first
        console.log('[createRank] Calling onRefresh...');
        await onRefresh();
        console.log('[createRank] onRefresh completed');
        
        // If refresh failed and response contains the new rank data, add it manually
        if (response.newRank || response.result) {
          const newRank = response.newRank || response.result;
          console.log('[createRank] Checking if rank exists in UI. New rank:', JSON.stringify(newRank));
          console.log('[createRank] Current ranks before update:', JSON.stringify(gangData.ranks.map((r: Rank) => ({ id: r.id, name: r.name, grade: r.grade }))));
          
          // Check if rank already exists (from successful refresh)
          const exists = gangData.ranks.some((r: Rank) => r.id === newRank.id);
          if (!exists) {
            console.log('[createRank] Rank not found in UI, adding manually with grade shifts');
            
            // New rank is inserted at grade 0, so shift all existing ranks up by 1
            const updatedRanks = gangData.ranks.map((r: Rank) => ({
              ...r,
              grade: r.grade + 1
            }));
            
            // Create completely new gangData object to trigger reactivity
            // Add new rank at the end since it has the lowest grade (0)
            gangData = {
              ...gangData,
              ranks: [...updatedRanks, newRank]
            };
            console.log('[createRank] Updated gangData ranks:', JSON.stringify(gangData.ranks.map((r: Rank) => ({ id: r.id, name: r.name, grade: r.grade }))));
          } else {
            console.log('[createRank] Rank already in UI from refresh');
          }
        }
      } else {
        console.error('[createRank] Failed:', response);
        fetchNui('trase_gangs:notify', {
          title: 'Create Rank',
          description: $locales[response?.result] || 'Failed to create rank: ' + (response?.result || 'unknown error'),
          type: 'error'
        });
      }
    } catch (e) {
      console.error('[createRank] Error:', e);
      fetchNui('trase_gangs:notify', {
        title: 'Create Rank',
        description: $locales['failed_to_create_rank'] || 'Failed to create rank: ' + e.message,
        type: 'error'
      });
    }
  }

  function toggleRankExpansion(rank: Rank) {
    if (expandedRankId === rank.id) {
      expandedRankId = null;
      editingPermissions = [];
    } else {
      expandedRankId = rank.id;
      editingPermissions = getPermissionKeys(rank.permissions);
    }
  }

  function toggleEditingPermission(permissionId: string) {
    if (editingPermissions.includes(permissionId)) {
      editingPermissions = editingPermissions.filter(p => p !== permissionId);
    } else {
      editingPermissions = [...editingPermissions, permissionId];
    }
  }

  async function saveInlinePermissions(rank: Rank) {
    try {
      const response = await fetchNui('updateRankPermissions', { 
        rankId: rank.id,
        name: rank.name,
        grade: rank.grade,
        permissions: editingPermissions 
      });
      
      if (response && response.success && response.updatedRank) {
        // Find and replace the specific rank in the array
        const rankIndex = gangData.ranks.findIndex((r: Rank) => r.id === rank.id);
        if (rankIndex !== -1) {
          gangData.ranks[rankIndex] = response.updatedRank;
          gangData.ranks = [...gangData.ranks]; // Trigger reactivity
        }
        expandedRankId = null;
        editingPermissions = [];
        fetchNui('trase_gangs:notify', {
          title: 'Update Permissions',
          description: 'Rank permissions updated successfully',
          type: 'success'
        });
      } else {
        fetchNui('trase_gangs:notify', {
          title: 'Update Permissions',
          description: 'Failed to update permissions: ' + (response?.result || 'unknown error'),
          type: 'error'
        });
      }
    } catch (e) {
      console.error('Failed to update permissions:', e);
      fetchNui('trase_gangs:notify', {
        title: 'Update Permissions',
        description: 'Failed to update permissions',
        type: 'error'
      });
    }
  }

  function cancelInlineEdit() {
    expandedRankId = null;
    editingPermissions = [];
  }

  function openRenameModal(rank: Rank) {
    selectedRank = rank;
    renameValue = rank.name;
    showRenameModal = true;
  }

  function closeRenameModal() {
    showRenameModal = false;
    selectedRank = null;
    renameValue = '';
  }

  async function renameRank() {
    if (!selectedRank || !renameValue.trim()) return;

    try {
      const response = await fetchNui('renameRank', { 
        rankId: selectedRank.id, 
        name: renameValue,
        grade: selectedRank.grade,
        permissions: selectedRank.permissions
      });
      
      if (response && response.success && response.updatedRank) {
        // Find and replace the specific rank in the array
        const rankIndex = gangData.ranks.findIndex((r: Rank) => r.id === selectedRank.id);
        if (rankIndex !== -1) {
          gangData.ranks[rankIndex] = response.updatedRank;
          gangData.ranks = [...gangData.ranks]; // Trigger reactivity
        }
        closeRenameModal();
        fetchNui('trase_gangs:notify', {
          title: 'Rename Rank',
          description: 'Rank renamed successfully',
          type: 'success'
        });
      } else {
        fetchNui('trase_gangs:notify', {
          title: 'Rename Rank',
          description: 'Failed to rename rank: ' + (response?.result || 'unknown error'),
          type: 'error'
        });
      }
    } catch (e) {
      console.error('Failed to rename rank:', e);
      fetchNui('trase_gangs:notify', {
        title: 'Rename Rank',
        description: 'Failed to rename rank',
        type: 'error'
      });
    }
  }

  function openDeleteConfirm(rank: Rank) {
    selectedRank = rank;
    showDeleteConfirm = true;
  }

  function closeDeleteConfirm() {
    showDeleteConfirm = false;
    selectedRank = null;
  }

  async function confirmDeleteRank() {
    if (!selectedRank) return;

    console.log('[ManageRanks] Deleting rank:', selectedRank.id);
    try {
      const response = await fetchNui('deleteRank', { rankId: selectedRank.id });
      console.log('[ManageRanks] Delete response:', response);
      
      if (response && response.success && response.updatedRanks) {
        // Replace the entire ranks array with the updated ranks (grades adjusted)
        gangData.ranks = response.updatedRanks;
        closeDeleteConfirm();
        fetchNui('trase_gangs:notify', {
          title: 'Delete Rank',
          description: 'Rank deleted and grades adjusted successfully',
          type: 'success'
        });
      } else {
        fetchNui('trase_gangs:notify', {
          title: 'Delete Rank',
          description: 'Failed to delete rank: ' + (response?.result || 'unknown error'),
          type: 'error'
        });
      }
    } catch (e) {
      console.error('Failed to delete rank:', e);
      fetchNui('trase_gangs:notify', {
        title: 'Delete Rank',
        description: 'Failed to delete rank',
        type: 'error'
      });
    }
  }

  async function moveRankUp(rank: Rank) {
    try {
      const response = await fetchNui('reorderRank', { 
        rankId: rank.id,
        direction: 'up'
      });
      
      if (response && response.success && response.updatedRanks) {
        gangData.ranks = response.updatedRanks;
        fetchNui('notify', {
          title: 'Reorder Rank',
          description: 'Rank position updated',
          type: 'success'
        });
      } else {
        fetchNui('trase_gangs:notify', {
          title: 'Reorder Rank',
          description: 'Cannot move rank up',
          type: 'error'
        });
      }
    } catch (e) {
      console.error('Failed to reorder rank:', e);
    }
  }

  async function moveRankDown(rank: Rank) {
    try {
      const response = await fetchNui('reorderRank', { 
        rankId: rank.id,
        direction: 'down'
      });
      
      if (response && response.success && response.updatedRanks) {
        gangData.ranks = response.updatedRanks;
        fetchNui('trase_gangs:notify', {
          title: 'Reorder Rank',
          description: 'Rank position updated',
          type: 'success'
        });
      } else {
        fetchNui('trase_gangs:notify', {
          title: 'Reorder Rank',
          description: 'Cannot move rank down',
          type: 'error'
        });
      }
    } catch (e) {
      console.error('Failed to reorder rank:', e);
    }
  }

  function canMoveUp(rank: Rank): boolean {
    const maxGrade = Math.max(...ranks.map((r: Rank) => r.grade));
    return rank.grade < maxGrade;
  }

  function canMoveDown(rank: Rank): boolean {
    return rank.grade > 0;
  }

  function getPermissionLabel(permissionId: string): string {
    return availablePermissions.find(p => p.id === permissionId)?.label || permissionId;
  }

  function getPermissionKeys(permissions: any): string[] {
    if (Array.isArray(permissions)) {
      return permissions;
    }
    if (typeof permissions === 'object' && permissions !== null) {
      // If permissions is an object like { invite_members: true }, extract keys where value is true
      return Object.keys(permissions).filter(key => permissions[key] === true);
    }
    return [];
  }
</script>

<div class="manage-ranks" in:fade={{ duration: 200 }}>
  <!-- Header -->
  <div class="header" in:fly={{ y: -20, duration: 250, delay: 50 }}>
    <div class="header-content">
      <ShieldIcon class="header-icon" />
      <div>
        <h2>Manage Ranks</h2>
        <p>Create and configure gang rank permissions</p>
      </div>
    </div>
    <button class="create-btn" on:click={openCreateModal} in:scale={{ start: 0.8, duration: 250, delay: 100 }}>
      <PlusIcon />
      <span>Create Rank</span>
    </button>
  </div>

  <!-- Ranks Table -->
  <div class="table-container" in:fly={{ y: 20, duration: 250, delay: 150 }}>
    <table>
      <thead>
        <tr>
          <th>Grade</th>
          <th>Rank Name</th>
          <th>Permissions</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {#each ranks as rank, i (rank.id)}
          <tr class:expanded={expandedRankId === rank.id} in:fly={{ y: 20, duration: 250, delay: 200 + (i * 50) }}>
            <td class="position-cell">
              <div class="position-badge">{rank.grade}</div>
            </td>
            <td class="name-cell">
              <div class="rank-name">{rank.name}</div>
            </td>
            <td class="permissions-cell" on:click={() => toggleRankExpansion(rank)}>
              <div class="permissions-preview clickable">
                {#if getPermissionKeys(rank.permissions).length === 0}
                  <span class="no-permissions">No permissions</span>
                {:else if getPermissionKeys(rank.permissions).length === availablePermissions.length}
                  <span class="all-permissions">All permissions</span>
                {:else}
                  <span class="permission-count">{getPermissionKeys(rank.permissions).length} permission{getPermissionKeys(rank.permissions).length !== 1 ? 's' : ''}</span>
                {/if}
                <button class="expand-icon">
                  {#if expandedRankId === rank.id}
                    <ChevronUpIcon />
                  {:else}
                    <ChevronDownIcon />
                  {/if}
                </button>
              </div>
            </td>
            <td class="actions-cell">
              <div class="actions">
                {#if canMoveUp(rank)}
                  <button class="action-btn reorder" on:click={() => moveRankUp(rank)} title="Move rank up">
                    <ChevronUpIcon />
                  </button>
                {/if}
                {#if canMoveDown(rank)}
                  <button class="action-btn reorder" on:click={() => moveRankDown(rank)} title="Move rank down">
                    <ChevronDownIcon />
                  </button>
                {/if}
                <button class="action-btn rename" on:click={() => openRenameModal(rank)} title="Rename rank">
                  <PencilIcon />
                </button>
                <button class="action-btn delete" on:click={() => openDeleteConfirm(rank)} title="Delete rank">
                  <TrashIcon />
                </button>
              </div>
            </td>
          </tr>
          {#if expandedRankId === rank.id}
            <tr class="permissions-row" transition:fly={{ y: -10, duration: 200 }}>
              <td colspan="4">
                <div class="permissions-editor">
                  <div class="permissions-header">
                    <h4>Configure Permissions for {rank.name}</h4>
                    <div class="permissions-actions">
                      <button class="btn btn-secondary" on:click={cancelInlineEdit}>Cancel</button>
                      <button class="btn btn-primary" on:click={() => saveInlinePermissions(rank)}>
                        <CheckIcon />
                        <span>Save Changes</span>
                      </button>
                    </div>
                  </div>
                  <div class="permissions-grid-inline">
                    {#each availablePermissions as permission}
                      <label class="permission-item-inline">
                        <input 
                          type="checkbox" 
                          checked={editingPermissions.includes(permission.id)}
                          on:change={() => toggleEditingPermission(permission.id)}
                        />
                        <div class="permission-info">
                          <div class="permission-label">{permission.label}</div>
                          <div class="permission-description">{permission.description}</div>
                        </div>
                      </label>
                    {/each}
                  </div>
                </div>
              </td>
            </tr>
          {/if}
        {/each}
      </tbody>
    </table>
  </div>
</div>

<!-- Create Rank Modal -->
{#if showCreateModal}
  <div class="modal-overlay" on:click={closeCreateModal} transition:fade={{ duration: 200 }}>
    <div class="modal" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="modal-header">
        <h3>Create New Rank</h3>
        <button class="close-btn" on:click={closeCreateModal}>
          <CloseIcon />
        </button>
      </div>
      
      <div class="modal-body">
        <div class="form-group">
          <label for="rank-name">Rank Name</label>
          <input 
            id="rank-name"
            type="text" 
            bind:value={newRankName} 
            placeholder="Enter rank name..."
            maxlength="50"
          />
        </div>

        <div class="form-group">
          <label>Permissions ({newRankPermissions.length} selected)</label>
          <div class="permissions-grid">
            {#each availablePermissions as permission}
              <label class="permission-item">
                <input 
                  type="checkbox" 
                  checked={newRankPermissions.includes(permission.id)}
                  on:change={() => togglePermission(permission.id)}
                />
                <div class="permission-info">
                  <div class="permission-label">{permission.label}</div>
                  <div class="permission-description">{permission.description}</div>
                </div>
              </label>
            {/each}
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeCreateModal}>Cancel</button>
        <button class="btn btn-primary" on:click={createRank}>
          <CheckIcon />
          <span>Create Rank</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Delete Confirmation Modal -->
{#if showDeleteConfirm && selectedRank}
  <div class="modal-overlay" on:click={closeDeleteConfirm} transition:fade={{ duration: 200 }}>
    <div class="modal small confirm-modal" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="modal-header">
        <h3>Delete Rank</h3>
        <button class="close-btn" on:click={closeDeleteConfirm}>
          <CloseIcon />
        </button>
      </div>
      
      <div class="modal-body">
        <div class="confirm-content">
          <div class="confirm-icon">
            <TrashIcon />
          </div>
          <div class="confirm-text">
            <p class="confirm-title">Are you sure you want to delete this rank?</p>
            <p class="confirm-description">
              You are about to delete the <strong>"{selectedRank.name}"</strong> rank. This action cannot be undone.
            </p>
          </div>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeDeleteConfirm}>Cancel</button>
        <button class="btn btn-danger" on:click={confirmDeleteRank}>
          <TrashIcon />
          <span>Delete Rank</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Rename Modal -->
{#if showRenameModal && selectedRank}
  <div class="modal-overlay" on:click={closeRenameModal} transition:fade={{ duration: 200 }}>
    <div class="modal small" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="modal-header">
        <h3>Rename Rank</h3>
        <button class="close-btn" on:click={closeRenameModal}>
          <CloseIcon />
        </button>
      </div>
      
      <div class="modal-body">
        <div class="form-group">
          <label for="rename-input">Rank Name</label>
          <input 
            id="rename-input"
            type="text" 
            bind:value={renameValue} 
            placeholder="Enter new rank name..."
            maxlength="50"
          />
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeRenameModal}>Cancel</button>
        <button class="btn btn-primary" on:click={renameRank}>
          <CheckIcon />
          <span>Rename</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .manage-ranks {
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
    background: linear-gradient(135deg, rgba(99, 102, 241, 0.15), rgba(79, 70, 229, 0.15));
    border-radius: 12px;
    color: var(--accent);
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
    background: rgba(99, 102, 241, 0.05);
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
    background: rgba(99, 102, 241, 0.03);
  }

  tbody tr.expanded {
    background: rgba(99, 102, 241, 0.05);
  }

  td {
    padding: 16px;
    color: var(--text-primary);
  }

  .position-cell {
    width: 100px;
  }

  .position-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    background: linear-gradient(135deg, rgba(99, 102, 241, 0.15), rgba(79, 70, 229, 0.15));
    border: 1px solid rgba(99, 102, 241, 0.3);
    border-radius: 8px;
    font-size: 14px;
    font-weight: 700;
    color: var(--accent);
  }

  .name-cell {
    min-width: 200px;
  }

  .rank-name {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .permissions-cell {
    min-width: 200px;
    cursor: pointer;
  }

  .permissions-preview {
    font-size: 14px;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .permissions-preview.clickable {
    transition: all 150ms ease;
  }

  .permissions-preview.clickable:hover {
    color: var(--accent);
  }

  .expand-icon {
    width: 24px;
    height: 24px;
    display: grid;
    place-items: center;
    background: transparent;
    border: none;
    cursor: pointer;
    color: var(--text-secondary);
    transition: all 150ms ease;
    margin-left: auto;
  }

  .expand-icon:hover {
    color: var(--accent);
  }

  .no-permissions {
    color: var(--text-dim);
    font-style: italic;
  }

  .all-permissions {
    color: #22c55e;
    font-weight: 500;
  }

  .permission-count {
    color: var(--accent);
    font-weight: 500;
  }

  .actions-cell {
    width: 150px;
  }

  .actions {
    display: flex;
    gap: 8px;
  }

  .action-btn {
    width: 36px;
    height: 36px;
    display: grid;
    place-items: center;
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 6px;
    cursor: pointer;
    transition: all 150ms ease;
    color: var(--text-secondary);
  }

  .action-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
  }

  .action-btn.rename:hover {
    background: rgba(59, 130, 246, 0.1);
    border-color: #3b82f6;
    color: #3b82f6;
  }

  .action-btn.permissions:hover {
    background: rgba(139, 92, 246, 0.1);
    border-color: #8b5cf6;
    color: #8b5cf6;
  }

  .action-btn.delete:hover {
    background: rgba(239, 68, 68, 0.1);
    border-color: #ef4444;
    color: #ef4444;
  }

  .action-btn.reorder:hover {
    background: rgba(234, 179, 8, 0.1);
    border-color: #eab308;
    color: #eab308;
  }

  /* Inline Permissions Editor */
  .permissions-row {
    background: var(--bg-base) !important;
  }

  .permissions-row td {
    padding: 0 !important;
  }

  .permissions-editor {
    padding: 24px;
    border-top: 1px solid var(--border);
  }

  .permissions-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    gap: 16px;
  }

  .permissions-header h4 {
    margin: 0;
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .permissions-actions {
    display: flex;
    gap: 12px;
  }

  .permissions-grid-inline {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 12px;
    max-height: 400px;
    overflow-y: auto;
    padding: 4px;
  }

  .permission-item-inline {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 12px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 8px;
    cursor: pointer;
    transition: all 150ms ease;
  }

  .permission-item-inline:hover {
    border-color: var(--accent);
    background: rgba(99, 102, 241, 0.05);
  }

  .permission-item-inline input[type="checkbox"] {
    margin-top: 2px;
    width: 18px;
    height: 18px;
    cursor: pointer;
    accent-color: var(--accent);
    flex-shrink: 0;
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
    max-width: 700px;
    max-height: 80vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
  }

  .modal.small {
    max-width: 450px;
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
    overflow-y: auto;
    flex: 1;
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

  .form-group input[type="text"] {
    padding: 12px 16px;
    background: var(--bg-base);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-primary);
    font-size: 14px;
    font-family: 'Inter', sans-serif;
    transition: all 150ms ease;
  }

  .form-group input[type="text"]:focus {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
  }

  .permissions-grid {
    display: flex;
    flex-direction: column;
    gap: 8px;
    max-height: 400px;
    overflow-y: auto;
    padding: 4px;
  }

  .permission-item {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 12px;
    background: var(--bg-base);
    border: 1px solid var(--border);
    border-radius: 8px;
    cursor: pointer;
    transition: all 150ms ease;
  }

  .permission-item:hover {
    border-color: var(--accent);
    background: rgba(99, 102, 241, 0.05);
  }

  .permission-item input[type="checkbox"] {
    margin-top: 2px;
    width: 18px;
    height: 18px;
    cursor: pointer;
    accent-color: var(--accent);
  }

  .permission-info {
    flex: 1;
  }

  .permission-label {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: 2px;
  }

  .permission-description {
    font-size: 12px;
    color: var(--text-secondary);
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

  .btn-danger {
    background: #ef4444;
    color: white;
  }

  .btn-danger:hover {
    background: #dc2626;
    transform: translateY(-1px);
  }

  /* Confirmation Modal */
  .confirm-modal .modal-body {
    padding: 32px 24px;
  }

  .confirm-content {
    display: flex;
    gap: 20px;
    align-items: flex-start;
  }

  .confirm-icon {
    width: 48px;
    height: 48px;
    display: grid;
    place-items: center;
    background: rgba(239, 68, 68, 0.1);
    border: 2px solid rgba(239, 68, 68, 0.3);
    border-radius: 12px;
    color: #ef4444;
    flex-shrink: 0;
  }

  .confirm-icon :global(svg) {
    width: 24px;
    height: 24px;
  }

  .confirm-text {
    flex: 1;
  }

  .confirm-title {
    margin: 0 0 8px 0;
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .confirm-description {
    margin: 0;
    font-size: 14px;
    line-height: 1.5;
    color: var(--text-secondary);
  }

  .confirm-description strong {
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

    .create-btn {
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
