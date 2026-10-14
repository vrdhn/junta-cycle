<script lang="ts">
  import { onMount } from "svelte";
  import { supabase } from "./supabase";

  interface Props {
    userId: string;
  }

  let { userId }: Props = $props();

  interface ParkingStand {
    id: string;
    name: string;
    place_id: string;
    capacity: number;
    place_name?: string;
    city_name?: string;
  }

  interface Cycle {
    id: string;
    parking_id: string;
    cycle_number: string;
    company_name: string;
    color: string;
    model_number: string;
    status: "running" | "broken" | "puncture" | "maintenance";
    created_at?: string;
  }

  let managedStands = $state<ParkingStand[]>([]);
  let selectedStandId = $state<string>("");
  let cycles = $state<Cycle[]>([]);
  let loading = $state(true);
  let errorMsg = $state<string | null>(null);
  let successMsg = $state<string | null>(null);

  // Add cycle form state
  let showAddForm = $state(false);
  let newCycleNumber = $state("");
  let newCompany = $state("");
  let newColor = $state("");
  let newModel = $state("");
  let newStatus = $state<"running" | "broken" | "puncture" | "maintenance">("running");

  async function loadStands() {
    loading = true;
    errorMsg = null;
    try {
      // 1. Fetch private stands assigned to this manager, or all private stands if not assigned
      let query = supabase
        .from("parkings")
        .select("id, name, place_id, capacity, manager_id, parking_type")
        .eq("parking_type", "private");

      const { data: allStands, error: standErr } = await query;
      if (standErr) throw standErr;

      // Filter by manager_id, fallback to all private stands if none directly matched
      const userStands = (allStands || []).filter((s) => s.manager_id === userId);
      const standsToUse = userStands.length > 0 ? userStands : (allStands || []);

      // Fetch place & city names
      const { data: placesData } = await supabase.from("places").select("id, name, city_id");
      const { data: citiesData } = await supabase.from("cities").select("id, name");

      const placeMap = new Map((placesData || []).map((p) => [p.id, p]));
      const cityMap = new Map((citiesData || []).map((c) => [c.id, c.name]));

      managedStands = standsToUse.map((s) => {
        let pName = "—";
        let cName = "—";
        if (placeMap.has(s.place_id)) {
          const pl = placeMap.get(s.place_id)!;
          pName = pl.name;
          cName = cityMap.get(pl.city_id) || "—";
        }
        return {
          id: s.id,
          name: s.name,
          place_id: s.place_id,
          capacity: s.capacity,
          place_name: pName,
          city_name: cName,
        };
      });

      if (managedStands.length > 0 && !selectedStandId) {
        selectedStandId = managedStands[0].id;
        await loadCycles(selectedStandId);
      }
    } catch (e: any) {
      errorMsg = `Failed to load manager parking stands: ${e.message || e}`;
    } finally {
      loading = false;
    }
  }

  async function loadCycles(standId: string) {
    if (!standId) return;
    try {
      const { data, error } = await supabase
        .from("cycles")
        .select("*")
        .eq("parking_id", standId)
        .order("cycle_number");

      if (error) throw error;
      cycles = data || [];
    } catch (e: any) {
      errorMsg = `Failed to load cycles: ${e.message || e}`;
    }
  }

  async function handleStandChange(e: Event) {
    const target = e.target as HTMLSelectElement;
    selectedStandId = target.value;
    await loadCycles(selectedStandId);
  }

  async function updateCycleStatus(cycleId: string, status: "running" | "broken" | "puncture" | "maintenance") {
    errorMsg = null;
    successMsg = null;
    try {
      const { error } = await supabase
        .from("cycles")
        .update({ status })
        .eq("id", cycleId);

      if (error) throw error;
      successMsg = `Updated cycle status to ${status}`;
      await loadCycles(selectedStandId);
    } catch (e: any) {
      errorMsg = `Failed to update status: ${e.message || e}`;
    }
  }

  async function addCycle() {
    if (!newCycleNumber.trim() || !newCompany.trim() || !newColor.trim() || !newModel.trim()) {
      errorMsg = "Please fill in all cycle details.";
      return;
    }
    errorMsg = null;
    successMsg = null;
    try {
      const { error } = await supabase.from("cycles").insert({
        parking_id: selectedStandId,
        cycle_number: newCycleNumber.trim().toUpperCase(),
        company_name: newCompany.trim(),
        color: newColor.trim(),
        model_number: newModel.trim(),
        status: newStatus,
      });

      if (error) throw error;
      successMsg = `Added cycle ${newCycleNumber.trim().toUpperCase()} to this stand!`;
      newCycleNumber = "";
      newCompany = "";
      newColor = "";
      newModel = "";
      newStatus = "running";
      showAddForm = false;
      await loadCycles(selectedStandId);
    } catch (e: any) {
      errorMsg = e.message || String(e);
    }
  }

  onMount(() => {
    loadStands();
  });
