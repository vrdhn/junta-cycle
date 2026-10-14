<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { checkBackendHealth } from "./health";
  import { supabase } from "./supabase";

  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || "";
  const apiKey = import.meta.env.VITE_SUPABASE_ANON_KEY || "";

  let isHealthy = $state<boolean | null>(null);
  let userName = $state<string | null>(null);
  let timer: ReturnType<typeof setInterval> | null = null;
  let authSubscription: { unsubscribe: () => void } | null = null;

  async function pingHealth() {
    isHealthy = await checkBackendHealth(supabaseUrl, apiKey);
  }

  async function updateUserInfo(sessionUser: any) {
    if (!sessionUser) {
      userName = null;
      return;
    }
    if (sessionUser.user_metadata?.full_name) {
      userName = sessionUser.user_metadata.full_name;
      return;
    }
    try {
      const { data } = await supabase
        .from("profiles")
        .select("full_name")
        .eq("id", sessionUser.id)
        .single();
      if (data?.full_name) {
        userName = data.full_name;
        return;
      }
    } catch {
      // fallback
    }
    userName = sessionUser.email || null;
  }

  type ThemeMode = "system" | "light" | "dark";
  let themeMode = $state<ThemeMode>("system");

  function applyTheme(mode: ThemeMode) {
    themeMode = mode;
    localStorage.setItem("jc-theme", mode);
    if (mode === "dark") {
      document.documentElement.setAttribute("data-theme", "dark");
    } else if (mode === "light") {
      document.documentElement.setAttribute("data-theme", "light");
    } else {
      document.documentElement.removeAttribute("data-theme");
    }
  }

  function cycleTheme() {
    if (themeMode === "system") {
      applyTheme("light");
    } else if (themeMode === "light") {
      applyTheme("dark");
    } else {
      applyTheme("system");
    }
  }

  onMount(() => {
    const saved = localStorage.getItem("jc-theme") as ThemeMode | null;
    if (saved === "light" || saved === "dark" || saved === "system") {
      applyTheme(saved);
    } else {
      applyTheme("system");
    }

    pingHealth();
    timer = setInterval(pingHealth, 5000);

    supabase.auth.getSession().then(({ data }) => {
      updateUserInfo(data?.session?.user ?? null);
    });

    const { data: authListener } = supabase.auth.onAuthStateChange((_event, session) => {
      updateUserInfo(session?.user ?? null);
    });
    authSubscription = authListener.subscription;
  });

  onDestroy(() => {
    if (timer) {
      clearInterval(timer);
    }
    if (authSubscription) {
      authSubscription.unsubscribe();
    }
  });
</script>

<header class="status-bar">
  <div class="status-inner">
    <span class="brand-title">Junta Cycle</span>
    <div class="status-right">
      {#if userName}
        <div class="user-pill" title={`Signed in as ${userName}`}>
          <span class="user-icon">👤</span>
          <span class="user-name">{userName}</span>
        </div>
      {/if}

      <!-- Theme Switcher Button -->
      <button
        class="theme-toggle-btn"
        onclick={cycleTheme}
        title={`Theme mode: ${themeMode.toUpperCase()} (Click to switch between Auto, Light, and Dark)`}
        aria-label="Toggle color theme"
      >
        {#if themeMode === "system"}
          <span class="theme-icon">💻</span>
          <span class="theme-text">Auto</span>
        {:else if themeMode === "light"}
          <span class="theme-icon">☀️</span>
          <span class="theme-text">Light</span>
        {:else}
          <span class="theme-icon">🌙</span>
          <span class="theme-text">Dark</span>
        {/if}
      </button>

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
  </div>
</header>

<style>
  .status-bar {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    height: 44px;
    background: var(--status-bar-bg);
    backdrop-filter: blur(8px);
    border-bottom: 1px solid var(--border-color);
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background-color 0.2s ease, border-color 0.2s ease;
  }

  .status-inner {
    width: 100%;
    max-width: 1280px;
    margin: 0 auto;
    padding: 0 clamp(0.75rem, 3vw, 2rem);
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

  .status-right {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .user-pill {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    background: var(--card-bg-subtle);
    color: var(--text-main);
    padding: 0.2rem 0.6rem;
    border-radius: 9999px;
    font-size: 0.8rem;
    font-weight: 600;
    border: 1px solid var(--border-color);
    max-width: 180px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .theme-toggle-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    background: var(--card-bg-subtle);
    border: 1px solid var(--border-color);
    color: var(--text-main);
    padding: 0.2rem 0.55rem;
    border-radius: 9999px;
    font-size: 0.775rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .theme-toggle-btn:hover {
    background: var(--input-bg);
    border-color: var(--primary-color);
  }

  .theme-icon {
    font-size: 0.85rem;
    line-height: 1;
  }

  .theme-text {
    font-size: 0.75rem;
  }

  .user-icon {
    font-size: 0.75rem;
    opacity: 0.8;
  }

  .user-name {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .indicator-group {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .status-dot {
    width: 10px;
    height: 10px;
    min-width: 10px;
    min-height: 10px;
    border-radius: 50%;
    display: inline-block;
    flex-shrink: 0;
    background-color: #94a3b8;
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

  @media (max-width: 640px) {
    .user-pill {
      max-width: 120px;
      font-size: 0.75rem;
      padding: 0.15rem 0.5rem;
    }
  }
</style>

