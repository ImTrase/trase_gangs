<script lang="ts">
  import { fade, scale } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';
  import { useNuiEvent } from '../utils/useNuiEvent';
  import { fetchNui } from '../utils/fetchNui';

  import '../theme.css';

  // Icons
  import TrophyIcon from 'virtual:icons/mdi/trophy';
  import CloseIcon from 'virtual:icons/mdi/close';
  import SwordsIcon from 'virtual:icons/mdi/sword-cross';
  import MapIcon from 'virtual:icons/mdi/map-marker-radius';
  import PillIcon from 'virtual:icons/mdi/pill';
  import StarIcon from 'virtual:icons/mdi/star';

  export let open = false;

  type TabKey = 'drugzones' | 'turfs' | 'gangwars' | 'reputation';

  const tabs: Array<{ key: TabKey; label: string; icon: any; color?: string }> = [
    { key: 'drugzones', label: 'Most Drugzone Wins', icon: PillIcon },
    { key: 'turfs', label: 'Most Turf Wins', icon: MapIcon },
    { key: 'gangwars', label: 'Most Gang War Wins', icon: SwordsIcon },
    { key: 'reputation', label: 'Highest REP', icon: StarIcon }
  ];

  let tab: TabKey = 'drugzones';

  let data = {
    drugzones: [] as any[],
    turfs: [] as any[],
    gangwars: [] as any[],
    reputation: [] as any[]
  };

  useNuiEvent('leaderboard:open', async (payload: any) => {
    open = true;
    tab = (payload?.tab as TabKey) || 'drugzones';
    await loadData();
  });

  useNuiEvent('leaderboard:close', () => {
    open = false;
    fetchNui('leaderboard:closeUI');
  });

  async function loadData() {
    const res = await fetchNui('leaderboard:getAll', { limit: 25 });
    data = {
      drugzones: res?.drugzones || [],
      turfs: res?.turfs || [],
      gangwars: res?.gangwars || [],
      reputation: res?.reputation || []
    };
  }

  function closeUI() {
    open = false;
    fetchNui('leaderboard:closeUI');
  }

  function selectTab(k: TabKey) {
    tab = k;
  }
</script>

<svelte:window on:keydown={(e) => { if (open && e.key === 'Escape') closeUI(); }} />

