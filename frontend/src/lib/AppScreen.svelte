<script lang="ts">
  import { onMount } from "svelte";
  import { supabase } from "./supabase";
  import LocationsAdmin from "./LocationsAdmin.svelte";
  import ManagerCyclesView from "./ManagerCyclesView.svelte";

  interface Props {
    user: any;
    onNavigate: (route: "home" | "debug" | "app") => void;
    onLogout: () => Promise<void>;
  }

  let { user, onNavigate, onLogout }: Props = $props();

  interface UserProfile {
    id: string;
    email: string;
    full_name: string | null;
    roles: string[];
  }

  let profile = $state<UserProfile | null>(null);
  let loadingProfile = $state(true);
  let errorMsg = $state<string | null>(null);
  let selectedRole = $state<string>("rider");

  // Rider state demo
  let bikeCode = $state("");
  let unlockedBike = $state<{ id: string; lockCode: string } | null>(null);
  let rideActive = $state(false);
  let rideStart = $state<Date | null>(null);

  async function loadProfile() {
    if (!user) return;
    loadingProfile = true;
    errorMsg = null;
    try {
      const { data, error } = await supabase
        .from("profiles")
        .select("id, email, full_name, roles")
        .eq("id", user.id)
        .single();

      if (error) {
        errorMsg = `Could not load profile: ${error.message}`;
      } else if (data) {
        profile = data;
        if (data.roles && data.roles.length > 0) {
          selectedRole = data.roles[0];
        }
      }
    } catch (e: any) {
      errorMsg = `Failed to fetch profile: ${e.message || e}`;
    } finally {
      loadingProfile = false;
    }
  }

  function handleUnlock() {
    if (!bikeCode.trim()) return;
    const dummyCode = String(Math.floor(1000 + Math.random() * 9000));
    unlockedBike = { id: bikeCode.trim().toUpperCase(), lockCode: dummyCode };
    rideActive = true;
    rideStart = new Date();
  }

  function handleEndRide() {
    rideActive = false;
    unlockedBike = null;
    bikeCode = "";
  }

  onMount(() => {
    loadProfile();
  });
</script>

