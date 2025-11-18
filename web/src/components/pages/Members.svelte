<script lang="ts">
  import { onMount } from 'svelte';
  import { fade, fly, scale } from 'svelte/transition';
  import { fetchNui } from '../../utils/fetchNui';
  
  // Icons
  import UsersIcon from "virtual:icons/mdi/account-group";
  import ArrowUpIcon from "virtual:icons/mdi/arrow-up";
  import ArrowDownIcon from "virtual:icons/mdi/arrow-down";
  import TrashIcon from "virtual:icons/mdi/delete";
  import CrownIcon from "virtual:icons/mdi/crown";
  import CircleIcon from "virtual:icons/mdi/circle";
  import CheckIcon from "virtual:icons/mdi/check";
  import CloseIcon from "virtual:icons/mdi/close";

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

  interface Member {
    name: string;
    identifier: string;
    rank: string;
    rankGrade: number;
    online: boolean;
    joined: string;
  }

  interface Rank {
    id: number;
    name: string;
    grade: number;
    members: number;
    permissions: any;
  }

  // Use real data from prop
  $: members = gangData.members || [];
  $: ranks = gangData.ranks || [];
  $: {
    console.log('[Members] Members updated:', members);
    if (members.length > 0) {
      console.log('[Members] Displaying members:', members.map((m: any) => ({ identifier: m.identifier, name: m.name })));
    }
  }

  let showPromoteModal = false;
  let showDemoteModal = false;
  let showKickModal = false;
  let selectedMember: Member | null = null;
  let selectedRankGrade: number | null = null;

  onMount(async () => {
    console.log('[Members] Received gangData:', gangData);
    console.log('[Members] Members array:', gangData.members);
    if (gangData.members && gangData.members.length > 0) {
      console.log('[Members] First member:', gangData.members[0]);
      console.log('[Members] Member names:', gangData.members.map((m: any) => m.name));
    }
  });

  function formatDate(dateString: string): string {
    if (!dateString) return 'Unknown';
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    });
  }

  function getAvailableRanksForPromotion(member: Member): Rank[] {
    const currentGrade = member.rankGrade;
    
    // Return ranks with higher grade (higher rank)
    return ranks.filter(r => r.grade > currentGrade);
  }

  function getAvailableRanksForDemotion(member: Member): Rank[] {
    const currentGrade = member.rankGrade;
    
    // Return ranks with lower grade (lower rank)
    return ranks.filter(r => r.grade < currentGrade);
  }

  function canPromote(member: Member): boolean {
    return getAvailableRanksForPromotion(member).length > 0;
  }

  function canDemote(member: Member): boolean {
    // Cannot demote the owner
    if (gangData.gang && member.identifier === gangData.gang.owner_identifier) return false;
    return getAvailableRanksForDemotion(member).length > 0;
  }
  
  function isOwner(member: Member): boolean {
    return gangData.gang && member.identifier === gangData.gang.owner_identifier;
  }

  function openPromoteModal(member: Member) {
    const availableRanks = getAvailableRanksForPromotion(member);
    if (availableRanks.length === 0) return;
    
    selectedMember = member;
    selectedRankGrade = availableRanks[0].grade;
    showPromoteModal = true;
  }

  function openDemoteModal(member: Member) {
    const availableRanks = getAvailableRanksForDemotion(member);
    if (availableRanks.length === 0) return;
    
    selectedMember = member;
    selectedRankGrade = availableRanks[0].grade;
    showDemoteModal = true;
  }

  function closePromoteModal() {
    showPromoteModal = false;
    selectedMember = null;
    selectedRankGrade = null;
  }

  function closeDemoteModal() {
    showDemoteModal = false;
    selectedMember = null;
    selectedRankGrade = null;
  }

  function openKickModal(member: Member) {
    selectedMember = member;
    showKickModal = true;
  }

  function closeKickModal() {
    showKickModal = false;
    selectedMember = null;
  }

  async function promoteMember() {
    if (!selectedMember || !selectedRankId) return;

    const newRank = ranks.find(r => r.id === selectedRankId);
    if (!newRank) return;

    try {
      await fetchNui('promoteMember', { 
        memberId: selectedMember.id, 
        rankId: selectedRankId 
      });
      
      members = members.map(m => 
        m.id === selectedMember.id 
          ? { ...m, rankId: selectedRankId, rankName: newRank.name }
          : m
      );
      closePromoteModal();
    } catch (e) {
      console.error('Failed to promote member:', e);
      // Update locally anyway for development
      members = members.map(m => 
        m.id === selectedMember.id 
          ? { ...m, rankId: selectedRankId, rankName: newRank.name }
          : m
      );
      closePromoteModal();
    }
  }

  async function demoteMember() {
    if (!selectedMember || !selectedRankId) return;

    const newRank = ranks.find(r => r.id === selectedRankId);
    if (!newRank) return;

    try {
      await fetchNui('demoteMember', { 
        memberId: selectedMember.id, 
        rankId: selectedRankId 
      });
      
      members = members.map(m => 
        m.id === selectedMember.id 
          ? { ...m, rankId: selectedRankId, rankName: newRank.name }
          : m
      );
      closeDemoteModal();
    } catch (e) {
      console.error('Failed to demote member:', e);
      // Update locally anyway for development
      members = members.map(m => 
        m.id === selectedMember.id 
          ? { ...m, rankId: selectedRankId, rankName: newRank.name }
          : m
      );
      closeDemoteModal();
    }
  }

  async function kickMember() {
    if (!selectedMember) return;

    try {
      await fetchNui('kickMember', { memberId: selectedMember.id });
      members = members.filter(m => m.id !== selectedMember.id);
      closeKickModal();
    } catch (e) {
      console.error('Failed to kick member:', e);
      // Delete locally anyway for development
      members = members.filter(m => m.id !== selectedMember.id);
      closeKickModal();
    }
  }

  $: onlineCount = members.filter(m => m.online).length;
  $: totalCount = members.length;
