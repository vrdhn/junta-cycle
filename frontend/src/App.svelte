<script lang="ts">
  import { onMount } from "svelte";
  import StatusBar from "./lib/StatusBar.svelte";
  import DebugPage from "./lib/DebugPage.svelte";
  import AppScreen from "./lib/AppScreen.svelte";
  import { supabase } from "./lib/supabase";

  let currentRoute = $state<"home" | "debug" | "app">("home");
  let activeUser = $state<any>(null);
  let sessionLoaded = $state(false);

  function checkRoute() {
    const rawPath = window.location.pathname.replace(/\/+$/, "");
    const hash = window.location.hash;
    const search = window.location.search;

    let target: "home" | "debug" | "app" = "home";

    // Hash overrides path if explicitly set
    if (hash === "#app" || hash === "#/app" || search.includes("app")) {
      target = "app";
    } else if (
      hash === "#debug" ||
      hash === "#/debug" ||
      hash === "#users" ||
      hash === "#/users" ||
      search.includes("debug") ||
      search.includes("users")
    ) {
      target = "debug";
    } else if (rawPath.endsWith("/app")) {
      target = "app";
    } else if (rawPath.endsWith("/debug") || rawPath.endsWith("/users")) {
      target = "debug";
    } else {
      target = "home";
    }

    // Redirect anonymous users from /app to /
    if (target === "app" && sessionLoaded && !activeUser) {
      navigateTo("home");
      return;
    }

    currentRoute = target;
  }

  function navigateTo(route: "home" | "debug" | "app") {
    const rawPath = window.location.pathname.replace(/\/+$/, "");
    const basePath = rawPath.replace(/\/(?:debug|users|app)$/, "");
    window.location.hash = "";

    let newUrl = `${basePath}/`;
    if (route === "app") {
      newUrl = `${basePath}/app`;
    } else if (route === "debug") {
      newUrl = `${basePath}/debug`;
    }

    window.history.pushState({}, "", newUrl);
    checkRoute();
  }

  async function checkSession() {
    const { data } = await supabase.auth.getSession();
    activeUser = data?.session?.user ?? null;
    sessionLoaded = true;
    checkRoute();
  }

  async function handleLogout() {
    await supabase.auth.signOut();
    activeUser = null;
    navigateTo("home");
  }

  onMount(() => {
    checkSession();

    window.addEventListener("popstate", checkRoute);
    window.addEventListener("hashchange", checkRoute);

    const { data: authListener } = supabase.auth.onAuthStateChange((_event, session) => {
      activeUser = session?.user ?? null;
      sessionLoaded = true;
      checkRoute();
    });

    return () => {
      window.removeEventListener("popstate", checkRoute);
      window.removeEventListener("hashchange", checkRoute);
      authListener.subscription.unsubscribe();
    };
  });
</script>

<StatusBar />

{#if currentRoute === "debug"}
  <DebugPage onNavigate={navigateTo} />
{:else if currentRoute === "app" && activeUser}
  <AppScreen user={activeUser} onNavigate={navigateTo} onLogout={handleLogout} />
{:else}
  <main class="welcome-container">
    <div class="hero-card">
      <div class="logo-icon">🚲</div>
      <h1>Welcome to Junta Cycles</h1>
      <p class="tagline">Smart community bicycle sharing for your daily commute.</p>

      {#if activeUser}
        <div class="user-status-box">
          <span class="user-greeting">Logged in as</span>
          <strong class="user-email">{activeUser.user_metadata?.full_name || activeUser.email}</strong>
          {#if activeUser.user_metadata?.full_name}
            <span class="user-subemail">{activeUser.email}</span>
          {/if}
          <button class="btn-logout" onclick={handleLogout}>Log Out</button>
        </div>
      {/if}

      <div class="action-section">
        {#if !activeUser}
          <button class="btn-primary" onclick={() => navigateTo("debug")}>
            Login / Select User
          </button>
        {:else}
          <button class="btn-primary" onclick={() => navigateTo("app")}>
            Open App (/app) ➔
          </button>
          <button class="btn-secondary" onclick={() => navigateTo("debug")}>
            Switch User (/debug)
          </button>
        {/if}
      </div>
    </div>
  </main>
{/if}

<style>
  .welcome-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
    padding: 1.5rem;
  }

  .hero-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 1rem;
    padding: 2.5rem 1.5rem;
    width: 100%;
    max-width: 480px;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
  }

  .logo-icon {
    font-size: 3.5rem;
    margin-bottom: 1rem;
  }

  h1 {
    font-size: 1.75rem;
    font-weight: 700;
    margin-bottom: 0.75rem;
    color: var(--text-main);
  }

  .tagline {
    font-size: 1rem;
    color: var(--text-muted);
    margin-bottom: 2rem;
    line-height: 1.5;
  }

  .user-status-box {
    background: #f0fdf4;
    border: 1px solid #bbf7d0;
    border-radius: 0.5rem;
    padding: 0.75rem 1rem;
    margin-bottom: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    align-items: center;
  }

  .user-greeting {
    font-size: 0.85rem;
    color: #166534;
  }

  .user-email {
    font-size: 1rem;
    color: #14532d;
    word-break: break-all;
  }

  .user-subemail {
    font-size: 0.8rem;
    color: #166534;
    opacity: 0.85;
    word-break: break-all;
  }

  .btn-logout {
    margin-top: 0.25rem;
    background: transparent;
    border: 1px solid #ef4444;
    color: #ef4444;
    padding: 0.25rem 0.75rem;
    border-radius: 0.375rem;
    font-size: 0.8rem;
    font-weight: 500;
    cursor: pointer;
  }

  .btn-logout:hover {
    background: #fef2f2;
  }

  .action-section {
    width: 100%;
  }

  .btn-primary {
    width: 100%;
    padding: 0.875rem 1.5rem;
    font-size: 1.125rem;
    font-weight: 600;
    color: #ffffff;
    background-color: var(--primary-color);
    border: none;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: background-color 0.2s ease;
  }

  .btn-primary:hover {
    background-color: var(--primary-hover);
  }

  .btn-secondary {
    width: 100%;
    padding: 0.875rem 1.5rem;
    font-size: 1rem;
    font-weight: 600;
    color: var(--primary-color);
    background-color: #f0f9ff;
    border: 1px solid #bae6fd;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: background-color 0.2s ease;
  }

  .btn-secondary:hover {
    background-color: #e0f2fe;
  }
</style>