</script>

<div class="manager-cycles-view">
  <div class="manager-top-card">
    <div class="header-info">
      <h2>🛠️ Private Stand Cycle Inventory</h2>
      <p class="subtitle">Real-time status of bicycles assigned to your private parking stand.</p>
    </div>

    {#if managedStands.length > 0}
      <div class="stand-selector-box">
        <label for="stand-select">Active Parking Stand:</label>
        <select id="stand-select" value={selectedStandId} onchange={handleStandChange}>
          {#each managedStands as st}
            <option value={st.id}>
              {st.name} ({st.place_name}, {st.city_name}) - Cap: {st.capacity}
            </option>
          {/each}
        </select>
        <button class="btn-toggle-add" onclick={() => (showAddForm = !showAddForm)}>
          {showAddForm ? "✕ Close Form" : "+ Add Cycle to Stand"}
        </button>
      </div>
    {/if}
  </div>

  {#if successMsg}
    <div class="alert alert-success">{successMsg}</div>
  {/if}
  {#if errorMsg}
    <div class="alert alert-error">{errorMsg}</div>
  {/if}

  {#if showAddForm}
    <div class="card add-cycle-card">
      <h3>Register New Cycle to Stand</h3>
      <div class="form-grid">
        <input type="text" placeholder="Cycle ID / Tag (e.g. JC-106)" bind:value={newCycleNumber} />
        <input type="text" placeholder="Company (e.g. Hero, Trek, Btwin)" bind:value={newCompany} />
        <input type="text" placeholder="Color (e.g. Matte Black, Red)" bind:value={newColor} />
        <input type="text" placeholder="Model (e.g. Sprint Pro, ST30)" bind:value={newModel} />
        <select bind:value={newStatus}>
          <option value="running">Status: Running (Available)</option>
          <option value="puncture">Status: Puncture</option>
          <option value="broken">Status: Broken</option>
          <option value="maintenance">Status: Maintenance</option>
        </select>
        <div class="form-actions">
          <button class="btn-primary" onclick={addCycle}>Save Cycle</button>
          <button class="btn-cancel" onclick={() => (showAddForm = false)}>Cancel</button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Stats Overview Bar -->
  <div class="stats-row">
    <div class="stat-pill stat-running">
      <span class="stat-val">{cycles.filter((c) => c.status === "running").length}</span>
      <span class="stat-lbl">Running / Available</span>
    </div>
    <div class="stat-pill stat-puncture">
      <span class="stat-val">{cycles.filter((c) => c.status === "puncture").length}</span>
      <span class="stat-lbl">Puncture</span>
    </div>
    <div class="stat-pill stat-broken">
      <span class="stat-val">{cycles.filter((c) => c.status === "broken").length}</span>
      <span class="stat-lbl">Broken</span>
    </div>
    <div class="stat-pill stat-total">
      <span class="stat-val">{cycles.length}</span>
      <span class="stat-lbl">Total at Stand</span>
    </div>
  </div>

  <!-- Cycles Table -->
  <div class="card table-card">
    <div class="table-header">
      <h3>Available Cycles at Stand ({cycles.length})</h3>
      <button class="btn-refresh" onclick={() => loadCycles(selectedStandId)} title="Refresh list">↻ Refresh</button>
    </div>

    {#if loading}
      <div class="table-empty">Loading cycles...</div>
    {:else if cycles.length === 0}
      <div class="table-empty">No cycles registered at this parking stand. Click "+ Add Cycle to Stand" to register one.</div>
    {:else}
      <div class="table-responsive">
        <table class="cycles-table">
          <thead>
            <tr>
              <th>Cycle ID</th>
              <th>Company</th>
              <th>Color</th>
              <th>Model Number</th>
              <th>Status</th>
              <th>Quick Status Update</th>
            </tr>
          </thead>
          <tbody>
            {#each cycles as cy}
              <tr class:row-warning={cy.status === "broken" || cy.status === "puncture"}>
                <td class="col-num">
                  <span class="cycle-tag">🚲 {cy.cycle_number}</span>
                </td>
                <td class="col-company"><strong>{cy.company_name}</strong></td>
                <td>
                  <span class="color-badge">
                    <span class="color-dot" style={`background-color: ${getColorHex(cy.color)}`}></span>
                    {cy.color}
                  </span>
                </td>
                <td class="col-model">{cy.model_number}</td>
                <td>
                  <span class={`badge-status status-${cy.status}`}>
                    {#if cy.status === "running"}
                      🟢 Running
                    {:else if cy.status === "puncture"}
                      🟡 Puncture
                    {:else if cy.status === "broken"}
                      🔴 Broken
                    {:else}
                      🟠 Maintenance
                    {/if}
                  </span>
                </td>
                <td class="col-actions">
                  <select
                    class="select-status-quick"
                    value={cy.status}
                    onchange={(e) => updateCycleStatus(cy.id, (e.target as HTMLSelectElement).value as any)}
                  >
                    <option value="running">Mark Running</option>
                    <option value="puncture">Report Puncture</option>
                    <option value="broken">Report Broken</option>
                    <option value="maintenance">Mark Maintenance</option>
                  </select>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>
</div>

<script lang="ts" module>
  function getColorHex(colorName: string): string {
    const c = colorName.toLowerCase();
    if (c.includes("black")) return "#1e293b";
    if (c.includes("blue")) return "#0284c7";
    if (c.includes("red")) return "#dc2626";
    if (c.includes("green")) return "#16a34a";
    if (c.includes("orange")) return "#ea580c";
    if (c.includes("yellow")) return "#eab308";
    if (c.includes("white")) return "#e2e8f0";
    if (c.includes("grey") || c.includes("gray") || c.includes("silver")) return "#64748b";
    return "#0d9488";
  }
</script>

<style>
  .manager-cycles-view {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .manager-top-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 0.75rem;
    padding: 1.25rem 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
  }

  .header-info h2 {
    font-size: 1.35rem;
    color: var(--text-main);
    margin-bottom: 0.25rem;
  }

  .subtitle {
    font-size: 0.9rem;
    color: var(--text-muted);
  }

  .stand-selector-box {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-wrap: wrap;
    background: #f8fafc;
    border: 1px solid var(--border-color);
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
  }

  .stand-selector-box label {
    font-size: 0.875rem;
    font-weight: 700;
    color: var(--text-main);
  }

  .stand-selector-box select {
    flex: 1;
    min-width: 240px;
    padding: 0.45rem 0.75rem;
    border: 1px solid var(--border-color);
    border-radius: 0.375rem;
    font-size: 0.9rem;
    background: white;
  }

  .btn-toggle-add {
    background: var(--primary-color);
    color: white;
    border: none;
    padding: 0.45rem 0.85rem;
    border-radius: 0.375rem;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.15s;
  }

  .btn-toggle-add:hover {
    background: var(--primary-hover);
  }

  .add-cycle-card {
    background: #f0fdfa;
    border: 2px dashed var(--primary-color);
  }

  .add-cycle-card h3 {
    margin-bottom: 0.75rem;
    font-size: 1.05rem;
    color: var(--primary-color);
  }

  .form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 0.65rem;
  }

  .form-grid input, .form-grid select {
    padding: 0.5rem 0.75rem;
    border: 1px solid var(--border-color);
    border-radius: 0.375rem;
    font-size: 0.9rem;
    background: white;
  }

  .form-actions {
    display: flex;
    gap: 0.5rem;
    grid-column: 1 / -1;
  }

  .btn-primary {
    background: var(--primary-color);
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    font-weight: 600;
    cursor: pointer;
  }

  .btn-cancel {
    background: #e2e8f0;
    color: #475569;
    border: none;
    padding: 0.5rem 0.85rem;
    border-radius: 0.375rem;
    font-weight: 600;
    cursor: pointer;
  }

  .stats-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 0.75rem;
  }

  .stat-pill {
    background: white;
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    padding: 0.85rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    box-shadow: 0 1px 2px rgba(0,0,0,0.03);
  }

  .stat-val {
    font-size: 1.6rem;
    font-weight: 800;
    line-height: 1.2;
  }

  .stat-lbl {
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--text-muted);
  }

  .stat-running .stat-val { color: #16a34a; }
  .stat-puncture .stat-val { color: #d97706; }
  .stat-broken .stat-val { color: #dc2626; }
  .stat-total .stat-val { color: var(--text-main); }

  .card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 0.75rem;
    padding: 1.25rem 1.5rem;
  }

  .table-card {
    padding: 0;
    overflow: hidden;
  }

  .table-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border-color);
    background: #f8fafc;
  }

  .table-header h3 {
    margin: 0;
    font-size: 1.05rem;
  }

  .btn-refresh {
    background: white;
    border: 1px solid var(--border-color);
    padding: 0.35rem 0.75rem;
    border-radius: 0.375rem;
    font-size: 0.85rem;
    cursor: pointer;
    font-weight: 500;
  }

  .table-responsive {
    overflow-x: auto;
  }

  .cycles-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9rem;
    text-align: left;
  }

  .cycles-table th, .cycles-table td {
    padding: 0.75rem 1rem;
    border-bottom: 1px solid var(--border-color);
  }

  .cycles-table th {
    background: #f8fafc;
    color: var(--text-muted);
    font-size: 0.75rem;
    text-transform: uppercase;
    font-weight: 700;
  }

  .row-warning {
    background-color: #fffbeb;
  }

  .cycle-tag {
    font-weight: 700;
    font-family: monospace;
    font-size: 0.95rem;
    color: var(--text-main);
  }

  .color-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.85rem;
    font-weight: 500;
  }

  .color-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    display: inline-block;
    border: 1px solid rgba(0, 0, 0, 0.15);
  }

  .badge-status {
    padding: 0.2rem 0.6rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 700;
  }

  .status-running {
    background: #dcfce7;
    color: #15803d;
  }

  .status-puncture {
    background: #fef3c7;
    color: #92400e;
  }

  .status-broken {
    background: #fee2e2;
    color: #991b1b;
  }

  .status-maintenance {
    background: #ffedd5;
    color: #9a3412;
  }

  .select-status-quick {
    padding: 0.25rem 0.5rem;
    font-size: 0.8rem;
    border: 1px solid var(--border-color);
    border-radius: 0.25rem;
    background: white;
    cursor: pointer;
  }

  .table-empty {
    padding: 2.5rem;
    text-align: center;
    color: var(--text-muted);
  }

  .alert {
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    font-size: 0.9rem;
  }

  .alert-success { background: #ecfdf5; color: #065f46; border: 1px solid #a7f3d0; }
  .alert-error { background: #fef2f2; color: #991b1b; border: 1px solid #fecaca; }
</style>
