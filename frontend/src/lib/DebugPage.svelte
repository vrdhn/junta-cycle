<script lang="ts">
  import { onMount } from "svelte";
  import { supabase } from "./supabase";

  interface Profile {
    id: string;
    email: string;
    full_name: string | null;
    roles: string[];
    created_at?: string;
  }

  let users = $state<Profile[]>([]);
  let loading = $state(true);
  let errorMsg = $state<string | null>(null);
  let activeUserEmail = $state<string | null>(null);
  let loggingInEmail = $state<string | null>(null);
  let successMsg = $state<string | null>(null);

  const supabaseUrl = (import.meta.env.VITE_SUPABASE_URL || "").replace(/\/+$/, "");
  const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || "";

  async function loadUsers() {
    loading = true;
    errorMsg = null;
    users = [];

    try {
      const debugUrl = `${supabaseUrl}/functions/v1/debug`;
      const res = await fetch(debugUrl, {
        method: "GET",
        headers: {
          apikey: supabaseAnonKey,
          Authorization: `Bearer ${supabaseAnonKey}`,
        },
      });

      if (!res.ok) {
        const text = await res.text();
        let parsedMessage = text;
        try {
          const errObj = JSON.parse(text);
          parsedMessage = errObj.error || errObj.message || text;
        } catch {
          // raw text
        }
        errorMsg = `Endpoint ${debugUrl} failed (HTTP ${res.status}): ${parsedMessage}`;
        return;
      }

      const json = await res.json();
      if (json.users && Array.isArray(json.users)) {
        users = json.users;
      } else {
        errorMsg = `Invalid response from ${debugUrl}: expected { users: [...] }`;
      }
    } catch (e: any) {
      errorMsg = `Network error calling ${supabaseUrl}/functions/v1/debug: ${e.message || e}`;
    } finally {
      loading = false;
    }
  }

  async function checkSession() {
    const { data } = await supabase.auth.getSession();
    activeUserEmail = data?.session?.user?.email ?? null;
  }

  interface Props {
    onNavigate?: (route: "home" | "debug" | "app") => void;
  }

  let { onNavigate }: Props = $props();

  async function loginAs(user: Profile) {
    loggingInEmail = user.email;
    errorMsg = null;
    successMsg = null;
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: user.email,
        password: "junta123",
      });

      if (error) {
        errorMsg = `Login failed for ${user.email}: ${error.message}`;
      } else {
        activeUserEmail = data?.user?.email ?? user.email;
        successMsg = `Logged in as ${user.full_name || user.email}`;
        if (onNavigate) {
          onNavigate("app");
        } else {
          window.location.hash = "app";
        }
      }
    } catch (e: any) {
      errorMsg = `Error logging in: ${e.message || e}`;
    } finally {
      loggingInEmail = null;
    }
  }

  async function logout() {
    await supabase.auth.signOut();
    activeUserEmail = null;
    successMsg = "Logged out successfully.";
  }

  onMount(() => {
    checkSession();
    loadUsers();

    const { data: authListener } = supabase.auth.onAuthStateChange((_event, session) => {
      activeUserEmail = session?.user?.email ?? null;
    });

    return () => {
      authListener.subscription.unsubscribe();
    };
  });
</script>

