<script lang="ts">
  import { fade, fly } from 'svelte/transition';
  import { onMount, onDestroy } from 'svelte';
  import { t } from '../utils/translate';
  
  // Icons
  import SkullIcon from "virtual:icons/mdi/skull";

  export let visible = false;
  export let title = "";
  export let description = "";
  
  export let myStats: { label: string; value: string | number }[] = [];
  export let leaderboard: { position: number; name: string; value: string | number; color?: string }[] = [];

  // Timer props
  export let showTimer = false;
  export let timerDuration = 0; // in seconds
  export let timerLabel = t('activity_timer_label','TIME REMAINING');

  let timeRemaining = timerDuration;
  let progressPercent = 100;
  let timerInterval: number | null = null;

  $: if (visible && showTimer && timerDuration > 0) {
    startTimer();
  }

  function startTimer() {
    if (timerInterval) clearInterval(timerInterval);
    
    timeRemaining = timerDuration;
    progressPercent = 100;

    timerInterval = window.setInterval(() => {
      if (timeRemaining > 0) {
        timeRemaining -= 0.1;
        progressPercent = (timeRemaining / timerDuration) * 100;
      } else {
        timeRemaining = 0;
        progressPercent = 0;
        if (timerInterval) clearInterval(timerInterval);
      }
    }, 100);
  }

  function formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  onDestroy(() => {
    if (timerInterval) clearInterval(timerInterval);
  });
</script>

{#if visible}
  <div class="overlay-container" transition:fade={{ duration: 300 }}>
    <div class="activity-card" transition:fly={{ y: -20, duration: 400, delay: 100 }}>
      <!-- Header -->
      <div class="card-header">
        <h1 class="title">{title}</h1>
        <p class="description">{description}</p>
      </div>

      <!-- Timer Progress Bar -->
      {#if showTimer}
        <div class="timer-section" transition:fly={{ y: -10, duration: 300, delay: 150 }}>
          <div class="timer-header">
            <span class="timer-label">{timerLabel}</span>
            <span class="timer-value">{formatTime(timeRemaining)}</span>
          </div>
          <div class="progress-bar">
            <div 
              class="progress-fill" 
              style="width: {progressPercent}%"
            ></div>
          </div>
        </div>
      {/if}

      <!-- My Statistics -->
      {#if myStats.length > 0}
        <div class="section">
          <h2 class="section-title">{t('activity.my_statistics','MY STATISTICS')}</h2>
          <div class="stats-grid">
            {#each myStats as stat, i}
              <div class="stat-card" transition:fly={{ x: -20, duration: 300, delay: 200 + (i * 50) }}>
                <div class="stat-icon">
                  <SkullIcon />
                </div>
                <div class="stat-content">
                  <div class="stat-label">{stat.label}</div>
                  <div class="stat-value">{stat.value}</div>
                </div>
              </div>
            {/each}
          </div>
        </div>
      {/if}

      <!-- Leaderboard -->
      {#if leaderboard.length > 0}
        <div class="section">
          <h2 class="section-title">{t('activity.leaderboard','LEADERBOARD')}</h2>
          <div class="leaderboard-list">
            {#each leaderboard as entry, i}
              <div 
                class="leaderboard-entry" 
                style="--entry-color: {entry.color || '#6b7280'}"
                transition:fly={{ x: -20, duration: 300, delay: 300 + (i * 50) }}
              >
                <div class="position-badge" class:gold={entry.position === 1}>{entry.position}</div>
                <div class="entry-name">{entry.name}</div>
                <div class="entry-value">{entry.value}</div>
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .overlay-container {
    position: fixed;
    top: 50%;
    left: 20px;
    transform: translateY(-50%);
    z-index: 9999;
    pointer-events: none;
  }

  .activity-card {
    width: 280px;
    background: transparent;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 16px;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', sans-serif;
  }

  /* Header */
  .card-header {
    text-align: left;
  }

  .title {
    margin: 0;
    font-size: 22px;
    font-weight: 700;
    color: var(--accent);
    letter-spacing: 0.3px;
    text-transform: uppercase;
    line-height: 1.2;
  }

  .description {
    margin: 6px 0 0 0;
    font-size: 11px;
    font-weight: 500;
    color: var(--text-secondary);
    letter-spacing: 0.3px;
    text-transform: uppercase;
  }

  /* Section */
  .section {
    margin-top: 0;
  }

  .section-title {
    margin: 0 0 8px 0;
    font-size: 11px;
    font-weight: 700;
    color: var(--text-dim);
    letter-spacing: 1px;
    text-transform: uppercase;
  }

  /* Stats Grid */
  .stats-grid {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .stat-card {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 8px;
    transition: all 200ms ease;
  }

  .stat-card:hover {
    border-color: var(--border-light);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  }

  .stat-icon {
    width: 32px;
    height: 32px;
    display: grid;
    place-items: center;
    background: linear-gradient(135deg, rgba(99, 102, 241, 0.15), rgba(79, 70, 229, 0.15));
    border-radius: 8px;
    color: var(--accent);
  }

  .stat-content {
    flex: 1;
  }

  .stat-label {
    font-size: 10px;
    font-weight: 500;
    color: var(--text-secondary);
    margin-bottom: 2px;
  }

  .stat-value {
    font-size: 16px;
    font-weight: 600;
    color: var(--text-primary);
  }

  /* Leaderboard */
  .leaderboard-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .leaderboard-entry {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 8px;
    transition: all 200ms ease;
  }

  .leaderboard-entry:hover {
    border-color: var(--border-light);
    transform: translateX(4px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  }

  .position-badge {
    width: 28px;
    height: 28px;
    display: grid;
    place-items: center;
    background: var(--entry-color);
    border-radius: 6px;
    font-size: 13px;
    font-weight: 700;
    color: #ffffff;
    flex-shrink: 0;
  }

  .position-badge.gold {
    background: linear-gradient(135deg, #fbbf24, #f59e0b, #d97706);
    box-shadow: 0 2px 8px rgba(251, 191, 36, 0.4);
  }

  .entry-name {
    flex: 1;
    font-size: 13px;
    font-weight: 500;
    color: var(--text-primary);
  }

  .entry-value {
    font-size: 11px;
    font-weight: 500;
    color: var(--text-secondary);
    padding: 4px 10px;
    background: rgba(99, 102, 241, 0.1);
    border: 1px solid rgba(99, 102, 241, 0.2);
    border-radius: 6px;
  }

  /* Timer Section */
  .timer-section {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .timer-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .timer-label {
    font-size: 10px;
    font-weight: 700;
    color: var(--text-dim);
    letter-spacing: 1px;
    text-transform: uppercase;
  }

  .timer-value {
    font-size: 16px;
    font-weight: 700;
    color: var(--accent);
    font-variant-numeric: tabular-nums;
  }

  .progress-bar {
    width: 100%;
    height: 8px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: 4px;
    overflow: hidden;
    position: relative;
  }

  .progress-fill {
    height: 100%;
    background: linear-gradient(90deg, var(--accent), #818cf8);
    border-radius: 4px;
    transition: width 0.1s linear;
    box-shadow: 0 0 10px rgba(99, 102, 241, 0.5);
  }

  .progress-fill::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    animation: shimmer 2s infinite;
  }

  @keyframes shimmer {
    0% {
      transform: translateX(-100%);
    }
    100% {
      transform: translateX(100%);
    }
  }

  @media (max-width: 768px) {
    .overlay-container {
      left: 10px;
    }

    .activity-card {
      width: 260px;
    }
  }
</style>