<div class="app-container">
  <div class="app-nav-header">
    <div class="nav-left">
      <button class="btn-text" onclick={() => onNavigate("home")}>← Home</button>
      <span class="nav-badge">/app</span>
    </div>
    <div class="nav-right">
      <button class="btn-text" onclick={() => onNavigate("debug")}>Switch User (/debug)</button>
      <button class="btn-logout" onclick={onLogout}>Log Out</button>
    </div>
  </div>

  <div class="welcome-header">
    <div class="user-greeting">
      <h1>Hello, {profile?.full_name || user?.user_metadata?.full_name || user?.email}</h1>
      <p class="user-email">{user?.email}</p>
    </div>
    {#if profile?.roles && profile.roles.length > 0}
      <div class="assigned-roles-pill">
        {#each profile.roles as r}
          <span class={`badge-role badge-${r}`}>{r}</span>
        {/each}
      </div>
    {/if}
  </div>

  {#if loadingProfile}
    <div class="card loading-card">Loading your roles and profile...</div>
  {:else if errorMsg}
    <div class="card error-card">{errorMsg}</div>
  {:else if profile && profile.roles.length > 0}
    <!-- Role Tabs -->
    <div class="tabs-bar">
      {#each profile.roles as role}
        <button
          class="tab-btn"
          class:active={selectedRole === role}
          onclick={() => (selectedRole = role)}
        >
          {#if role === "rider"}
            🚴 Rider
          {:else if role === "manager"}
            🛠️ Manager
          {:else if role === "superuser"}
            ⚡ Superuser
          {:else}
            {role}
          {/if}
        </button>
      {/each}
    </div>

    <!-- Active Role Tab Content -->
    <div class="tab-content">
      {#if selectedRole === "rider"}
        <div class="role-view">
          <div class="card">
            <h2>🚴 Rider Dashboard</h2>
            <p class="card-desc">Scan a bike's QR code or enter its Bike ID to unlock physical combination lock.</p>

            {#if !rideActive}
              <div class="unlock-form">
                <label for="bike-input">Bike Identifier / QR ID</label>
                <div class="input-row">
                  <input
                    id="bike-input"
                    type="text"
                    placeholder="e.g. JC-104"
                    bind:value={bikeCode}
                  />
                  <button class="btn-primary" onclick={handleUnlock} disabled={!bikeCode.trim()}>
                    Unlock Bike
                  </button>
                </div>
              </div>
            {:else}
              <div class="active-ride-box">
                <div class="ride-header">
                  <span class="badge-active">Ride in Progress</span>
                  <h3>Bike: {unlockedBike?.id}</h3>
                </div>
                <div class="lock-code-banner">
                  <span class="lock-label">Physical Lock Combination:</span>
                  <span class="lock-number">{unlockedBike?.lockCode}</span>
                  <p class="lock-hint">Rotate dials on the physical combination lock to this 4-digit code.</p>
                </div>
                <button class="btn-danger" onclick={handleEndRide}>
                  End Ride &amp; Lock Bike
                </button>
              </div>
            {/if}
          </div>

          <div class="grid-two">
            <div class="card">
              <h3>Station Stand Locations</h3>
              <ul class="info-list">
                <li><strong>Station 1:</strong> Main Gate (8 bikes available)</li>
                <li><strong>Station 2:</strong> Library Plaza (5 bikes available)</li>
                <li><strong>Station 3:</strong> Sports Complex (3 bikes available)</li>
              </ul>
            </div>
            <div class="card">
              <h3>Rider Guidelines</h3>
              <ul class="info-list">
                <li>Always scramble the combination dials after locking.</li>
                <li>Report damaged brakes or chains immediately.</li>
                <li>Return cycles only to designated yellow rack stands.</li>
              </ul>
            </div>
          </div>
        </div>

      {:else if selectedRole === "manager"}
        <div class="role-view">
          <ManagerCyclesView userId={user.id} />
        </div>

      {:else if selectedRole === "superuser"}
        <div class="role-view">
          <LocationsAdmin />

          <div class="card">
            <h2>⚡ System Administration</h2>
            <p class="card-desc">System configuration, global access controls, and diagnostics.</p>

            <div class="superuser-actions">
              <button class="btn-primary" onclick={() => onNavigate("debug")}>
                Open User Accounts &amp; Roles Table (/debug) ➔
              </button>
            </div>
          </div>

          <div class="grid-two">
            <div class="card">
              <h3>System Health</h3>
              <ul class="info-list">
                <li><strong>Database:</strong> PostgreSQL 17 (Supabase Managed)</li>
                <li><strong>Edge Functions:</strong> <code>GET /debug</code> (Active)</li>
                <li><strong>Row Level Security:</strong> Disabled (App Logic Authorization)</li>
              </ul>
            </div>
            <div class="card">
              <h3>Security &amp; Policy</h3>
              <ul class="info-list">
                <li>Zero client fallback mock data policy active.</li>
                <li>OpenSSL PBKDF2 AES-256 encrypted configuration.</li>
                <li>Isolated cached runtimes in <code>~/.cache/junta-cycle</code>.</li>
              </ul>
            </div>
          </div>
        </div>
      {/if}
    </div>
  {:else}
    <div class="card">No roles assigned to this account. Contact an administrator.</div>
  {/if}
</div>

<style>
  .app-container {
    width: 100%;
    max-width: 1100px;
    margin: 0 auto;
    padding: 0 clamp(0.75rem, 3vw, 2rem);
  }

  .app-nav-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.25rem;
    gap: 0.75rem;
  }

  .nav-left, .nav-right {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .nav-badge {
    background: #e2e8f0;
    color: #475569;
    padding: 0.2rem 0.5rem;
    border-radius: 9999px;
    font-size: 0.8rem;
    font-family: monospace;
    font-weight: 600;
  }

  .btn-text {
    background: none;
    border: none;
    color: var(--primary-color);
    font-weight: 600;
    cursor: pointer;
    font-size: 0.9rem;
    padding: 0.35rem 0.6rem;
    border-radius: 0.375rem;
    transition: background-color 0.15s;
  }

  .btn-text:hover {
    background: #f0fdfa;
  }

  .btn-logout {
    background: transparent;
    border: 1px solid #ef4444;
    color: #ef4444;
    padding: 0.3rem 0.75rem;
    border-radius: 0.375rem;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }

  .btn-logout:hover {
    background: #fef2f2;
  }

  .welcome-header {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 0.75rem;
    padding: 1.25rem 1.5rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
    margin-bottom: 1.5rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
  }

  .user-greeting h1 {
    font-size: clamp(1.25rem, 3vw, 1.6rem);
    color: var(--text-main);
    margin-bottom: 0.2rem;
  }

  .user-email {
    font-size: 0.9rem;
    color: var(--text-muted);
  }

  .assigned-roles-pill {
    display: flex;
    gap: 0.4rem;
    flex-wrap: wrap;
  }

  .badge-role {
    padding: 0.25rem 0.65rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: capitalize;
  }

  .badge-rider {
    background: #dcfce7;
    color: #15803d;
    border: 1px solid #bbf7d0;
  }

  .badge-manager {
    background: #e0f2fe;
    color: #0369a1;
    border: 1px solid #bae6fd;
  }

  .badge-superuser {
    background: #f3e8ff;
    color: #7e22ce;
    border: 1px solid #d8b4fe;
  }

  .tabs-bar {
    display: flex;
    gap: 0.5rem;
    border-bottom: 2px solid var(--border-color);
    margin-bottom: 1.5rem;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
  }

  .tab-btn {
    padding: 0.75rem 1.25rem;
    background: none;
    border: none;
    border-bottom: 3px solid transparent;
    font-size: 1rem;
    font-weight: 600;
    color: var(--text-muted);
    cursor: pointer;
    transition: all 0.2s ease;
    white-space: nowrap;
    margin-bottom: -2px;
  }

  .tab-btn:hover {
    color: var(--text-main);
  }

  .tab-btn.active {
    color: var(--primary-color);
    border-bottom-color: var(--primary-color);
    background: #f0fdfa;
    border-top-left-radius: 0.5rem;
    border-top-right-radius: 0.5rem;
  }

  .tab-content {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .role-view {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 0.75rem;
    padding: 1.5rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
  }

  .card h2 {
    font-size: 1.35rem;
    margin-bottom: 0.35rem;
    color: var(--text-main);
  }

  .card h3 {
    font-size: 1.1rem;
    margin-bottom: 0.75rem;
    color: var(--text-main);
  }

  .card-desc {
    color: var(--text-muted);
    font-size: 0.95rem;
    margin-bottom: 1.25rem;
  }

  .unlock-form {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    max-width: 440px;
  }

  .unlock-form label {
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--text-main);
  }

  .input-row {
    display: flex;
    gap: 0.5rem;
  }

  .input-row input {
    flex: 1;
    padding: 0.65rem 0.85rem;
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    font-size: 1rem;
  }

  .input-row input:focus {
    outline: none;
    border-color: var(--primary-color);
  }

  .btn-primary {
    background: var(--primary-color);
    color: white;
    border: none;
    padding: 0.65rem 1.25rem;
    border-radius: 0.5rem;
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.15s;
    white-space: nowrap;
  }

  .btn-primary:hover:not(:disabled) {
    background: var(--primary-hover);
  }

  .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-danger {
    background: #ef4444;
    color: white;
    border: none;
    padding: 0.65rem 1.25rem;
    border-radius: 0.5rem;
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.15s;
    width: 100%;
    max-width: 280px;
  }

  .btn-danger:hover {
    background: #dc2626;
  }

  .active-ride-box {
    background: #f0fdf4;
    border: 1px solid #bbf7d0;
    border-radius: 0.75rem;
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .ride-header {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .badge-active {
    background: #10b981;
    color: white;
    padding: 0.2rem 0.6rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 700;
  }

  .lock-code-banner {
    background: white;
    border: 1px dashed #10b981;
    border-radius: 0.5rem;
    padding: 1rem;
    text-align: center;
  }

  .lock-label {
    display: block;
    font-size: 0.85rem;
    color: #166534;
    font-weight: 600;
    margin-bottom: 0.25rem;
  }

  .lock-number {
    display: block;
    font-size: 2.25rem;
    font-weight: 800;
    letter-spacing: 0.25em;
    color: #14532d;
    font-family: monospace;
  }

  .lock-hint {
    font-size: 0.8rem;
    color: var(--text-muted);
    margin-top: 0.25rem;
  }

  .grid-two {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1.25rem;
  }

  .info-list {
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    font-size: 0.925rem;
    color: var(--text-main);
  }

  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 1rem;
  }

  .stat-card {
    background: #f8fafc;
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    padding: 1rem;
    text-align: center;
  }

  .stat-num {
    display: block;
    font-size: 1.75rem;
    font-weight: 800;
    color: var(--text-main);
  }

  .stat-label {
    font-size: 0.8rem;
    color: var(--text-muted);
    font-weight: 600;
  }

  .loading-card, .error-card {
    text-align: center;
    color: var(--text-muted);
    padding: 2.5rem;
  }

  .error-card {
    color: #991b1b;
    background: #fef2f2;
    border-color: #fecaca;
  }
</style>