<div class="users-container">
  <div class="debug-banner">
    &lt;DEBUG PAGE, NOT FOR PRODUCTION&gt;
  </div>

  <div class="header-nav">
    <button class="nav-back" onclick={() => onNavigate ? onNavigate("home") : (window.location.hash = "")}>← Back to Home</button>
    {#if activeUserEmail}
      <button class="nav-app" onclick={() => onNavigate ? onNavigate("app") : (window.location.hash = "app")}>Go to /app ➔</button>
    {/if}
    <span class="badge-secret">/debug</span>
  </div>

  <div class="session-card">
    <div class="session-info">
      {#if activeUserEmail}
        <span class="session-indicator active"></span>
        <span>Active User: <strong>{activeUserEmail}</strong></span>
      {:else}
        <span class="session-indicator inactive"></span>
        <span class="session-none">Not logged in (Click on any name below to log in)</span>
      {/if}
    </div>
    {#if activeUserEmail}
      <div class="session-actions">
        <button class="btn-app-action" onclick={() => onNavigate ? onNavigate("app") : (window.location.hash = "app")}>Open /app ➔</button>
        <button class="btn-logout" onclick={logout}>Log Out</button>
      </div>
    {/if}
  </div>

  {#if successMsg}
    <div class="alert alert-success">{successMsg}</div>
  {/if}

  {#if errorMsg}
    <div class="alert alert-error">{errorMsg}</div>
  {/if}

  <div class="table-card">
    <div class="table-header">
      <div class="table-title-group">
        <h2>System Users &amp; Roles</h2>
        <span class="badge-endpoint">GET /functions/v1/debug</span>
      </div>
      <button class="btn-refresh" onclick={loadUsers} title="Refresh users from backend">
        ↻ Refresh
      </button>
    </div>

    {#if loading}
      <div class="table-loading">Calling /debug REST endpoint...</div>
    {:else if users.length === 0}
      <div class="table-empty">
        {#if errorMsg}
          No users loaded due to endpoint error.
        {:else}
          No users found in database. Run <code>./jctool db-demo</code> to seed users.
        {/if}
      </div>
    {:else}
      <div class="table-wrapper">
        <table class="users-table">
          <thead>
            <tr>
              <th class="col-num">#</th>
              <th>Full Name (Click to Login)</th>
              <th>Email</th>
              <th>Roles</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {#each users as user, idx}
              <tr class:current-user={activeUserEmail === user.email}>
                <td class="col-num">{idx + 1}</td>
                <td class="col-name">
                  <button
                    class="btn-login-user"
                    disabled={loggingInEmail === user.email}
                    onclick={() => loginAs(user)}
                    title={`Click to log in as ${user.full_name || user.email}`}
                  >
                    {#if loggingInEmail === user.email}
                      <span>Logging in...</span>
                    {:else}
                      <span class="user-name">{user.full_name || "Unnamed"}</span>
                      <span class="user-arrow">➔</span>
                    {/if}
                  </button>
                </td>
                <td class="col-email">{user.email}</td>
                <td class="col-roles">
                  <div class="roles-wrap">
                    {#each user.roles as role}
                      <span class={`role-badge role-${role}`}>{role}</span>
                    {/each}
                  </div>
                </td>
                <td class="col-status">
                  {#if activeUserEmail === user.email}
                    <span class="badge-active">Logged In</span>
                  {:else}
                    <span class="badge-idle">—</span>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>

<style>
  .users-container {
    width: 100%;
    max-width: 1280px;
    margin: 1.25rem auto;
    padding: 0 clamp(0.75rem, 3vw, 2rem);
    box-sizing: border-box;
  }

  .debug-banner {
    background: #fee2e2;
    border: 2px solid #ef4444;
    color: #991b1b;
    font-weight: 800;
    font-size: clamp(0.95rem, 2.5vw, 1.2rem);
    letter-spacing: 0.06em;
    text-align: center;
    padding: 0.85rem 1.25rem;
    border-radius: 0.75rem;
    margin-bottom: 1.25rem;
    box-shadow: 0 4px 6px -1px rgba(239, 68, 68, 0.12), 0 2px 4px -2px rgba(239, 68, 68, 0.08);
  }

  .header-nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    gap: 0.75rem;
  }

  .nav-back {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    color: var(--primary-color);
    background: transparent;
    border: none;
    cursor: pointer;
    text-decoration: none;
    font-weight: 600;
    font-size: 0.95rem;
    padding: 0.4rem 0.75rem;
    border-radius: 0.5rem;
    transition: background-color 0.15s;
  }

  .nav-back:hover {
    background-color: #f0fdfa;
    text-decoration: none;
  }

  .nav-app {
    display: inline-flex;
    align-items: center;
    color: #047857;
    background-color: #d1fae5;
    border: none;
    cursor: pointer;
    text-decoration: none;
    font-weight: 700;
    font-size: 0.95rem;
    padding: 0.4rem 0.85rem;
    border-radius: 0.5rem;
    transition: background-color 0.15s;
  }

  .nav-app:hover {
    background-color: #a7f3d0;
  }

  .session-actions {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .btn-app-action {
    display: inline-flex;
    align-items: center;
    background-color: var(--primary-color);
    color: white;
    border: none;
    cursor: pointer;
    text-decoration: none;
    font-size: 0.85rem;
    font-weight: 600;
    padding: 0.35rem 0.85rem;
    border-radius: 0.5rem;
    transition: background-color 0.15s;
  }

  .btn-app-action:hover {
    background-color: var(--primary-hover);
  }

  .badge-secret {
    background: #f1f5f9;
    color: #475569;
    border: 1px solid #cbd5e1;
    border-radius: 9999px;
    font-size: 0.8rem;
    padding: 0.25rem 0.75rem;
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    font-weight: 600;
  }

  .session-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 0.75rem;
    padding: 0.875rem 1.25rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1.25rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  }

  .session-info {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    font-size: 0.95rem;
  }

  .session-indicator {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .session-indicator.active {
    background: #10b981;
    box-shadow: 0 0 6px rgba(16, 185, 129, 0.6);
  }

  .session-indicator.inactive {
    background: #94a3b8;
  }

  .session-none {
    color: var(--text-muted);
  }

  .btn-logout {
    background: transparent;
    border: 1px solid #ef4444;
    color: #ef4444;
    padding: 0.35rem 0.85rem;
    border-radius: 0.5rem;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .btn-logout:hover {
    background: #fef2f2;
    border-color: #dc2626;
  }

  .alert {
    padding: 0.85rem 1.25rem;
    border-radius: 0.5rem;
    font-size: 0.925rem;
    margin-bottom: 1.25rem;
  }

  .alert-success {
    background: #ecfdf5;
    color: #065f46;
    border: 1px solid #a7f3d0;
  }

  .alert-error {
    background: #fef2f2;
    color: #991b1b;
    border: 1px solid #fecaca;
  }

  .table-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 0.75rem;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -2px rgba(0, 0, 0, 0.05);
    overflow: hidden;
  }

  .table-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border-color);
    background: var(--card-header-bg);
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .table-title-group {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .badge-endpoint {
    font-size: 0.75rem;
    font-weight: 600;
    padding: 0.2rem 0.65rem;
    border-radius: 9999px;
    background: var(--card-bg-subtle);
    color: var(--text-muted);
    border: 1px solid var(--border-color);
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  }

  .table-header h2 {
    font-size: clamp(1.1rem, 2vw, 1.3rem);
    font-weight: 700;
    margin: 0;
    color: var(--text-main);
  }

  .btn-refresh {
    background: var(--card-bg-subtle);
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    padding: 0.4rem 0.85rem;
    font-size: 0.85rem;
    font-weight: 500;
    cursor: pointer;
    color: var(--text-main);
    transition: all 0.15s ease;
  }

  .btn-refresh:hover {
    background: var(--input-bg);
    color: var(--text-main);
    border-color: var(--primary-color);
  }

  .table-loading,
  .table-empty {
    padding: 3rem 1.5rem;
    text-align: center;
    color: var(--text-muted);
    font-size: 1rem;
  }

  .table-wrapper {
    width: 100%;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
  }

  .users-table {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
    text-align: left;
    font-size: 0.925rem;
  }

  .users-table th {
    background: var(--card-header-bg);
    color: var(--text-muted);
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    padding: 0.875rem 1rem;
    border-bottom: 1px solid var(--border-color);
    white-space: nowrap;
    position: sticky;
    top: 0;
    z-index: 5;
  }

  .users-table td {
    padding: 0.875rem 1rem;
    border-bottom: 1px solid var(--border-color);
    color: var(--text-main);
    vertical-align: middle;
    transition: background-color 0.15s ease;
  }

  .users-table tr:last-child td {
    border-bottom: none;
  }

  .users-table tr:hover td {
    background-color: var(--table-hover);
  }

  .users-table tr.current-user td {
    background-color: var(--active-row-bg);
  }

  .users-table tr.current-user td:first-child {
    border-left: 3px solid #10b981;
  }

  .col-num {
    color: var(--text-muted);
    width: 44px;
    font-size: 0.825rem;
    font-variant-numeric: tabular-nums;
  }

  .btn-login-user {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    background: var(--highlight-box);
    border: 1px solid var(--border-color);
    padding: 0.4rem 0.75rem;
    border-radius: 0.5rem;
    cursor: pointer;
    font-weight: 600;
    color: var(--primary-color);
    text-align: left;
    font-size: 0.925rem;
    transition: all 0.15s ease;
  }

  .btn-login-user:hover:not(:disabled) {
    background: var(--card-bg-subtle);
    border-color: var(--primary-color);
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(13, 148, 136, 0.12);
  }

  .user-arrow {
    opacity: 0.6;
    transition: transform 0.15s, opacity 0.15s;
    font-size: 0.8rem;
  }

  .btn-login-user:hover .user-arrow {
    opacity: 1;
    transform: translateX(3px);
  }

  .col-email {
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    color: #64748b;
    font-size: 0.875rem;
    white-space: nowrap;
  }

  .roles-wrap {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem;
  }

  .role-badge {
    display: inline-block;
    padding: 0.25rem 0.65rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.02em;
    text-transform: capitalize;
  }

  .role-badge.role-superuser {
    background: #f3e8ff;
    color: #7e22ce;
    border: 1px solid #d8b4fe;
  }

  .role-badge.role-manager {
    background: #e0f2fe;
    color: #0369a1;
    border: 1px solid #bae6fd;
  }

  .role-badge.role-rider {
    background: #dcfce7;
    color: #15803d;
    border: 1px solid #bbf7d0;
  }

  .badge-active {
    background: #10b981;
    color: #ffffff;
    font-size: 0.75rem;
    font-weight: 700;
    letter-spacing: 0.03em;
    padding: 0.25rem 0.65rem;
    border-radius: 9999px;
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
  }

  .badge-active::before {
    content: "";
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #ffffff;
    display: inline-block;
  }

  .badge-idle {
    color: #cbd5e1;
    font-size: 0.9rem;
  }

  @media (max-width: 640px) {
    .users-container {
      padding: 0 0.75rem;
    }

    .session-card {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.75rem;
    }

    .btn-logout {
      width: 100%;
      text-align: center;
    }

    .col-num {
      display: none;
    }

    .users-table th,
    .users-table td {
      padding: 0.65rem 0.75rem;
      font-size: 0.85rem;
    }

    .btn-login-user {
      padding: 0.35rem 0.55rem;
      font-size: 0.85rem;
    }

    .col-email {
      font-size: 0.8rem;
    }
  }
</style>
