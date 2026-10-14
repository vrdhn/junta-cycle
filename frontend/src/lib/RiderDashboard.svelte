<script lang="ts">
  import { onMount } from "svelte";
  import { supabase } from "./supabase";

  interface Props {
    userId: string;
    userEmail: string;
    initialCycleIdOrUuid?: string;
  }

  let { userId, userEmail, initialCycleIdOrUuid }: Props = $props();

  interface HomeStandInfo {
    id: string;
    name: string;
    place_name: string;
    city_name: string;
    capacity: number;
  }

  interface AvailableCycle {
    id: string;
    cycle_number: string;
    qr_id: string;
    lock_code: string;
    company_name: string;
    color: string;
    model_number: string;
    status: string;
  }

  interface ActiveCheckout {
    id: string;
    checked_out_at: string;
    status: string;
    cycle: {
      id: string;
      cycle_number: string;
      company_name: string;
      color: string;
      model_number: string;
      lock_code: string;
    };
  }

  interface PrivateStandOption {
    id: string;
    name: string;
    place_name: string;
    city_name: string;
  }

  // State
  let loading = $state(true);
  let errorMsg = $state<string | null>(null);
  let successMsg = $state<string | null>(null);

  let homeStand = $state<HomeStandInfo | null>(null);
  let availableCycles = $state<AvailableCycle[]>([]);
  let activeCheckout = $state<ActiveCheckout | null>(null);

  // Stand picker for users without home stand
  let privateStands = $state<PrivateStandOption[]>([]);
  let selectedStandId = $state<string>("");
  let savingHomeStand = $state(false);

  // Checkout manual input / QR search
  let manualInput = $state("");
  let processingCheckout = $state(false);

  $effect(() => {
    if (initialCycleIdOrUuid) {
      manualInput = initialCycleIdOrUuid;
    }
  });

  // Return cycle state
  let returnCondition = $state<"running" | "puncture" | "broken">("running");
  let returnNotes = $state("");
  let processingReturn = $state(false);

  async function loadRiderData() {
    loading = true;
    errorMsg = null;
    successMsg = null;

    try {
      // 1. Fetch rider profile (home_parking_id)
      const { data: profile, error: profErr } = await supabase
        .from("profiles")
        .select("id, home_parking_id, full_name")
        .eq("id", userId)
        .single();

      if (profErr) throw new Error(`Failed to load profile: ${profErr.message}`);

      // 2. Check for active checkout
      const { data: checkoutsData, error: chkErr } = await supabase
        .from("checkouts")
        .select(`
          id,
          checked_out_at,
          status,
          cycles (
            id,
            cycle_number,
            company_name,
            color,
            model_number,
            lock_code
          )
        `)
        .eq("rider_id", userId)
        .eq("status", "active")
        .maybeSingle();

      if (chkErr) throw new Error(`Failed to check active checkout: ${chkErr.message}`);

      if (checkoutsData && checkoutsData.cycles) {
        activeCheckout = {
          id: checkoutsData.id,
          checked_out_at: checkoutsData.checked_out_at,
          status: checkoutsData.status,
          cycle: checkoutsData.cycles as any
        };
      } else {
        activeCheckout = null;
      }

      // 3. If home_parking_id is set, fetch stand details & available working cycles
      if (profile?.home_parking_id) {
        const { data: stand, error: standErr } = await supabase
          .from("parkings")
          .select(`
            id,
            name,
            capacity,
            places (
              name,
              cities (
                name
              )
            )
          `)
          .eq("id", profile.home_parking_id)
          .single();

        if (standErr) throw new Error(`Failed to load home stand: ${standErr.message}`);

        homeStand = {
          id: stand.id,
          name: stand.name,
          place_name: (stand.places as any)?.name || "Unknown Place",
          city_name: (stand.places as any)?.cities?.name || "Unknown City",
          capacity: stand.capacity
        };

        // Query active checkouts across all cycles to filter out currently checked-out cycles
        const { data: activeCheckouts, error: actErr } = await supabase
          .from("checkouts")
          .select("cycle_id")
          .eq("status", "active");

        if (actErr) throw new Error(`Failed to fetch active checkout states: ${actErr.message}`);

        const busyCycleIds = new Set((activeCheckouts || []).map((c: any) => c.cycle_id));

        // Query cycles at this home stand that are working ('running')
        const { data: cycles, error: cycErr } = await supabase
          .from("cycles")
          .select("id, cycle_number, qr_id, lock_code, company_name, color, model_number, status")
          .eq("parking_id", profile.home_parking_id)
          .eq("status", "running")
          .order("cycle_number");

        if (cycErr) throw new Error(`Failed to load cycles: ${cycErr.message}`);

        // Filter out cycles currently checked out
        availableCycles = (cycles || []).filter((c: AvailableCycle) => !busyCycleIds.has(c.id));
      } else {
        homeStand = null;
        availableCycles = [];
        await loadPrivateStands();
      }

      // If initialCycleIdOrUuid was provided, auto-validate or fill
      if (initialCycleIdOrUuid && !activeCheckout && homeStand) {
        manualInput = initialCycleIdOrUuid;
      }
    } catch (e: any) {
      errorMsg = e.message || String(e);
    } finally {
      loading = false;
    }
  }

  async function loadPrivateStands() {
    try {
      const { data, error } = await supabase
        .from("parkings")
        .select(`
          id,
          name,
          places (
            name,
            cities (
              name
            )
          )
        `)
        .eq("parking_type", "private")
        .order("name");

      if (error) throw error;

      privateStands = (data || []).map((p: any) => ({
        id: p.id,
        name: p.name,
        place_name: p.places?.name || "Unknown Place",
        city_name: p.places?.cities?.name || "Unknown City"
      }));

      if (privateStands.length > 0 && !selectedStandId) {
        selectedStandId = privateStands[0].id;
      }
    } catch (e: any) {
      errorMsg = `Failed to load private stands: ${e.message || e}`;
    }
  }

  async function saveHomeStand() {
    if (!selectedStandId) return;
    savingHomeStand = true;
    errorMsg = null;
    successMsg = null;

    try {
      const { error } = await supabase
        .from("profiles")
        .update({ home_parking_id: selectedStandId })
        .eq("id", userId);

      if (error) throw error;

      successMsg = "Home stand set successfully!";
      await loadRiderData();
    } catch (e: any) {
      errorMsg = `Could not save home stand: ${e.message || e}`;
    } finally {
      savingHomeStand = false;
    }
  }

  async function handleCheckout(cycleId: string) {
    if (!homeStand) {
      errorMsg = "Please assign a home stand before checking out cycles.";
      return;
    }

    processingCheckout = true;
    errorMsg = null;
    successMsg = null;

    try {
      // 1. Fetch and verify cycle
      const { data: cycle, error: cycErr } = await supabase
        .from("cycles")
        .select(`
          id,
          cycle_number,
          parking_id,
          status,
          lock_code,
          company_name,
          color,
          model_number,
          parkings (
            name
          )
        `)
        .eq("id", cycleId)
        .single();

      if (cycErr || !cycle) throw new Error("Cycle not found.");

      // Enforce: cycle must belong to rider's home stand
      if (cycle.parking_id !== homeStand.id) {
        const cycleStandName = (cycle.parkings as any)?.name || "another stand";
        throw new Error(
          `Cycle ${cycle.cycle_number} belongs to "${cycleStandName}", but your registered home stand is "${homeStand.name}". You can only check out cycles from your home stand.`
        );
      }

      // Enforce: cycle must be working ('running')
      if (cycle.status !== "running") {
        throw new Error(`Cycle ${cycle.cycle_number} is marked as "${cycle.status}" and cannot be checked out.`);
      }

      // Enforce: cycle must not already be checked out
      const { data: existingActive, error: actErr } = await supabase
        .from("checkouts")
        .select("id")
        .eq("cycle_id", cycle.id)
        .eq("status", "active")
        .maybeSingle();

      if (actErr) throw actErr;
      if (existingActive) {
        throw new Error(`Cycle ${cycle.cycle_number} is currently checked out by another rider.`);
      }

      // 2. Perform checkout
      const { error: insErr } = await supabase.from("checkouts").insert({
        cycle_id: cycle.id,
        rider_id: userId,
        home_parking_id: homeStand.id,
        status: "active"
      });

      if (insErr) throw insErr;

      successMsg = `Checked out ${cycle.cycle_number}! Rotate lock to code: ${cycle.lock_code}`;
      manualInput = "";
      await loadRiderData();
    } catch (e: any) {
      errorMsg = e.message || String(e);
    } finally {
      processingCheckout = false;
    }
  }

  async function handleManualCheckout() {
    const raw = manualInput.trim();
    if (!raw) return;

    processingCheckout = true;
    errorMsg = null;
    successMsg = null;

    try {
      // Find cycle by cycle_number or qr_id
      const isUuid = /^[0-9a-fA-F-]{36}$/.test(raw);
      let query = supabase.from("cycles").select("id, cycle_number");

      if (isUuid) {
        query = query.eq("qr_id", raw);
      } else {
        query = query.ilike("cycle_number", raw);
      }

      const { data, error } = await query.maybeSingle();

      if (error || !data) {
        throw new Error(`No cycle found matching "${raw}". Please verify the Cycle ID or QR code.`);
      }

      await handleCheckout(data.id);
    } catch (e: any) {
      errorMsg = e.message || String(e);
      processingCheckout = false;
    }
  }

  async function handleReturnCycle() {
    if (!activeCheckout) return;

    processingReturn = true;
    errorMsg = null;
    successMsg = null;

    try {
      // 1. Mark checkout as completed
      const { error: retErr } = await supabase
        .from("checkouts")
        .update({
          returned_at: new Date().toISOString(),
          status: "completed",
          return_parking_id: homeStand?.id || null,
          return_note: returnNotes.trim() || null
        })
        .eq("id", activeCheckout.id);

      if (retErr) throw retErr;

      // 2. If rider reported damage, update cycle status
      if (returnCondition !== "running") {
        const { error: cycErr } = await supabase
          .from("cycles")
          .update({ status: returnCondition })
          .eq("id", activeCheckout.cycle.id);

        if (cycErr) {
          console.warn("Could not update cycle damage status:", cycErr.message);
        }
      }

      successMsg = `Cycle ${activeCheckout.cycle.cycle_number} successfully returned to ${homeStand?.name || "home stand"}. Thank you!`;
      returnNotes = "";
      returnCondition = "running";
      await loadRiderData();
    } catch (e: any) {
      errorMsg = `Failed to return cycle: ${e.message || e}`;
    } finally {
      processingReturn = false;
    }
  }

  function formatTime(iso: string) {
    try {
      return new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    } catch {
      return iso;
    }
  }

  onMount(() => {
    loadRiderData();
  });
