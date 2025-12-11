<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from '../../utils/translate';
  import { fade, fly, scale } from 'svelte/transition';
  import { fetchNui } from '../../utils/fetchNui';

  // Icons
  import TrophyIcon from "virtual:icons/mdi/trophy";
  import PillIcon from "virtual:icons/mdi/pill";
  import UsersIcon from "virtual:icons/mdi/account-group";
  import UserCheckIcon from "virtual:icons/mdi/account-check";
  import CashIcon from "virtual:icons/mdi/currency-usd";
  import TrendingUpIcon from "virtual:icons/mdi/trending-up";
  import BankIcon from "virtual:icons/mdi/bank";
  import ArrowDownIcon from "virtual:icons/mdi/arrow-down";
  import ArrowUpIcon from "virtual:icons/mdi/arrow-up";

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

  // Computed values from gangData
  $: gang = gangData.gang || {};
  $: members = gangData.members || [];
  $: stats = gangData.stats || {};
  $: onlineMembersCount = members.filter((m: any) => m.online).length;
  $: totalMembers = members.length;
  $: gangBank = gang.bank || 0;

  // Bank transaction state
  let showBankModal = false;
  let bankAction: 'deposit' | 'withdraw' = 'deposit';
  let bankAmount = '';
  let bankLoading = false;
  let bankError = '';

  onMount(async () => {
    console.log('[DashboardPage] Received gangData:', gangData);
  });

  function openBankModal(action: 'deposit' | 'withdraw') {
    bankAction = action;
    bankAmount = '';
    bankError = '';
    showBankModal = true;
  }

  function closeBankModal() {
    showBankModal = false;
    bankAmount = '';
    bankError = '';
  }

  async function handleBankTransaction() {
    const amount = parseInt(bankAmount);
    if (!amount || amount <= 0) {
      bankError = 'Please enter a valid amount';
      return;
    }

    if (bankAction === 'withdraw' && amount > gangBank) {
      bankError = 'Insufficient gang funds';
      return;
    }

    bankLoading = true;
    bankError = '';

    try {
      const response = await fetchNui('gangBankTransaction', {
        action: bankAction,
        amount: amount
      });

      if (response?.success) {
        // Update local gang bank value
        if (bankAction === 'deposit') {
          gang.bank = (gang.bank || 0) + amount;
        } else {
          gang.bank = (gang.bank || 0) - amount;
        }
        gangData.gang = gang;
        closeBankModal();
        
        fetchNui('trase_gangs:notify', {
          title: bankAction === 'deposit' ? 'Deposit Successful' : 'Withdrawal Successful',
          description: `$${amount.toLocaleString()} has been ${bankAction === 'deposit' ? 'deposited to' : 'withdrawn from'} the gang bank`,
          type: 'success'
        });
      } else {
        bankError = response?.error || 'Transaction failed';
      }
    } catch (e) {
      bankError = 'Transaction failed';
      console.error('Bank transaction error:', e);
    } finally {
      bankLoading = false;
    }
  }

  function formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value);
  }

  function handleLogoUpload() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = async (e: Event) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;

      // Check file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        alert('File size must be less than 5MB');
        return;
      }

      uploading = true;
      
      // Create preview
      const reader = new FileReader();
      reader.onload = async (e) => {
        const result = e.target?.result as string;
        logoPreview = result;
        
        try {
          // Send to server
          await fetchNui('uploadGangLogo', { logo: result });
          gangData.logo = result;
        } catch (error) {
          console.error('Failed to upload logo:', error);
          logoPreview = gangData.logo;
        } finally {
          uploading = false;
        }
      };
      reader.readAsDataURL(file);
    };
    input.click();
  }

  function removeLogo() {
    logoPreview = null;
    gangData.logo = null;
    fetchNui('removeGangLogo');
  }

  // Generate mini chart path
  function generateChartPath(data: number[], width: number = 100, height: number = 40): string {
    if (data.length === 0) return '';
    
    const max = Math.max(...data);
    const min = Math.min(...data);
    const range = max - min || 1;
    
    const points = data.map((value, index) => {
      const x = (index / (data.length - 1)) * width;
      const y = height - ((value - min) / range) * height;
      return `${x},${y}`;
    });
    
    return `M ${points.join(' L ')}`;
  }
