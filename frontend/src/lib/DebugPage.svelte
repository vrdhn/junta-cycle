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

  async function loadUsers() {
    loading = true;
    errorMsg = null;
    try {
      const { data, error } = await supabase
        .from("profiles")
        .select("id, email, full_name, roles, created_at")
        .order("email");

      if (error) {
        console.warn("Could not fetch remote profiles, using fallback list:", error.message);
        users = DEMO_FALLBACK;
      } else if (data && data.length > 0) {
        users = data;
      } else {
        users = DEMO_FALLBACK;
      }
    } catch (e: any) {
      console.warn("Error fetching profiles:", e);
      users = DEMO_FALLBACK;
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
      <h2>System Users &amp; Roles</h2>
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
              <th>#</th>
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
    max-width: 900px;
    margin: 1.5rem auto;
    padding: 0 1rem;
    box-sizing: border-box;
  }

  .debug-banner {
    background: #fee2e2;
    border: 2px solid #ef4444;
    color: #991b1b;
    font-weight: 800;
    font-size: 1.15rem;
    letter-spacing: 0.05em;
    text-align: center;
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    margin-bottom: 1.25rem;
    box-shadow: 0 2px 4px rgba(239, 68, 68, 0.15);
  }

  .header-nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .nav-back {
    color: var(--primary-color);
    text-decoration: none;
    font-weight: 500;
    font-size: 0.95rem;
  }

  .nav-back:hover {
    text-decoration: underline;
  }

  .badge-secret {
    background: #f1f5f9;
    color: #64748b;
    border: 1px solid #cbd5e1;
    border-radius: 9999px;
    font-size: 0.75rem;
    padding: 0.2rem 0.6rem;
    font-family: monospace;
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
    margin-bottom: 1rem;
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
    padding: 0.35rem 0.8rem;
    border-radius: 0.375rem;
    font-size: 0.85rem;
    font-weight: 500;
    cursor: pointer;
  }

  .btn-logout:hover {
    background: #fef2f2;
  }

  .alert {
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    font-size: 0.9rem;
    margin-bottom: 1rem;
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
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
    overflow: hidden;
  }

  .table-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border-color);
  }

  .table-header h2 {
    font-size: 1.25rem;
    font-weight: 600;
    margin: 0;
    color: var(--text-main);
  }

  .btn-refresh {
    background: transparent;
    border: 1px solid var(--border-color);
    border-radius: 0.375rem;
    padding: 0.3rem 0.7rem;
    font-size: 0.85rem;
    cursor: pointer;
    color: var(--text-muted);
  }

  .btn-refresh:hover {
    background: #f8fafc;
    color: var(--text-main);
  }

  .table-loading {
    padding: 2rem;
    text-align: center;
    color: var(--text-muted);
  }

  .table-wrapper {
    overflow-x: auto;
  }

  .users-table {
    width: 100%;
    border-collapse: collapse;
    text-align: left;
    font-size: 0.9rem;
  }

  .users-table th {
    background: #f8fafc;
    color: #475569;
    font-weight: 600;
    padding: 0.75rem 1rem;
    border-bottom: 1px solid var(--border-color);
    white-space: nowrap;
  }

  .users-table td {
    padding: 0.75rem 1rem;
    border-bottom: 1px solid var(--border-color);
    vertical-align: middle;
  }

  .users-table tr:last-child td {
    border-bottom: none;
  }

  .users-table tr:hover {
    background-color: #f8fafc;
  }

  .users-table tr.current-user {
    background-color: #f0fdf4;
  }

  .col-num {
    color: #94a3b8;
    width: 30px;
    font-size: 0.8rem;
  }

  .btn-login-user {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    background: transparent;
    border: none;
    padding: 0.25rem 0.5rem;
    border-radius: 0.375rem;
    cursor: pointer;
    font-weight: 600;
    color: var(--primary-color);
    text-align: left;
    transition: background 0.15s, color 0.15s;
  }

  .btn-login-user:hover {
    background: #e0f2fe;
    color: #0369a1;
  }

  .user-arrow {
    opacity: 0;
    transition: opacity 0.15s, transform 0.15s;
    font-size: 0.75rem;
  }

  .btn-login-user:hover .user-arrow {
    opacity: 1;
    transform: translateX(2px);
  }

  .col-email {
    font-family: monospace;
    color: #64748b;
    font-size: 0.85rem;
  }

  .roles-wrap {
    display: flex;
    flex-wrap: wrap;
    gap: 0.35rem;
  }

  .role-badge {
    display: inline-block;
    padding: 0.2rem 0.55rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
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
    font-weight: 600;
    padding: 0.2rem 0.5rem;
    border-radius: 0.25rem;
  }

  .badge-idle {
    color: #cbd5e1;
  }
</style>