</script>

<div class="rider-dashboard">
  <!-- Notifications -->
  {#if errorMsg}
    <div class="alert alert-error">
      <strong>⚠️ Error:</strong> {errorMsg}
      <button class="btn-dismiss" onclick={() => (errorMsg = null)}>✕</button>
    </div>
  {/if}

  {#if successMsg}
    <div class="alert alert-success">
      <strong>✅ Success:</strong> {successMsg}
      <button class="btn-dismiss" onclick={() => (successMsg = null)}>✕</button>
    </div>
  {/if}

  {#if loading}
    <div class="card loading-card">
      <div class="spinner"></div>
      <p>Loading your rider profile and cycles...</p>
    </div>
  {:else if !homeStand}
    <!-- No Home Stand Assigned: Prompt Rider to Pick One -->
    <div class="card setup-card">
      <div class="card-header">
        <div>
          <h2>🏡 Select Your Home Stand</h2>
          <p class="subtitle">
            Cycles belong to private parking stands in your community. You check out cycles from your home stand and return them when finished.
          </p>
        </div>
      </div>

      {#if privateStands.length === 0}
        <p class="empty-text">No private parking stands found. Please ask an administrator to add one.</p>
      {:else}
        <div class="setup-form">
          <label for="home-stand-select">Choose your private society / residential stand:</label>
          <select id="home-stand-select" bind:value={selectedStandId} disabled={savingHomeStand}>
            {#each privateStands as stand}
              <option value={stand.id}>
                {stand.name} ({stand.place_name}, {stand.city_name})
              </option>
            {/each}
          </select>

          <button class="btn-primary" onclick={saveHomeStand} disabled={savingHomeStand || !selectedStandId}>
            {savingHomeStand ? "Saving..." : "Set as My Home Stand"}
          </button>
        </div>
      {/if}
    </div>
  {:else if activeCheckout}
    <!-- Active Checkout Screen -->
    <div class="card active-checkout-card">
      <div class="checkout-status-header">
        <span class="badge-active-checkout">⚡ Active Checkout in Progress</span>
        <span class="checkout-time">Started at {formatTime(activeCheckout.checked_out_at)}</span>
      </div>

      <div class="cycle-summary">
        <h2>Cycle {activeCheckout.cycle.cycle_number}</h2>
        <p class="specs">
          {activeCheckout.cycle.company_name} • {activeCheckout.cycle.model_number} • <span class="color-text">{activeCheckout.cycle.color}</span>
        </p>
        <p class="home-tag">Origin Home Stand: <strong>{homeStand.name}</strong> ({homeStand.place_name})</p>
      </div>

      <!-- High Visibility Combination Lock Display -->
      <div class="lock-box">
        <span class="lock-title">🔐 Physical Lock Combination</span>
        <div class="lock-digits">{activeCheckout.cycle.lock_code}</div>
        <p class="lock-instruction">
          Rotate dials on the cycle's physical cable lock to this 4-digit code to open it.<br/>
          <strong>Security Notice:</strong> Always scramble the dials after locking when parking at public/interim stands!
        </p>
      </div>

      <!-- Return Cycle Section -->
      <div class="return-section">
        <h3>🔄 Return Cycle to Home Stand</h3>
        <p class="return-desc">
          When you bring the cycle back to <strong>{homeStand.name}</strong>, lock it to the stand, scramble the dials, and confirm below:
        </p>

        <div class="condition-picker">
          <span class="section-label">Cycle Condition on Return:</span>
          <div class="radio-group">
            <label class="radio-label">
              <input type="radio" bind:group={returnCondition} value="running" />
              <span>🟢 Working fine (ready for next rider)</span>
            </label>
            <label class="radio-label">
              <input type="radio" bind:group={returnCondition} value="puncture" />
              <span>🟡 Puncture / Low tire pressure</span>
            </label>
            <label class="radio-label">
              <input type="radio" bind:group={returnCondition} value="broken" />
              <span>🔴 Broken / Needs repair</span>
            </label>
          </div>
        </div>

        <div class="notes-field">
          <label for="return-notes">Notes for Stand Manager (optional):</label>
          <input
            id="return-notes"
            type="text"
            placeholder="e.g. Front brake loose, parked in slot 3"
            bind:value={returnNotes}
          />
        </div>

        <button
          class="btn-return"
          onclick={handleReturnCycle}
          disabled={processingReturn}
        >
          {processingReturn ? "Returning..." : "Confirm Return & Lock Bike"}
        </button>
      </div>
    </div>
  {:else}
    <!-- Available Cycles & Checkout Screen -->
    <div class="rider-main-grid">
      <!-- Stand Info Banner -->
      <div class="stand-info-bar card">
        <div class="stand-info-left">
          <span class="stand-icon">🏡</span>
          <div>
            <h3>{homeStand.name}</h3>
            <p class="location-crumbs">{homeStand.place_name}, {homeStand.city_name} • Capacity: {homeStand.capacity} slots</p>
          </div>
        </div>
        <button class="btn-text-sm" onclick={() => { homeStand = null; loadPrivateStands(); }}>
          Change Home Stand
        </button>
      </div>

      <!-- Manual / QR Code Input Card -->
      <div class="card checkout-quick-card">
        <h3>📱 Check Out via Cycle ID or QR Code</h3>
        <p class="card-desc">Scan a cycle's sticker or enter its ID (e.g. <code>JC-101</code>) to unlock it.</p>
        <div class="checkout-input-row">
          <input
            type="text"
            placeholder="Enter Cycle ID or QR UUID..."
            bind:value={manualInput}
            onkeydown={(e) => e.key === "Enter" && handleManualCheckout()}
            disabled={processingCheckout}
          />
          <button
            class="btn-primary"
            onclick={handleManualCheckout}
            disabled={processingCheckout || !manualInput.trim()}
          >
            {processingCheckout ? "Verifying..." : "Check Out"}
          </button>
        </div>
      </div>

      <!-- Working Cycles Available at Home Stand -->
      <div class="card inventory-card">
        <div class="card-header">
          <div>
            <h3>Available Cycles at {homeStand.name}</h3>
            <p class="card-desc">Only verified working cycles (not broken, punctured, or in use) are listed.</p>
          </div>
          <span class="count-pill">{availableCycles.length} Available</span>
        </div>

        {#if availableCycles.length === 0}
          <div class="empty-state">
            <span class="empty-icon">🚲</span>
            <p>No cycles currently available at this stand.</p>
            <span class="empty-sub">All cycles might be currently checked out or undergoing maintenance.</span>
          </div>
        {:else}
          <div class="cycles-table-wrapper">
            <table class="cycles-table">
              <thead>
                <tr>
                  <th>Cycle ID</th>
                  <th>Brand &amp; Model</th>
                  <th>Color</th>
                  <th>Status</th>
                  <th style="text-align: right;">Action</th>
                </tr>
              </thead>
              <tbody>
                {#each availableCycles as cycle}
                  <tr>
                    <td>
                      <span class="cycle-pill">{cycle.cycle_number}</span>
                    </td>
                    <td>
                      <strong>{cycle.company_name}</strong>
                      <span class="table-sub">{cycle.model_number}</span>
                    </td>
                    <td>{cycle.color}</td>
                    <td>
                      <span class="status-badge status-running">Ready</span>
                    </td>
                    <td style="text-align: right;">
                      <button
                        class="btn-checkout-sm"
                        onclick={() => handleCheckout(cycle.id)}
                        disabled={processingCheckout}
                      >
                        Check Out ➔
                      </button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .rider-dashboard {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    width: 100%;
  }

  /* Alerts */
  .alert {
    padding: 0.9rem 1.2rem;
    border-radius: 8px;
    font-size: 0.95rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border: 1px solid transparent;
  }
  .alert-error {
    background-color: rgba(239, 68, 68, 0.15);
    border-color: #ef4444;
    color: #fca5a5;
  }
  .alert-success {
    background-color: rgba(34, 197, 94, 0.15);
    border-color: #22c55e;
    color: #86efac;
  }
  .btn-dismiss {
    background: none;
    border: none;
    color: inherit;
    font-size: 1.1rem;
    cursor: pointer;
  }

  /* Cards */
  .card {
    background-color: #1e293b;
    border: 1px solid #334155;
    border-radius: 12px;
    padding: 1.5rem;
  }
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 1rem;
  }
  .card-header h3, .card h2 {
    margin: 0 0 0.35rem 0;
    color: #f8fafc;
  }
  .subtitle, .card-desc {
    margin: 0;
    color: #94a3b8;
    font-size: 0.9rem;
  }
  .loading-card {
    text-align: center;
    padding: 3rem;
    color: #94a3b8;
  }
  .spinner {
    width: 32px;
    height: 32px;
    border: 3px solid #334155;
    border-top-color: #3b82f6;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin: 0 auto 1rem auto;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  /* Setup Card */
  .setup-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    margin-top: 1.25rem;
    max-width: 500px;
  }
  .setup-form select {
    background-color: #0f172a;
    border: 1px solid #475569;
    color: #f8fafc;
    padding: 0.65rem 0.9rem;
    border-radius: 6px;
    font-size: 0.95rem;
  }

  /* Stand Info Bar */
  .stand-info-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
  }
  .stand-info-left {
    display: flex;
    align-items: center;
    gap: 1rem;
  }
  .stand-icon {
    font-size: 2rem;
  }
  .stand-info-left h3 {
    margin: 0;
    font-size: 1.15rem;
    color: #f8fafc;
  }
  .location-crumbs {
    margin: 0.2rem 0 0 0;
    font-size: 0.85rem;
    color: #94a3b8;
  }
  .btn-text-sm {
    background: none;
    border: none;
    color: #60a5fa;
    font-size: 0.85rem;
    cursor: pointer;
    text-decoration: underline;
  }

  /* Quick checkout bar */
  .checkout-input-row {
    display: flex;
    gap: 0.75rem;
    margin-top: 1rem;
  }
  .checkout-input-row input {
    flex: 1;
    background-color: #0f172a;
    border: 1px solid #475569;
    color: #f8fafc;
    padding: 0.65rem 1rem;
    border-radius: 6px;
    font-size: 1rem;
  }
  .checkout-input-row input:focus {
    outline: none;
    border-color: #3b82f6;
  }

  /* Inventory Table */
  .count-pill {
    background-color: rgba(34, 197, 94, 0.2);
    color: #86efac;
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.8rem;
    font-weight: 600;
  }
  .cycles-table-wrapper {
    overflow-x: auto;
    margin-top: 0.5rem;
  }
  .cycles-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.95rem;
  }
  .cycles-table th {
    text-align: left;
    padding: 0.75rem 1rem;
    color: #94a3b8;
    border-bottom: 1px solid #334155;
    font-weight: 600;
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .cycles-table td {
    padding: 0.85rem 1rem;
    border-bottom: 1px solid #1e293b;
    color: #cbd5e1;
  }
  .cycles-table tr:hover td {
    background-color: rgba(255, 255, 255, 0.02);
  }
  .cycle-pill {
    font-family: monospace;
    font-weight: 700;
    background-color: #0f172a;
    color: #38bdf8;
    padding: 0.25rem 0.6rem;
    border-radius: 4px;
    border: 1px solid #334155;
  }
  .table-sub {
    display: block;
    font-size: 0.8rem;
    color: #94a3b8;
  }
  .status-badge {
    display: inline-block;
    padding: 0.2rem 0.55rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
  }
  .status-running {
    background-color: rgba(34, 197, 94, 0.15);
    color: #86efac;
    border: 1px solid rgba(34, 197, 94, 0.3);
  }

  .btn-primary {
    background-color: #2563eb;
    color: #ffffff;
    border: none;
    padding: 0.65rem 1.25rem;
    border-radius: 6px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }
  .btn-primary:hover:not(:disabled) {
    background-color: #1d4ed8;
  }
  .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .btn-checkout-sm {
    background-color: #059669;
    color: #ffffff;
    border: none;
    padding: 0.45rem 0.9rem;
    border-radius: 6px;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }
  .btn-checkout-sm:hover:not(:disabled) {
    background-color: #047857;
  }
  .btn-checkout-sm:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .empty-state {
    text-align: center;
    padding: 3rem 1rem;
    color: #94a3b8;
  }
  .empty-icon {
    font-size: 2.5rem;
    display: block;
    margin-bottom: 0.5rem;
  }
  .empty-sub {
    font-size: 0.85rem;
    color: #64748b;
  }

  /* Active Checkout Card */
  .active-checkout-card {
    border-color: #3b82f6;
    background: linear-gradient(180deg, #1e293b 0%, #0f172a 100%);
    box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);
  }
  .checkout-status-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.25rem;
  }
  .badge-active-checkout {
    background-color: #2563eb;
    color: #ffffff;
    padding: 0.35rem 0.85rem;
    border-radius: 9999px;
    font-size: 0.85rem;
    font-weight: 700;
    letter-spacing: 0.03em;
  }
  .checkout-time {
    color: #94a3b8;
    font-size: 0.9rem;
  }
  .cycle-summary h2 {
    font-size: 1.8rem;
    margin: 0 0 0.25rem 0;
    color: #38bdf8;
  }
  .specs {
    margin: 0 0 0.5rem 0;
    font-size: 1rem;
    color: #cbd5e1;
  }
  .color-text {
    font-weight: 600;
  }
  .home-tag {
    font-size: 0.85rem;
    color: #94a3b8;
    margin: 0;
  }

  /* Lock Box */
  .lock-box {
    margin: 1.5rem 0;
    padding: 1.5rem;
    background-color: #0b1329;
    border: 2px dashed #f59e0b;
    border-radius: 12px;
    text-align: center;
  }
  .lock-title {
    display: block;
    font-size: 0.95rem;
    color: #f59e0b;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .lock-digits {
    font-family: monospace;
    font-size: 3.5rem;
    font-weight: 900;
    letter-spacing: 0.25em;
    color: #fbbf24;
    margin: 0.5rem 0;
    text-shadow: 0 0 20px rgba(245, 158, 11, 0.4);
  }
  .lock-instruction {
    margin: 0;
    font-size: 0.9rem;
    color: #cbd5e1;
    line-height: 1.4;
  }

  /* Return Section */
  .return-section {
    border-top: 1px solid #334155;
    padding-top: 1.5rem;
    margin-top: 1.5rem;
  }
  .return-section h3 {
    margin: 0 0 0.35rem 0;
    color: #f8fafc;
  }
  .return-desc {
    font-size: 0.9rem;
    color: #94a3b8;
    margin: 0 0 1.25rem 0;
  }
  .section-label {
    display: block;
    font-size: 0.9rem;
    color: #cbd5e1;
    margin-bottom: 0.5rem;
    font-weight: 600;
  }
  .radio-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-bottom: 1rem;
  }
  .radio-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    color: #e2e8f0;
    cursor: pointer;
  }
  .notes-field {
    margin-bottom: 1.25rem;
  }
  .notes-field label {
    display: block;
    font-size: 0.85rem;
    color: #cbd5e1;
    margin-bottom: 0.35rem;
  }
  .notes-field input {
    width: 100%;
    background-color: #0f172a;
    border: 1px solid #475569;
    color: #f8fafc;
    padding: 0.65rem 0.9rem;
    border-radius: 6px;
    font-size: 0.95rem;
    box-sizing: border-box;
  }
  .btn-return {
    width: 100%;
    background-color: #dc2626;
    color: #ffffff;
    border: none;
    padding: 0.85rem 1.5rem;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 700;
    cursor: pointer;
    transition: background 0.15s;
  }
  .btn-return:hover:not(:disabled) {
    background-color: #b91c1c;
  }
  .btn-return:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
