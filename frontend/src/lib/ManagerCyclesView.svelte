<script lang="ts">
  import QRCode from "qrcode";
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

  interface ActiveCheckout {
    id: string;
    checked_out_at: string;
    rider_name: string;
    rider_email: string;
    rider_phone?: string;
  }

  interface Cycle {
    id: string;
    parking_id: string;
    cycle_number: string;
    qr_id: string;
    lock_code: string;
    company_name: string;
    color: string;
    model_number: string;
    status: "running" | "broken" | "puncture" | "maintenance";
    created_at?: string;
    active_checkout?: ActiveCheckout | null;
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
  let newLockCode = $state("");
  let newStatus = $state<"running" | "broken" | "puncture" | "maintenance">("running");

  // Printable QR modal state
  let selectedCycleForQr = $state<Cycle | null>(null);
  let qrImageUrl = $state<string>("");
  let scanUrl = $state<string>("");

  function formatCheckoutTime(iso: string): string {
    if (!iso) return "—";
    try {
      const d = new Date(iso);
      const now = new Date();
      const diffMs = now.getTime() - d.getTime();
      const diffMins = Math.max(0, Math.floor(diffMs / 60000));
      const timeStr = d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
      if (diffMins < 60) {
        return `${timeStr} (${diffMins}m ago)`;
      }
      const diffHours = Math.floor(diffMins / 60);
      const remMins = diffMins % 60;
      return `${timeStr} (${diffHours}h ${remMins}m ago)`;
    } catch {
      return iso;
    }
  }

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
      // 1. Fetch cycles for this stand
      const { data: cyclesData, error: cycErr } = await supabase
        .from("cycles")
        .select("*")
        .eq("parking_id", standId)
        .order("cycle_number");

      if (cycErr) throw cycErr;

      const cycleList: any[] = cyclesData || [];
      const cycleIds = cycleList.map((c) => c.id);
      const checkoutMap = new Map<string, ActiveCheckout>();

      // 2. Fetch active checkouts for cycles at this stand
      if (cycleIds.length > 0) {
        const { data: checkoutsData, error: chkErr } = await supabase
          .from("checkouts")
          .select("id, cycle_id, rider_id, checked_out_at, status")
          .in("cycle_id", cycleIds)
          .eq("status", "active");

        if (!chkErr && checkoutsData && checkoutsData.length > 0) {
          const riderIds = Array.from(new Set(checkoutsData.map((chk: any) => chk.rider_id)));
          const { data: profilesData } = await supabase
            .from("profiles")
            .select("id, full_name, email, phone_number")
            .in("id", riderIds);

          const profileMap = new Map((profilesData || []).map((p: any) => [p.id, p]));

          for (const chk of checkoutsData) {
            const profile = profileMap.get(chk.rider_id);
            checkoutMap.set(chk.cycle_id, {
              id: chk.id,
              checked_out_at: chk.checked_out_at,
              rider_name: profile?.full_name || profile?.email || "Unknown Rider",
              rider_email: profile?.email || "",
              rider_phone: profile?.phone_number || "",
            });
          }
        }
      }

      cycles = cycleList.map((c) => ({
        ...c,
        active_checkout: checkoutMap.get(c.id) || null,
      }));
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
      const payload: any = {
        parking_id: selectedStandId,
        cycle_number: newCycleNumber.trim().toUpperCase(),
        company_name: newCompany.trim(),
        color: newColor.trim(),
        model_number: newModel.trim(),
        status: newStatus,
      };
      if (newLockCode.trim()) {
        payload.lock_code = newLockCode.trim();
      }

      const { error } = await supabase.from("cycles").insert(payload);

      if (error) throw error;
      successMsg = `Added cycle ${newCycleNumber.trim().toUpperCase()} to this stand!`;
      newCycleNumber = "";
      newCompany = "";
      newColor = "";
      newModel = "";
      newLockCode = "";
      newStatus = "running";
      showAddForm = false;
      await loadCycles(selectedStandId);
    } catch (e: any) {
      errorMsg = e.message || String(e);
    }
  }

  function getScanUrl(qrId: string): string {
    const origin = window.location.origin;
    const pathname = window.location.pathname.replace(/\/+$/, "").replace(/\/(?:app|debug|users)$/, "");
    return `${origin}${pathname}/scan/${qrId}`;
  }

  async function openQrPopup(cycle: Cycle) {
    selectedCycleForQr = cycle;
    scanUrl = getScanUrl(cycle.qr_id);
    try {
      qrImageUrl = await QRCode.toDataURL(scanUrl, {
        width: 250,
        margin: 1,
        color: {
          dark: "#0f172a",
          light: "#ffffff",
        },
      });
    } catch (err: any) {
      console.error("Failed to generate QR code", err);
    }
  }

  function closeQrPopup() {
    selectedCycleForQr = null;
    qrImageUrl = "";
    scanUrl = "";
  }

  function printSticker() {
    window.print();
  }

  function getStandName(parkingId: string): string {
    const stand = managedStands.find((s) => s.id === parkingId);
    return stand ? `${stand.name} (${stand.place_name || ""})` : "";
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
        <input type="text" placeholder="Lock Code (e.g. 4821 - default 1234)" bind:value={newLockCode} />
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
      <span class="stat-val">{cycles.filter((c) => c.status === "running" && !c.active_checkout).length}</span>
      <span class="stat-lbl">Available at Stand</span>
    </div>
    <div class="stat-pill stat-checked-out">
      <span class="stat-val">{cycles.filter((c) => Boolean(c.active_checkout)).length}</span>
      <span class="stat-lbl">Checked Out</span>
    </div>
    <div class="stat-pill stat-puncture">
      <span class="stat-val">{cycles.filter((c) => c.status === "puncture").length}</span>
      <span class="stat-lbl">Puncture</span>
    </div>
    <div class="stat-pill stat-broken">
      <span class="stat-val">{cycles.filter((c) => c.status === "broken" || c.status === "maintenance").length}</span>
      <span class="stat-lbl">Broken / Maint</span>
    </div>
    <div class="stat-pill stat-total">
      <span class="stat-val">{cycles.length}</span>
      <span class="stat-lbl">Total at Stand</span>
    </div>
  </div>

  <!-- Cycles Table -->
  <div class="card table-card">
    <div class="table-header">
      <h3>Cycles Assigned to Stand ({cycles.length})</h3>
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
              <th>Lock Code</th>
              <th>Status</th>
              <th>Custody / Checked Out By</th>
              <th>QR Sticker</th>
              <th>Quick Status Update</th>
            </tr>
          </thead>
          <tbody>
            {#each cycles as cy}
              <tr
                class:row-warning={cy.status === "broken" || cy.status === "puncture"}
                class:row-checked-out={Boolean(cy.active_checkout)}
              >
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
                  <span class="lock-code-badge">🔒 {cy.lock_code || "1234"}</span>
                </td>
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
                <td class="col-custody">
                  {#if cy.active_checkout}
                    <div class="checkout-rider-box">
                      <span class="badge-checked-out">⚡ Checked Out</span>
                      <strong class="rider-name">{cy.active_checkout.rider_name}</strong>
                      <span class="rider-meta">
                        {cy.active_checkout.rider_email}{cy.active_checkout.rider_phone ? ` • ${cy.active_checkout.rider_phone}` : ''}
                      </span>
                      <span class="rider-time">🕐 {formatCheckoutTime(cy.active_checkout.checked_out_at)}</span>
                    </div>
                  {:else if cy.status === "running"}
                    <span class="badge-available-stand">🟢 Available at Stand</span>
                  {:else}
                    <span class="text-in-rack">In Rack (Unavailable)</span>
                  {/if}
                </td>
                <td>
                  <button class="btn-qr-action" onclick={() => openQrPopup(cy)} title="View printable QR Sticker">
                    🏷️ QR Code
                  </button>
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

  <!-- Printable QR Popup Modal -->
  {#if selectedCycleForQr}
    <div
      class="modal-backdrop"
      onclick={closeQrPopup}
      onkeydown={(e) => e.key === "Escape" && closeQrPopup()}
      role="button"
      tabindex="0"
    >
      <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
      <div
        class="modal-content-container"
        onclick={(e) => e.stopPropagation()}
        onkeydown={(e) => e.stopPropagation()}
        role="document"
        tabindex="-1"
      >
        <!-- Printable Sticker Element -->
        <div class="sticker-card">
          <div class="sticker-header">
            <div class="sticker-brand">🚴 JUNTA CYCLE</div>
            <div class="sticker-tag">{selectedCycleForQr.cycle_number}</div>
          </div>

          <div class="sticker-qr-box">
            {#if qrImageUrl}
              <img src={qrImageUrl} alt={`QR Code for ${selectedCycleForQr.cycle_number}`} class="sticker-qr-img" />
            {:else}
              <div class="qr-loading">Generating QR...</div>
            {/if}
          </div>

          <div class="sticker-uuid-box">
            <span class="uuid-lbl">Scan URL:</span>
            <span class="uuid-txt">{scanUrl}</span>
          </div>

          <div class="sticker-info-rows">
            <div class="sticker-info-row">
              <span class="info-k">Cycle:</span>
              <span class="info-v">{selectedCycleForQr.company_name} - {selectedCycleForQr.model_number} ({selectedCycleForQr.color})</span>
            </div>
            {#if getStandName(selectedCycleForQr.parking_id)}
              <div class="sticker-info-row">
                <span class="info-k">Home Stand:</span>
                <span class="info-v">{getStandName(selectedCycleForQr.parking_id)}</span>
              </div>
            {/if}
          </div>

          <div class="sticker-footer-note">
            Scan QR code with your phone camera or Junta Cycle App to unlock ride
          </div>
        </div>

        <!-- Non-printed modal controls -->
        <div class="modal-actions no-print">
          <button class="btn-print" onclick={printSticker}>
            🖨️ Print QR Sticker
          </button>
          <button class="btn-close-modal" onclick={closeQrPopup}>
            Close
          </button>
        </div>
      </div>
    </div>
  {/if}
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
  .stat-checked-out .stat-val { color: #2563eb; }
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

  .row-checked-out {
    background-color: #f0f7ff;
  }

  .col-custody {
    min-width: 200px;
  }

  .checkout-rider-box {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }

  .badge-checked-out {
    display: inline-block;
    align-self: flex-start;
    background-color: rgba(37, 99, 235, 0.12);
    color: #2563eb;
    border: 1px solid rgba(37, 99, 235, 0.3);
    padding: 0.15rem 0.5rem;
    border-radius: 9999px;
    font-size: 0.725rem;
    font-weight: 700;
  }

  .rider-name {
    font-size: 0.875rem;
    color: var(--text-main);
  }

  .rider-meta {
    font-size: 0.75rem;
    color: var(--text-muted);
  }

  .rider-time {
    font-size: 0.75rem;
    color: #2563eb;
    font-weight: 600;
  }

  .badge-available-stand {
    color: #16a34a;
    font-size: 0.85rem;
    font-weight: 600;
  }

  .text-in-rack {
    color: var(--text-muted);
    font-size: 0.8rem;
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

  .lock-code-badge {
    display: inline-flex;
    align-items: center;
    background: #f1f5f9;
    border: 1px solid #cbd5e1;
    color: #334155;
    font-weight: 700;
    font-family: monospace;
    font-size: 0.85rem;
    padding: 0.2rem 0.5rem;
    border-radius: 0.25rem;
    letter-spacing: 0.05em;
  }

  .btn-qr-action {
    background: #0f172a;
    color: white;
    border: none;
    padding: 0.35rem 0.7rem;
    border-radius: 0.375rem;
    font-size: 0.8rem;
    font-weight: 600;
    cursor: pointer;
    transition: background-color 0.15s;
    white-space: nowrap;
  }

  .btn-qr-action:hover {
    background: #334155;
  }

  /* Modal Backdrop */
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(15, 23, 42, 0.65);
    backdrop-filter: blur(2px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 9999;
    padding: 1rem;
  }

  .modal-content-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    max-width: 380px;
    width: 100%;
  }

  /* Sticker Card Layout */
  .sticker-card {
    background: #ffffff;
    color: #0f172a;
    width: 100%;
    max-width: 360px;
    border: 2px dashed #94a3b8;
    border-radius: 0.75rem;
    padding: 1.25rem;
    box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.2);
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    box-sizing: border-box;
  }

  .sticker-header {
    width: 100%;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 2px solid #0f172a;
    padding-bottom: 0.5rem;
    margin-bottom: 0.85rem;
  }

  .sticker-brand {
    font-weight: 900;
    font-size: 0.95rem;
    letter-spacing: 0.05em;
    color: #0f172a;
  }

  .sticker-tag {
    font-family: monospace;
    font-weight: 900;
    font-size: 1.15rem;
    background: #0f172a;
    color: #ffffff;
    padding: 0.15rem 0.55rem;
    border-radius: 0.25rem;
  }

  .sticker-qr-box {
    background: #ffffff;
    padding: 0.5rem;
    border: 1px solid #e2e8f0;
    border-radius: 0.5rem;
    display: flex;
    justify-content: center;
    align-items: center;
    margin-bottom: 0.75rem;
  }

  .sticker-qr-img {
    width: 180px;
    height: 180px;
    display: block;
    image-rendering: pixelated;
  }

  .qr-loading {
    width: 180px;
    height: 180px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.85rem;
    color: #64748b;
  }

  .sticker-uuid-box {
    width: 100%;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 0.35rem;
    padding: 0.35rem 0.5rem;
    margin-bottom: 0.75rem;
    font-family: monospace;
    font-size: 0.7rem;
    word-break: break-all;
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
  }

  .uuid-lbl {
    font-weight: 700;
    color: #64748b;
    font-size: 0.65rem;
    text-transform: uppercase;
  }

  .uuid-txt {
    color: #0f172a;
    font-weight: 600;
  }

  .sticker-info-rows {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    font-size: 0.825rem;
    text-align: left;
    margin-bottom: 0.75rem;
  }

  .sticker-info-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px dotted #e2e8f0;
    padding-bottom: 0.25rem;
  }

  .info-k {
    color: #64748b;
    font-weight: 600;
  }

  .info-v {
    font-weight: 700;
    color: #0f172a;
    text-align: right;
  }

  .sticker-footer-note {
    font-size: 0.7rem;
    color: #64748b;
    font-weight: 600;
    border-top: 1px solid #e2e8f0;
    padding-top: 0.5rem;
    width: 100%;
  }

  .modal-actions {
    display: flex;
    gap: 0.75rem;
    width: 100%;
    justify-content: center;
  }

  .btn-print {
    background: #0d9488;
    color: white;
    border: none;
    padding: 0.6rem 1.25rem;
    border-radius: 0.375rem;
    font-weight: 700;
    font-size: 0.95rem;
    cursor: pointer;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    transition: background 0.15s;
  }

  .btn-print:hover {
    background: #0f766e;
  }

  .btn-close-modal {
    background: #ffffff;
    color: #334155;
    border: 1px solid #cbd5e1;
    padding: 0.6rem 1rem;
    border-radius: 0.375rem;
    font-weight: 600;
    font-size: 0.95rem;
    cursor: pointer;
  }

  .btn-close-modal:hover {
    background: #f1f5f9;
  }

  /* Print Media Query */
  @media print {
    :global(body) {
      background: white !important;
      color: black !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    :global(body *) {
      visibility: hidden !important;
    }

    .modal-backdrop,
    .modal-backdrop * {
      visibility: visible !important;
    }

    .modal-backdrop {
      position: absolute !important;
      top: 0 !important;
      left: 0 !important;
      width: 100% !important;
      height: auto !important;
      background: none !important;
      backdrop-filter: none !important;
      padding: 0.5cm !important;
      display: block !important;
      z-index: 10000 !important;
    }

    .modal-content-container {
      margin: 0 auto !important;
      max-width: 100% !important;
      width: auto !important;
    }

    .sticker-card {
      border: 2px dashed #000000 !important;
      box-shadow: none !important;
      max-width: 340px !important;
      margin: 0 auto !important;
      page-break-inside: avoid;
    }

    .no-print {
      display: none !important;
      visibility: hidden !important;
    }
  }
</style>
