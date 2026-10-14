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

  // Predefined demo fallback in case database is empty or offline
  const DEMO_FALLBACK: Profile[] = [
    { id: "1", email: "aarav@junta.cycle", full_name: "Aarav Patel", roles: ["superuser"] },
    { id: "2", email: "bhavna@junta.cycle", full_name: "Bhavna Sharma", roles: ["manager", "rider"] },
    { id: "3", email: "chirag@junta.cycle", full_name: "Chirag Gupta", roles: ["manager", "rider"] },
    { id: "4", email: "divya@junta.cycle", full_name: "Divya Nair", roles: ["manager", "rider"] },
    { id: "5", email: "eshan@junta.cycle", full_name: "Eshan Reddy", roles: ["rider"] },
    { id: "6", email: "fatima@junta.cycle", full_name: "Fatima Khan", roles: ["rider"] },
    { id: "7", email: "gopal@junta.cycle", full_name: "Gopal Krishnan", roles: ["rider"] },
    { id: "8", email: "hema@junta.cycle", full_name: "Hema Sundaram", roles: ["rider"] },
    { id: "9", email: "ishan@junta.cycle", full_name: "Ishan Joshi", roles: ["rider"] },
    { id: "10", email: "jaya@junta.cycle", full_name: "Jaya Verma", roles: ["rider"] },
  ];

  let users = $state<Profile[]>([]);
  let loading = $state(true);
  let errorMsg = $state<string | null>(null);
  let activeUserEmail = $state<string | null>(null);
  let loggingInEmail = $state<string | null>(null);
  let successMsg = $state<string | null>(null);
  let dataSource = $state<"backend" | "fallback" | "loading">("loading");

  async function loadUsers() {
    loading = true;
    errorMsg = null;
    try {
      const { data, error } = await supabase
        .from("profiles")
        .select("id, email, full_name, roles, created_at")
        .order("email");

      if (error) {
        errorMsg = `Backend fetch failed (${error.code}: ${error.message}). Showing local fallback data. Hint: apply migrations with GRANT SELECT privileges.`;
        users = DEMO_FALLBACK;
        dataSource = "fallback";
      } else if (data && data.length > 0) {
        users = data;
        dataSource = "backend";
      } else {
        errorMsg = "Backend returned 0 users. Showing demo fallback data. Run './jctool db-demo' to seed users.";
        users = DEMO_FALLBACK;
        dataSource = "fallback";
      }
    } catch (e: any) {
      errorMsg = `Connection error: ${e.message || e}. Showing local fallback data.`;
      users = DEMO_FALLBACK;
      dataSource = "fallback";
    } finally {
      loading = false;
    }
  }

  async function checkSession() {
    const { data } = await supabase.auth.getSession();
    activeUserEmail = data?.session?.user?.email ?? null;
  }

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
    <a href="./" class="nav-back">← Back to Home</a>
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
      <button class="btn-logout" onclick={logout}>Log Out</button>
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
        {#if dataSource === "backend"}
          <span class="badge-source live" title="Successfully queried from Supabase profiles table">
            ● Live from Supabase
          </span>
        {:else if dataSource === "fallback"}
          <span class="badge-source fallback" title="Showing local fallback data because database query failed or returned 0 rows">
            ⚠ Local Fallback
          </span>
        {/if}
      </div>
      <button class="btn-refresh" onclick={loadUsers} title="Refresh users from database">
        ↻ Refresh
      </button>
    </div>

    {#if loading}
      <div class="table-loading">Loading users...</div>
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
    background: #fafafa;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .table-title-group {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .badge-source {
    font-size: 0.75rem;
    font-weight: 600;
    padding: 0.2rem 0.65rem;
    border-radius: 9999px;
    letter-spacing: 0.02em;
  }

  .badge-source.live {
    background: #ecfdf5;
    color: #065f46;
    border: 1px solid #a7f3d0;
  }

  .badge-source.fallback {
    background: #fef3c7;
    color: #92400e;
    border: 1px solid #fde68a;
  }

  .table-header h2 {
    font-size: clamp(1.1rem, 2vw, 1.3rem);
    font-weight: 700;
    margin: 0;
    color: var(--text-main);
  }

  .btn-refresh {
    background: #ffffff;
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    padding: 0.4rem 0.85rem;
    font-size: 0.85rem;
    font-weight: 500;
    cursor: pointer;
    color: var(--text-muted);
    transition: all 0.15s ease;
  }

  .btn-refresh:hover {
    background: #f8fafc;
    color: var(--text-main);
    border-color: #cbd5e1;
  }

  .table-loading {
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
    background: #f8fafc;
    color: #475569;
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
    vertical-align: middle;
    transition: background-color 0.15s ease;
  }

  .users-table tr:last-child td {
    border-bottom: none;
  }

  .users-table tr:hover td {
    background-color: #f8fafc;
  }

  .users-table tr.current-user td {
    background-color: #f0fdf4;
  }

  .users-table tr.current-user td:first-child {
    border-left: 3px solid #10b981;
  }

  .col-num {
    color: #94a3b8;
    width: 44px;
    font-size: 0.825rem;
    font-variant-numeric: tabular-nums;
  }

  .btn-login-user {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    background: #f0fdfa;
    border: 1px solid #ccfbf1;
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
    background: #ccfbf1;
    border-color: #99f6e4;
    color: #0f766e;
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