{#if open}
  <div>
    <div
      class="backdrop"
      role="button"
      tabindex="0"
      aria-label="Close overlay"
      in:fade={{ duration: 160 }}
      out:fade={{ duration: 160 }}
      on:click={(e) => e.currentTarget === e.target && closeUI()}
      on:keydown={(e) => e.key === 'Enter' && closeUI()}
    />

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
              <TrophyIcon class="brand-icon" />
            </div>
            <div class="brand-text">
              <strong>Gang Leaderboards</strong>
              <span>Top gangs by category</span>
            </div>
          </div>

          <div class="nav-section">
            <div class="nav-label">Categories</div>
            <nav class="nav" aria-label="Leaderboard Categories">
              {#each tabs as t}
                <button
                  class="nav-item {tab === t.key ? 'active' : ''}"
                  on:click={() => selectTab(t.key)}
                  aria-pressed={tab === t.key}
                >
                  <svelte:component this={t.icon} class="nav-icon" />
                  <span>{t.label}</span>
                </button>
              {/each}
            </nav>
          </div>
        </aside>

        <!-- Main Content -->
        <div class="main">
          <header class="topbar">
            <h1 class="page-title">
              {tabs.find(x => x.key === tab)?.label}
            </h1>
            <button class="close-btn" on:click={closeUI} aria-label="Close">
              <CloseIcon class="close-icon" />
              <span>Close</span>
            </button>
          </header>

          <main class="content" role="region" aria-live="polite">
            <div class="table">
              <div class="table-head">
                <div class="th th-rank">#</div>
                <div class="th th-gang">Gang</div>
                <div class="th th-wins">Wins</div>
                <div class="th th-rep">REP</div>
                <div class="th th-members">Members</div>
              </div>

              {#key tab}
                <div class="table-rows" in:fade={{ duration: 200, easing: cubicOut }} out:fade={{ duration: 150 }}>
                  {#each (data[tab] || []) as row, i}
                    <div class="table-row">
                      <div class="td td-rank">{i + 1}</div>
                      <div class="td td-gang">{row.name}</div>
                      <div class="td td-wins">{tab === 'reputation' ? '-' : row.wins}</div>
                      <div class="td td-rep">{row.reputation}</div>
                      <div class="td td-members">{row.members}</div>
                    </div>
                  {/each}

                  {#if (data[tab] || []).length === 0}
                    <div class="empty">No data available.</div>
                  {/if}
                </div>
              {/key}
            </div>
          </main>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

  :root {
    --bg-dark: #0f0f17;
    --bg-panel: #18181f;
    --bg-sidebar: #1a1a22;
    --bg-elevated: #20202a;
    /* Blue-forward accent to match existing UI */
    --accent: #3b82f6;          /* blue-500 */
    --accent-hover: #2563eb;    /* blue-600 */
    --accent-light: #60a5fa;    /* blue-400 */
    --text-primary: #ffffff;
    --text-secondary: #a0a0ab;
    --text-dim: #71717a;
    --border: #27272f;
    --border-light: #3a3a44;
  }

  * { font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }

  .backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.7); z-index: 999; }
  .wrap { position: fixed; inset: 0; display: grid; place-items: center; padding: 3vh 3vw; z-index: 1000; }
  .panel { width: 1200px; max-width: 95vw; height: 760px; max-height: 94vh; display: grid; grid-template-columns: 240px 1fr; background: var(--bg-panel); border-radius: 20px; overflow: hidden; box-shadow: 0 20px 60px rgba(0,0,0,0.5); color: var(--text-primary); }

  .sidebar { background: var(--bg-sidebar); display: flex; flex-direction: column; padding: 24px 16px; gap: 24px; border-right: 1px solid var(--border); }
  .brand { display: flex; align-items: flex-start; gap: 12px; padding: 8px; }
  .brand-icon-wrapper { width: 48px; height: 48px; background: linear-gradient(135deg, var(--accent), var(--accent-hover)); border-radius: 12px; display: grid; place-items: center; flex-shrink: 0; }
  .brand-icon { width: 28px; height: 28px; color: white; }
  .brand-text { display: flex; flex-direction: column; gap: 4px; flex: 1; }
  .brand-text strong { font-size: 15px; font-weight: 600; color: var(--text-primary); line-height: 1.2; }
  .brand-text span { font-size: 11px; color: var(--text-dim); }

  .nav-section { flex: 1; display: flex; flex-direction: column; gap: 8px; }
  .nav-label { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-dim); padding: 0 12px 4px; }
  .nav { display: flex; flex-direction: column; gap: 2px; }
  .nav-item { display: flex; align-items: center; gap: 12px; padding: 12px; background: transparent; border: none; border-radius: 10px; color: var(--text-secondary); cursor: pointer; transition: all 150ms ease; font-size: 14px; font-weight: 500; text-align: left; }
  .nav-item:hover { background: rgba(255,255,255,0.05); color: var(--text-primary); }
  .nav-item.active { background: linear-gradient(135deg, var(--accent), var(--accent-hover)); color: white; }
  .nav-icon { width: 20px; height: 20px; flex-shrink: 0; }

  .main { display: grid; grid-template-rows: auto 1fr; background: var(--bg-dark); }
  .topbar { display: flex; align-items: center; justify-content: space-between; padding: 20px 32px; background: var(--bg-panel); border-bottom: 1px solid var(--border); }
  .page-title { font-size: 22px; font-weight: 700; margin: 0; color: var(--text-primary); }
  .close-btn { display: flex; align-items: center; gap: 8px; padding: 8px 20px; background: var(--bg-elevated); border: 1px solid var(--border-light); border-radius: 8px; color: var(--text-primary); font-size: 13px; font-weight: 500; cursor: pointer; transition: all 150ms ease; }
  .close-icon { width: 16px; height: 16px; }
  .close-btn:hover { background: var(--bg-sidebar); }

  .content { padding: 24px; overflow-y: auto; }
  .table { background: var(--bg-elevated); border: 1px solid var(--border); border-radius: 12px; }
  .table-head { display: grid; grid-template-columns: 80px 1fr 120px 120px 120px; gap: 8px; padding: 12px 16px; background: var(--bg-sidebar); border-bottom: 1px solid var(--border); font-size: 12px; text-transform: uppercase; color: var(--text-dim); letter-spacing: 0.5px; }
  .table-row { display: grid; grid-template-columns: 80px 1fr 120px 120px 120px; gap: 8px; padding: 14px 16px; border-bottom: 1px solid var(--border); font-size: 14px; color: var(--text-primary); }
  .table-row:last-child { border-bottom: none; }
  .th, .td { display: flex; align-items: center; }
  .th-rank, .td-rank { font-weight: 700; color: var(--accent-light); }
  .td-gang { font-weight: 600; }
  .empty { padding: 16px; text-align: center; color: var(--text-secondary); }

  @media (max-width: 900px) {
    .panel { grid-template-columns: 1fr; }
    .sidebar { display: none; }
  }
</style>