</script>

<div class="dashboard" in:fade={{ duration: 200 }}>
  <!-- Gang Header -->
  <div class="gang-header" in:fly={{ y: -20, duration: 250, delay: 50 }}>
    <h2 class="gang-name">{gang.label || t('dashboard.gang_dashboard','Gang Dashboard')}</h2>
    <div class="rep-badge">
      <TrophyIcon class="rep-icon" />
      <span>{(gang.reputation || 0).toLocaleString()} REP</span>
    </div>
  </div>

  <!-- Stats Grid -->
  <div class="stats-grid">
    <!-- Total Revenue - First -->
    <div class="stat-card wide revenue-card" in:fly={{ y: 20, duration: 250, delay: 100 }}>
      <div class="stat-icon revenue">
        <CashIcon />
      </div>
      <div class="stat-content">
        <div class="stat-label">{t('dashboard.total_revenue','Total Revenue')}</div>
        <div class="stat-value">{formatCurrency(gang.total_revenue || 0)}</div>
        <div class="stat-subtext">{t('dashboard.all_time_earnings','All-time earnings')}</div>
      </div>
    </div>

    <!-- Online Members -->
    <div class="stat-card" in:fly={{ y: 20, duration: 250, delay: 150 }}>
      <div class="stat-icon online">
        <UserCheckIcon />
      </div>
      <div class="stat-content">
        <div class="stat-label">{t('dashboard.online_members','Online Members')}</div>
        <div class="stat-value">{onlineMembersCount}</div>
        <div class="stat-subtext">{t('dashboard.of_total','of {n} total').replace('{n}', String(totalMembers))}</div>
      </div>
    </div>

    <!-- Total Members -->
    <div class="stat-card" in:fly={{ y: 20, duration: 250, delay: 200 }}>
      <div class="stat-icon members">
        <UsersIcon />
      </div>
      <div class="stat-content">
        <div class="stat-label">{t('dashboard.total_members','Total Members')}</div>
        <div class="stat-value">{totalMembers}</div>
      </div>
    </div>
  </div>

  <!-- Gang Bank Section -->
  <div class="bank-section" in:fly={{ y: 20, duration: 250, delay: 220 }}>
    <div class="bank-card">
      <div class="bank-header">
        <div class="bank-icon">
          <BankIcon />
        </div>
        <div class="bank-info">
          <div class="bank-label">{t('dashboard.gang_bank','Gang Bank')}</div>
          <div class="bank-balance">{formatCurrency(gangBank)}</div>
          <div class="bank-subtext">{t('dashboard.available_funds','Available funds for gang activities')}</div>
        </div>
      </div>
      <div class="bank-actions">
        <button class="bank-btn deposit" on:click={() => openBankModal('deposit')}>
          <ArrowDownIcon />
          <span>{t('dashboard.deposit','Deposit')}</span>
        </button>
        <button class="bank-btn withdraw" on:click={() => openBankModal('withdraw')}>
          <ArrowUpIcon />
          <span>{t('dashboard.withdraw','Withdraw')}</span>
        </button>
      </div>
    </div>
  </div>

  <!-- Chart Cards Section -->
  <div class="charts-section">
    <!-- Turf Wins with Full Width Graph -->
    <div class="chart-card-full" in:fly={{ y: 20, duration: 250, delay: 250 }}>
      <div class="chart-header">
        <div class="chart-info">
          <div class="stat-icon turf">
            <TrophyIcon />
          </div>
          <div class="stat-content">
            <div class="stat-label">{t('dashboard.turf_wins','Turf Wins')}</div>
            <div class="stat-value">{stats.turf_wins || 0}</div>
          </div>
        </div>
        <div class="chart-meta">
          <TrendingUpIcon class="trend-icon" />
          <span>{t('dashboard.last_n_periods','Last {n} periods').replace('{n}', '5')}</span>
        </div>
      </div>
      <div class="full-chart">
        <svg width="100%" height="80" viewBox="0 0 400 80" preserveAspectRatio="none">
          <defs>
            <linearGradient id="turfGradient" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" style="stop-color:#ef4444;stop-opacity:0.3" />
              <stop offset="100%" style="stop-color:#ef4444;stop-opacity:0" />
            </linearGradient>
          </defs>
          <!-- Fill area -->
          <path
            d={`${generateChartPath([8, 10, 12, 11, stats.turf_wins || 0], 400, 80)} L 400,80 L 0,80 Z`}
            fill="url(#turfGradient)"
          />
          <!-- Line -->
          <path
            d={generateChartPath([8, 10, 12, 11, stats.turf_wins || 0], 400, 80)}
            fill="none"
            stroke="#ef4444"
            stroke-width="3"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>
    </div>

    <!-- Drugzone Wins with Full Width Graph -->
    <div class="chart-card-full" in:fly={{ y: 20, duration: 250, delay: 300 }}>
      <div class="chart-header">
        <div class="chart-info">
          <div class="stat-icon drugzone">
            <PillIcon />
          </div>
          <div class="stat-content">
            <div class="stat-label">{t('dashboard.drugzone_wins','Drugzone Wins')}</div>
            <div class="stat-value">{stats.drugzone_wins || 0}</div>
          </div>
        </div>
        <div class="chart-meta">
          <TrendingUpIcon class="trend-icon" />
          <span>{t('dashboard.last_n_periods','Last {n} periods').replace('{n}','5')}</span>
        </div>
      </div>
      <div class="full-chart">
        <svg width="100%" height="80" viewBox="0 0 400 80" preserveAspectRatio="none">
          <defs>
            <linearGradient id="drugzoneGradient" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" style="stop-color:#8b5cf6;stop-opacity:0.3" />
              <stop offset="100%" style="stop-color:#8b5cf6;stop-opacity:0" />
            </linearGradient>
          </defs>
          <!-- Fill area -->
          <path
            d={`${generateChartPath([15, 18, 20, 22, stats.drugzone_wins || 0], 400, 80)} L 400,80 L 0,80 Z`}
            fill="url(#drugzoneGradient)"
          />
          <!-- Line -->
          <path
            d={generateChartPath([15, 18, 20, 22, stats.drugzone_wins || 0], 400, 80)}
            fill="none"
            stroke="#8b5cf6"
            stroke-width="3"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>
    </div>
  </div>