</script>

<div class="members-page" in:fade={{ duration: 200 }}>
  <!-- Header -->
  <div class="header" in:fly={{ y: -20, duration: 250, delay: 50 }}>
    <div class="header-content">
      <UsersIcon class="header-icon" />
      <div>
        <h2>Gang Members</h2>
        <p>{onlineCount} online · {totalCount} total members</p>
      </div>
    </div>
  </div>

  <!-- Members Table -->
  <div class="table-container" in:fly={{ y: 20, duration: 250, delay: 150 }}>
    <table>
      <thead>
        <tr>
          <th>Status</th>
          <th>Member Name</th>
          <th>Rank</th>
          <th>Joined Date</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {#each members as member, i (member.identifier)}
          <tr in:fly={{ y: 20, duration: 250, delay: 200 + (i * 30) }}>
            <td class="status-cell">
              <div class="status-indicator" class:online={member.online}>
                <CircleIcon />
              </div>
            </td>
            <td class="name-cell">
              <div class="member-name">{member.name}</div>
            </td>
            <td class="rank-cell">
              <div class="rank-badge">
                <CrownIcon class="rank-icon" />
                <span>{member.rank}</span>
              </div>
            </td>
            <td class="date-cell">
              <span class="date-text">{formatDate(member.joined)}</span>
            </td>
            <td class="actions-cell">
              <div class="actions">
                {#if canPromote(member)}
                  <button 
                    class="action-btn promote" 
                    on:click={() => openPromoteModal(member)} 
                    title="Promote member"
                  >
                    <ArrowUpIcon />
                  </button>
                {/if}
                {#if canDemote(member)}
                  <button 
                    class="action-btn demote" 
                    on:click={() => openDemoteModal(member)} 
                    title="Demote member"
                  >
                    <ArrowDownIcon />
                  </button>
                {/if}
                {#if !isOwner(member)}
                  <button 
                    class="action-btn kick" 
                    on:click={() => openKickModal(member)} 
                    title="Kick member"
                  >
                    <TrashIcon />
                  </button>
                {/if}
              </div>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</div>

<!-- Promote Modal -->
{#if showPromoteModal && selectedMember}
  <div class="modal-overlay" on:click={closePromoteModal} transition:fade={{ duration: 200 }}>
    <div class="modal" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="modal-header">
        <h3>Promote Member</h3>
        <button class="close-btn" on:click={closePromoteModal}>
          <CloseIcon />
        </button>
      </div>
      
      <div class="modal-body">
        <p class="modal-description">
          Promote <strong>{selectedMember.name}</strong> from <strong>{selectedMember.rank}</strong> to:
        </p>
        
        <div class="form-group">
          <label for="promote-rank">Select Rank</label>
          <select id="promote-rank" bind:value={selectedRankGrade}>
            {#each getAvailableRanksForPromotion(selectedMember) as rank}
              <option value={rank.grade}>{rank.name}</option>
            {/each}
          </select>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closePromoteModal}>Cancel</button>
        <button class="btn btn-primary promote-btn" on:click={promoteMember}>
          <ArrowUpIcon />
          <span>Promote</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Demote Modal -->
{#if showDemoteModal && selectedMember}
  <div class="modal-overlay" on:click={closeDemoteModal} transition:fade={{ duration: 200 }}>
    <div class="modal" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="modal-header">
        <h3>Demote Member</h3>
        <button class="close-btn" on:click={closeDemoteModal}>
          <CloseIcon />
        </button>
      </div>
      
      <div class="modal-body">
        <p class="modal-description">
          Demote <strong>{selectedMember.name}</strong> from <strong>{selectedMember.rank}</strong> to:
        </p>
        
        <div class="form-group">
          <label for="demote-rank">Select Rank</label>
          <select id="demote-rank" bind:value={selectedRankGrade}>
            {#each getAvailableRanksForDemotion(selectedMember) as rank}
              <option value={rank.grade}>{rank.name}</option>
            {/each}
          </select>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeDemoteModal}>Cancel</button>
        <button class="btn btn-primary demote-btn" on:click={demoteMember}>
          <ArrowDownIcon />
          <span>Demote</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Kick Member Modal -->
{#if showKickModal && selectedMember}
  <div class="modal-overlay" on:click={closeKickModal} transition:fade={{ duration: 200 }}>
    <div class="modal confirm-modal" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 250 }}>
      <div class="modal-header">
        <h3>Kick Member</h3>
        <button class="close-btn" on:click={closeKickModal}>
          <CloseIcon />
        </button>
      </div>
      
      <div class="modal-body">
        <div class="warning-container">
          <TrashIcon class="warning-icon" />
          <p class="modal-description">
            Are you sure you want to kick <strong>{selectedMember.name}</strong> from the gang?
          </p>
          <p class="warning-text">
            This action cannot be undone. The member will lose access to all gang features.
          </p>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeKickModal}>Cancel</button>
        <button class="btn btn-danger" on:click={kickMember}>
          <TrashIcon />
          <span>Kick Member</span>
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .members-page {
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
    background: rgba(59, 130, 246, 0.05);
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
    background: rgba(59, 130, 246, 0.03);
  }

  td {
    padding: 16px;
    color: var(--text-primary);
  }

  .status-cell {
    width: 80px;
  }

  .status-indicator {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    color: #6b7280;
  }

  .status-indicator.online {
    color: #22c55e;
  }

  .name-cell {
    min-width: 200px;
  }

  .member-name {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .rank-cell {
    min-width: 150px;
  }

  .rank-badge {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 6px 12px;
    background: linear-gradient(135deg, rgba(234, 179, 8, 0.15), rgba(202, 138, 4, 0.15));
    border: 1px solid rgba(234, 179, 8, 0.3);
    border-radius: 6px;
  }

  .rank-icon {
    width: 16px;
    height: 16px;
    color: #eab308;
  }

  .rank-badge span {
    font-size: 13px;
    font-weight: 600;
    color: #eab308;
  }

  .date-cell {
    min-width: 130px;
  }

  .date-text {
    font-size: 14px;
    color: var(--text-secondary);
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

  .action-btn.promote:hover {
    background: rgba(34, 197, 94, 0.1);
    border-color: #22c55e;
    color: #22c55e;
  }

  .action-btn.demote:hover {
    background: rgba(234, 179, 8, 0.1);
    border-color: #eab308;
    color: #eab308;
  }

  .action-btn.kick:hover {
    background: rgba(239, 68, 68, 0.1);
    border-color: #ef4444;
    color: #ef4444;
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
  }

  .modal-description {
    margin: 0 0 20px 0;
    font-size: 14px;
    color: var(--text-secondary);
    line-height: 1.6;
  }

  .modal-description strong {
    color: var(--text-primary);
    font-weight: 600;
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

  .form-group select {
    padding: 12px 16px;
    background: var(--bg-base);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-primary);
    font-size: 14px;
    font-family: 'Inter', sans-serif;
    cursor: pointer;
    transition: all 150ms ease;
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

  .form-group select:focus {
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

  .btn-primary.promote-btn {
    background: #22c55e;
  }

  .btn-primary.promote-btn:hover {
    background: #16a34a;
  }

  .btn-primary.demote-btn {
    background: #eab308;
  }

  .btn-primary.demote-btn:hover {
    background: #ca8a04;
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

  .confirm-modal {
    max-width: 450px;
  }

  .warning-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    text-align: center;
  }

  .warning-icon {
    width: 56px;
    height: 56px;
    padding: 14px;
    background: rgba(239, 68, 68, 0.15);
    border: 2px solid rgba(239, 68, 68, 0.3);
    border-radius: 50%;
    color: #ef4444;
  }

  .warning-text {
    margin: 0;
    font-size: 13px;
    color: var(--text-dim);
    line-height: 1.5;
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

    .table-container {
      overflow-x: auto;
    }

    table {
      min-width: 700px;
    }
  }
</style>
