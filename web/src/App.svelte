
<script lang="ts">
  import Dashboard from './components/Dashboard.svelte';
  import ActivityOverlay from './components/ActivityOverlay.svelte';
  import ServerManagement from './components/ServerManagement.svelte';
  import Leaderboard from './components/Leaderboard.svelte';
  import Notifications from './components/Notifications.svelte';
  import { useNuiEvent } from './utils/useNuiEvent';
  import { locales } from './stores/localeStore';

  import { onMount } from 'svelte';
  import { fetchNui } from './utils/fetchNui';

  onMount(() => {
    fetchNui('fetchLocales').then((fetchedLocales) => {
      locales.set(fetchedLocales);
    });
  });

  import { debugData } from './utils/debugData';

  import './styles/fonts.css'; // ✅ Import here!
  import {isEnvBrowser} from "./utils/misc";

  // Activity Overlay State (no mock data)
  let showActivity = false;
  let activityTitle = "";
  let activityDescription = "";
  let activityStats: { label: string; value: string | number }[] = [];
  let activityLeaderboard: { position: number; name: string; value: string | number; color?: string }[] = [];
  
  // Timer state (disabled by default)
  let showTimer = false;
  let timerDuration = 0;
  let timerLabel = "TIME REMAINING";

  // Listen for NUI events to show/hide and update activity overlay
  useNuiEvent('showActivityOverlay', (data: any) => {
    activityTitle = data.title || "ACTIVITY";
    activityDescription = data.description || "";
    activityStats = data.stats || [];
    activityLeaderboard = data.leaderboard || [];
    showTimer = data.showTimer || false;
    timerDuration = data.timerDuration || 0;
    timerLabel = data.timerLabel || "TIME REMAINING";
    showActivity = true;
  });

  useNuiEvent('hideActivityOverlay', () => {
    showActivity = false;
  });

  useNuiEvent('updateActivityStats', (data: any) => {
    if (data.stats) activityStats = data.stats;
  });

  useNuiEvent('updateActivityLeaderboard', (data: any) => {
    if (data.leaderboard) activityLeaderboard = data.leaderboard;
  });

  // No debug/mock data active by default
</script>

<main>
  <Dashboard />
  <ServerManagement />
  <Leaderboard />
  <ActivityOverlay 
    bind:visible={showActivity}
    title={activityTitle}
    description={activityDescription}
    myStats={activityStats}
    leaderboard={activityLeaderboard}
    {showTimer}
    {timerDuration}
    {timerLabel}
  />
  <Notifications />
</main>

<style>
  .hudWrapper {
    width: 100%;
    position: absolute;
    bottom: 0;
    height: 100%;
    z-index: -1;
  }
</style>