</div>

<!-- Bank Transaction Modal -->
{#if showBankModal}
  <div class="modal-overlay" on:click={closeBankModal} on:keydown={(e) => e.key === 'Escape' && closeBankModal()} transition:fade={{ duration: 150 }}>
    <div class="modal-content" on:click|stopPropagation transition:scale={{ start: 0.9, duration: 200 }}>
      <div class="modal-header">
        <div class="modal-icon" class:deposit={bankAction === 'deposit'} class:withdraw={bankAction === 'withdraw'}>
          {#if bankAction === 'deposit'}
            <ArrowDownIcon />
          {:else}
            <ArrowUpIcon />
          {/if}
        </div>
        <h3>{bankAction === 'deposit' ? t('dashboard.deposit_funds','Deposit Funds') : t('dashboard.withdraw_funds','Withdraw Funds')}</h3>
      </div>
      
      <div class="modal-body">
        <div class="current-balance">
          <span class="balance-label">{t('dashboard.current_balance','Current Gang Balance')}</span>
          <span class="balance-value">{formatCurrency(gangBank)}</span>
        </div>
        
        <div class="input-group">
          <label for="bank-amount">{t('dashboard.amount','Amount')}</label>
          <div class="input-wrapper">
            <span class="currency-prefix">$</span>
            <input 
              id="bank-amount"
              type="number" 
              bind:value={bankAmount} 
              placeholder="0"
              min="1"
              disabled={bankLoading}
            />
          </div>
          {#if bankError}
            <div class="input-error">{bankError}</div>
          {/if}
        </div>

        {#if bankAction === 'deposit'}
          <div class="info-text">
            {t('dashboard.deposit_info','Money will be taken from your pocket and added to the gang bank.')}
          </div>
        {:else}
          <div class="info-text">
            {t('dashboard.withdraw_info','Money will be taken from the gang bank and added to your pocket.')}
          </div>
        {/if}
      </div>
      
      <div class="modal-footer">
        <button class="btn-cancel" on:click={closeBankModal} disabled={bankLoading}>
          {t('common.cancel','Cancel')}
        </button>
        <button 
          class="btn-confirm" 
          class:deposit={bankAction === 'deposit'} 
          class:withdraw={bankAction === 'withdraw'}
          on:click={handleBankTransaction}
          disabled={bankLoading || !bankAmount}
        >
          {#if bankLoading}
            {t('common.processing','Processing...')}
          {:else}
            {bankAction === 'deposit' ? t('dashboard.deposit','Deposit') : t('dashboard.withdraw','Withdraw')}
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .dashboard {
    display: flex;
    flex-direction: column;
    gap: 24px;
    padding: 12px;
  }

  /* Logo Section */
  .logo-section {
    display: grid;
    grid-template-columns: 200px 1fr;
    gap: 24px;
    align-items: center;
  }

  .logo-card {
    width: 200px;
    height: 200px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 16px;
    overflow: hidden;
    position: relative;
  }

  .logo-preview {
    width: 100%;
    height: 100%;
    position: relative;
  }

  .logo-preview img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .logo-overlay {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.8);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 8px;
    opacity: 0;
    transition: opacity 200ms ease;
  }

  .logo-preview:hover .logo-overlay {
    opacity: 1;
  }

  .logo-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    background: var(--accent);
    border: none;
    border-radius: 8px;
    color: white;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    transition: all 150ms ease;
    font-family: 'Inter', sans-serif;
  }

  .logo-btn:hover {
    background: var(--accent-hover);
    transform: translateY(-1px);
  }

  .logo-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .logo-btn.danger {
    background: #ef4444;
  }

  .logo-btn.danger:hover {
    background: #dc2626;
  }

  .logo-placeholder {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    background: transparent;
    border: 2px dashed var(--border-light);
    border-radius: 16px;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 200ms ease;
    font-family: 'Inter', sans-serif;
  }

  .logo-placeholder:hover {
    border-color: var(--accent);
    background: rgba(99, 102, 241, 0.05);
  }

  .logo-placeholder:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .placeholder-icon {
    width: 48px;
    height: 48px;
    color: var(--text-dim);
  }

  .placeholder-text {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .placeholder-hint {
    font-size: 12px;
    color: var(--text-dim);
  }

  .logo-info {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .logo-info h2 {
    font-size: 32px;
    font-weight: 700;
    margin: 0;
    color: var(--text-primary);
  }

  .rep-badge {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    background: linear-gradient(135deg, rgba(234, 179, 8, 0.15), rgba(202, 138, 4, 0.15));
    border: 1px solid rgba(234, 179, 8, 0.3);
    border-radius: 8px;
    width: fit-content;
  }

  .rep-icon {
    width: 20px;
    height: 20px;
    color: #eab308;
  }

  .rep-badge span {
    font-size: 14px;
    font-weight: 600;
    color: #eab308;
  }

  /* Stats Grid */
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 16px;
  }

  .stat-card {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px;
    display: flex;
    gap: 16px;
    align-items: flex-start;
    transition: all 200ms ease;
  }

  .stat-card:hover {
    border-color: var(--border-light);
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
  }

  .stat-card.wide {
    grid-column: span 2;
  }

  .stat-card.revenue-card {
    background: linear-gradient(135deg, var(--bg-elevated), rgba(234, 179, 8, 0.05));
  }

  .stat-card.chart-card {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .stat-main {
    display: flex;
    gap: 16px;
    align-items: flex-start;
  }

  .mini-chart {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding-top: 8px;
    border-top: 1px solid var(--border);
  }

  .mini-chart svg {
    width: 100%;
    height: auto;
  }

  .chart-label {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    color: var(--text-dim);
  }

  .trend-icon {
    width: 14px;
    height: 14px;
    color: #22c55e;
  }

  /* Charts Section */
  .charts-section {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 16px;
  }

  .chart-card-full {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    transition: all 200ms ease;
  }

  .chart-card-full:hover {
    border-color: var(--border-light);
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
  }

  .chart-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
  }

  .chart-info {
    display: flex;
    gap: 16px;
    align-items: flex-start;
  }

  .chart-meta {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: var(--text-dim);
  }

  .full-chart {
    width: 100%;
    margin-top: 8px;
  }

  .full-chart svg {
    display: block;
    width: 100%;
  }

  @media (max-width: 1024px) {
    .stat-card.wide {
      grid-column: span 1;
    }

    .charts-section {
      grid-template-columns: 1fr;
    }
  }

  .stat-icon {
    width: 48px;
    height: 48px;
    border-radius: 12px;
    display: grid;
    place-items: center;
    flex-shrink: 0;
  }

  .stat-icon.turf {
    background: linear-gradient(135deg, rgba(239, 68, 68, 0.15), rgba(220, 38, 38, 0.15));
    color: #ef4444;
  }

  .stat-icon.drugzone {
    background: linear-gradient(135deg, rgba(139, 92, 246, 0.15), rgba(124, 58, 237, 0.15));
    color: #8b5cf6;
  }

  .stat-icon.online {
    background: linear-gradient(135deg, rgba(34, 197, 94, 0.15), rgba(22, 163, 74, 0.15));
    color: #22c55e;
  }

  .stat-icon.members {
    background: linear-gradient(135deg, rgba(59, 130, 246, 0.15), rgba(37, 99, 235, 0.15));
    color: #3b82f6;
  }

  .stat-icon.revenue {
    background: linear-gradient(135deg, rgba(234, 179, 8, 0.15), rgba(202, 138, 4, 0.15));
    color: #eab308;
  }

  .stat-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .stat-label {
    font-size: 13px;
    font-weight: 500;
    color: var(--text-secondary);
  }

  .stat-value {
    font-size: 28px;
    font-weight: 700;
    color: var(--text-primary);
    line-height: 1;
  }

  .stat-subtext {
    font-size: 12px;
    color: var(--text-dim);
    margin-top: 2px;
  }

  @media (max-width: 768px) {
    .logo-section {
      grid-template-columns: 1fr;
      gap: 16px;
    }

    .logo-card {
      width: 100%;
      max-width: 200px;
      margin: 0 auto;
    }

    .stats-grid {
      grid-template-columns: 1fr;
    }

    .stat-card.wide {
      grid-column: span 1;
    }
  }

  /* Bank Section Styles */
  .bank-section {
    margin-top: 8px;
  }

  .bank-card {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 24px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 24px;
  }

  .bank-header {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .bank-icon {
    width: 56px;
    height: 56px;
    border-radius: 14px;
    background: linear-gradient(135deg, #10b981, #059669);
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    font-size: 28px;
  }

  .bank-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .bank-label {
    font-size: 14px;
    color: var(--text-secondary);
    font-weight: 500;
  }

  .bank-balance {
    font-size: 28px;
    font-weight: 700;
    color: var(--text-primary);
    letter-spacing: -0.5px;
  }

  .bank-subtext {
    font-size: 12px;
    color: var(--text-secondary);
  }

  .bank-actions {
    display: flex;
    gap: 12px;
  }

  .bank-btn {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 20px;
    border-radius: 10px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    border: none;
  }

  .bank-btn.deposit {
    background: linear-gradient(135deg, #10b981, #059669);
    color: white;
  }

  .bank-btn.deposit:hover {
    background: linear-gradient(135deg, #059669, #047857);
    transform: translateY(-2px);
  }

  .bank-btn.withdraw {
    background: var(--bg-panel);
    border: 1px solid var(--border);
    color: var(--text-primary);
  }

  .bank-btn.withdraw:hover {
    background: var(--bg-sidebar);
    border-color: var(--accent);
  }

  /* Modal Styles */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.7);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    backdrop-filter: blur(4px);
  }

  .modal-content {
    background: var(--bg-panel);
    border: 1px solid var(--border);
    border-radius: 16px;
    width: 100%;
    max-width: 420px;
    overflow: hidden;
  }

  .modal-header {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 24px;
    border-bottom: 1px solid var(--border);
  }

  .modal-icon {
    width: 48px;
    height: 48px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
  }

  .modal-icon.deposit {
    background: linear-gradient(135deg, #10b981, #059669);
    color: white;
  }

  .modal-icon.withdraw {
    background: linear-gradient(135deg, #f59e0b, #d97706);
    color: white;
  }

  .modal-header h3 {
    font-size: 18px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .modal-body {
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .current-balance {
    background: var(--bg-elevated);
    border-radius: 10px;
    padding: 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .balance-label {
    font-size: 14px;
    color: var(--text-secondary);
  }

  .balance-value {
    font-size: 18px;
    font-weight: 700;
    color: #10b981;
  }

  .input-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .input-group label {
    font-size: 14px;
    font-weight: 500;
    color: var(--text-secondary);
  }

  .input-wrapper {
    display: flex;
    align-items: center;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 10px;
    overflow: hidden;
  }

  .input-wrapper:focus-within {
    border-color: var(--accent);
  }

  .currency-prefix {
    padding: 12px 16px;
    background: var(--bg-dark);
    color: var(--text-secondary);
    font-weight: 600;
    border-right: 1px solid var(--border);
  }

  .input-wrapper input {
    flex: 1;
    padding: 12px 16px;
    background: transparent;
    border: none;
    color: var(--text-primary);
    font-size: 16px;
    font-weight: 500;
    outline: none;
  }

  .input-wrapper input::placeholder {
    color: var(--text-secondary);
  }

  .input-error {
    color: var(--danger);
    font-size: 13px;
    margin-top: 4px;
  }

  .info-text {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.5;
    padding: 12px;
    background: var(--bg-elevated);
    border-radius: 8px;
  }

  .modal-footer {
    display: flex;
    gap: 12px;
    padding: 20px 24px;
    border-top: 1px solid var(--border);
    background: var(--bg-dark);
  }

  .btn-cancel, .btn-confirm {
    flex: 1;
    padding: 12px 20px;
    border-radius: 10px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    border: none;
  }

  .btn-cancel {
    background: var(--bg-elevated);
    color: var(--text-secondary);
  }

  .btn-cancel:hover:not(:disabled) {
    background: var(--bg-panel);
  }

  .btn-confirm.deposit {
    background: linear-gradient(135deg, #10b981, #059669);
    color: white;
  }

  .btn-confirm.deposit:hover:not(:disabled) {
    background: linear-gradient(135deg, #059669, #047857);
  }

  .btn-confirm.withdraw {
    background: linear-gradient(135deg, #f59e0b, #d97706);
    color: white;
  }

  .btn-confirm.withdraw:hover:not(:disabled) {
    background: linear-gradient(135deg, #d97706, #b45309);
  }

  .btn-confirm:disabled, .btn-cancel:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  @media (max-width: 600px) {
    .bank-card {
      flex-direction: column;
      text-align: center;
    }

    .bank-header {
      flex-direction: column;
    }

    .bank-actions {
      width: 100%;
    }

    .bank-btn {
      flex: 1;
      justify-content: center;
    }
  }
</style>