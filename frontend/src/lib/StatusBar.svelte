<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { checkBackendHealth } from "./health";

  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || "";
  const apiKey = import.meta.env.VITE_SUPABASE_ANON_KEY || "";

  let isHealthy: boolean | null = null;
  let timer: ReturnType<typeof setInterval> | null = null;

  async function pingHealth() {
    isHealthy = await checkBackendHealth(supabaseUrl, apiKey);
  }

  onMount(() => {
    pingHealth();
    timer = setInterval(pingHealth, 5000);
  });

  onDestroy(() => {
    if (timer) {
      clearInterval(timer);
    }
  });
</script>

<header class="status-bar">
  <div class="status-inner">

    <span class="brand-title">Junta Cycle</span>
    <div class="indicator-group" title={isHealthy === null ? "Checking backend..." : isHealthy ? "Backend connected" : "Backend unreachable"}>
      <span
        class="status-dot"
        class:healthy={isHealthy === true}
        class:unhealthy={isHealthy === false}
        class:checking={isHealthy === null}
      ></span>
      <span class="status-label">
        {#if isHealthy === true}
          Online
        {:else if isHealthy === false}
          Offline
        {:else}
          Connecting...
        {/if}
      </span>
    </div>
  </div>
</header>

<style>
  .status-bar {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    height: 44px;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(8px);
    border-bottom: 1px solid var(--border-color);
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .status-inner {
    width: 100%;
    max-width: 480px;
    padding: 0 1.25rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .brand-title {
    font-size: 0.875rem;
    font-weight: 700;
    letter-spacing: 0.02em;
    color: var(--text-main);
  }

  .indicator-group {
    display: flex;
    align-items: center;
    gap: 0.375rem;
  }

  .status-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    display: inline-block;
    transition: background-color 0.3s ease;
  }

  .status-dot.checking {
    background-color: #94a3b8;
  }

  .status-dot.healthy {
    background-color: #22c55e;
    box-shadow: 0 0 6px rgba(34, 197, 94, 0.6);
  }

  .status-dot.unhealthy {
    background-color: #ef4444;
    box-shadow: 0 0 6px rgba(239, 68, 68, 0.6);
  }

  .status-label {
    font-size: 0.75rem;
    font-weight: 500;
    color: var(--text-muted);
  }
</style>
