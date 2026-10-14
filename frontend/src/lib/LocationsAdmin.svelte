<script lang="ts">
  import { onMount } from "svelte";
  import { supabase } from "./supabase";

  interface City {
    id: string;
    name: string;
  }

  interface Place {
    id: string;
    city_id: string;
    name: string;
    city_name?: string;
  }

  interface Manager {
    id: string;
    full_name: string | null;
    email: string;
  }

  interface Parking {
    id: string;
    place_id: string;
    name: string; // Stand name
    parking_type: "private" | "public";
    manager_id: string | null;
    capacity: number;
    place_name?: string;
    city_name?: string;
    manager_name?: string;
  }

  let cities = $state<City[]>([]);
  let places = $state<Place[]>([]);
  let parkings = $state<Parking[]>([]);
  let managers = $state<Manager[]>([]);

  let loading = $state(true);
  let errorMsg = $state<string | null>(null);
  let successMsg = $state<string | null>(null);

  // Form states
  let newCityName = $state("");
  let newPlaceCityId = $state("");
  let newPlaceName = $state("");

  let newParkingPlaceId = $state("");
  let newParkingName = $state("");
  let newParkingType = $state<"private" | "public">("private");
  let newParkingManagerId = $state("");
  let newParkingCapacity = $state(10);

  let activeModal = $state<"city" | "place" | "parking" | null>(null);

  async function loadData() {
    loading = true;
    errorMsg = null;
    try {
      const [citiesRes, placesRes, parkRes, profRes] = await Promise.all([
        supabase.from("cities").select("*").order("name"),
        supabase.from("places").select("*").order("name"),
        supabase.from("parkings").select("*").order("name"),
        supabase.from("profiles").select("id, full_name, email, roles"),
      ]);

      if (citiesRes.error) throw citiesRes.error;
      if (placesRes.error) throw placesRes.error;
      if (parkRes.error) throw parkRes.error;

      cities = citiesRes.data || [];
      const rawPlaces = placesRes.data || [];

      // Filter managers
      const allProfiles = profRes.data || [];
      managers = allProfiles
        .filter((p: any) => p.roles && p.roles.includes("manager"))
        .map((p: any) => ({
          id: p.id,
          full_name: p.full_name,
          email: p.email,
        }));

      const cityMap = new Map(cities.map((c) => [c.id, c.name]));
      const mgrMap = new Map(allProfiles.map((m: any) => [m.id, m.full_name || m.email]));

      places = rawPlaces.map((pl: any) => ({
        ...pl,
        city_name: cityMap.get(pl.city_id) || "—",
      }));

      const placeMap = new Map(places.map((pl) => [pl.id, pl]));

      parkings = (parkRes.data || []).map((p: any) => {
        let cityName = "—";
        let placeName = "—";

        if (placeMap.has(p.place_id)) {
          const pl = placeMap.get(p.place_id)!;
          placeName = pl.name;
          cityName = pl.city_name || "—";
        }

        return {
          ...p,
          place_name: placeName,
          city_name: cityName,
          manager_name: p.manager_id ? mgrMap.get(p.manager_id) || "Assigned" : "—",
        };
      });
    } catch (e: any) {
      errorMsg = `Failed to load locations: ${e.message || e}`;
    } finally {
      loading = false;
    }
  }

  async function addCity() {
    if (!newCityName.trim()) return;
    errorMsg = null;
    successMsg = null;
    try {
      const { error } = await supabase.from("cities").insert({ name: newCityName.trim() });
      if (error) throw error;
      successMsg = `Added City "${newCityName.trim()}"`;
      newCityName = "";
      activeModal = null;
      await loadData();
    } catch (e: any) {
      errorMsg = e.message || String(e);
    }
  }

  async function addPlace() {
    if (!newPlaceCityId || !newPlaceName.trim()) return;
    errorMsg = null;
    successMsg = null;
    try {
      const { error } = await supabase.from("places").insert({
        city_id: newPlaceCityId,
        name: newPlaceName.trim(),
      });
      if (error) throw error;
      successMsg = `Added Place "${newPlaceName.trim()}"`;
      newPlaceName = "";
      activeModal = null;
      await loadData();
    } catch (e: any) {
      errorMsg = e.message || String(e);
    }
  }

  async function addParking() {
    if (!newParkingPlaceId || !newParkingName.trim()) return;
    errorMsg = null;
    successMsg = null;
    try {
      const { error } = await supabase.from("parkings").insert({
        place_id: newParkingPlaceId,
        name: newParkingName.trim(),
        parking_type: newParkingType,
        manager_id: newParkingType === "private" && newParkingManagerId ? newParkingManagerId : null,
        capacity: Number(newParkingCapacity) || 10,
      });
      if (error) throw error;
      successMsg = `Added ${newParkingType} stand "${newParkingName.trim()}"`;
      newParkingName = "";
      newParkingManagerId = "";
      newParkingCapacity = 10;
      activeModal = null;
      await loadData();
    } catch (e: any) {
      errorMsg = e.message || String(e);
    }
  }

  onMount(() => {
    loadData();
  });
</script>

<div class="locations-admin">
  <div class="admin-top-bar">
    <div>
      <h3>📍 Parking Directory</h3>
      <p class="admin-subtitle">City ➔ Place ➔ Stand ➔ Type ➔ Manager ➔ CAP</p>
    </div>
    <div class="btn-group">
      <button class="btn-action" onclick={() => (activeModal = "city")}>+ Add City</button>
      <button class="btn-action" onclick={() => (activeModal = "place")}>+ Add Place</button>
      <button class="btn-action btn-highlight" onclick={() => (activeModal = "parking")}>+ Add Stand</button>
      <button class="btn-refresh" onclick={loadData} title="Refresh data">↻</button>
    </div>
  </div>

  {#if successMsg}
    <div class="alert alert-success">{successMsg}</div>
  {/if}
  {#if errorMsg}
    <div class="alert alert-error">{errorMsg}</div>
  {/if}

  <!-- Modal: Add City -->
  {#if activeModal === "city"}
    <div class="form-card">
      <h4>Add New City</h4>
      <div class="form-row">
        <input type="text" placeholder="City name (e.g. Bengaluru, Pune)" bind:value={newCityName} />
        <button class="btn-submit" onclick={addCity} disabled={!newCityName.trim()}>Save City</button>
        <button class="btn-cancel" onclick={() => (activeModal = null)}>Cancel</button>
      </div>
    </div>
  <!-- Modal: Add Place -->
  {:else if activeModal === "place"}
    <div class="form-card">
      <h4>Add Place to City</h4>
      <div class="form-grid">
        <select bind:value={newPlaceCityId}>
          <option value="" disabled selected>Select City</option>
          {#each cities as c}
            <option value={c.id}>{c.name}</option>
          {/each}
        </select>
        <input
          type="text"
          placeholder="Place name (e.g. Palm Meadows, Indiranagar Metro)"
          bind:value={newPlaceName}
        />
        <div class="form-buttons">
          <button class="btn-submit" onclick={addPlace} disabled={!newPlaceCityId || !newPlaceName.trim()}>Save Place</button>
          <button class="btn-cancel" onclick={() => (activeModal = null)}>Cancel</button>
        </div>
      </div>
    </div>
  <!-- Modal: Add Parking Stand -->
  {:else if activeModal === "parking"}
    <div class="form-card">
      <h4>Add Parking Stand</h4>
      <div class="form-grid">
        <select bind:value={newParkingPlaceId}>
          <option value="" disabled selected>Select Place</option>
          {#each places as pl}
            <option value={pl.id}>{pl.name} ({pl.city_name})</option>
          {/each}
        </select>

        <input type="text" placeholder="Stand Name (e.g. Tower A Rack, Gate 1 Stand)" bind:value={newParkingName} />

        <select bind:value={newParkingType}>
          <option value="private">Private (Society)</option>
          <option value="public">Public (Landmark)</option>
        </select>

        {#if newParkingType === "private"}
          <select bind:value={newParkingManagerId}>
            <option value="">Assign Manager (Optional)</option>
            {#each managers as m}
              <option value={m.id}>{m.full_name || m.email} ({m.email})</option>
            {/each}
          </select>
        {/if}

        <input type="number" min="1" max="100" placeholder="CAP (e.g. 10)" bind:value={newParkingCapacity} />

        <div class="form-buttons">
          <button class="btn-submit" onclick={addParking} disabled={!newParkingPlaceId || !newParkingName.trim()}>Save Stand</button>
          <button class="btn-cancel" onclick={() => (activeModal = null)}>Cancel</button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Parking Directory Table: City => Place => Stand => Type => Manager => CAP -->
  <div class="table-card">
    <div class="table-header">
      <h4>Parking Directory ({parkings.length} total)</h4>
      <span class="badge-tag">CITY ➔ PLACE ➔ STAND ➔ TYPE ➔ MANAGER ➔ CAP</span>
    </div>
    {#if loading}
      <div class="table-loading">Loading parking directory...</div>
    {:else if parkings.length === 0}
      <div class="table-empty">No parking stands defined yet. Use the buttons above to add cities, places, and stands.</div>
    {:else}
      <div class="table-responsive">
        <table class="data-table">
          <thead>
            <tr>
              <th>City</th>
              <th>Place</th>
              <th>Stand</th>
              <th>Type</th>
              <th>Manager</th>
              <th class="col-cap">CAP</th>
            </tr>
          </thead>
          <tbody>
            {#each parkings as p}
              <tr>
                <td class="col-city">{p.city_name}</td>
                <td class="col-place"><strong>{p.place_name}</strong></td>
                <td class="col-stand">{p.name}</td>
                <td>
                  <span class={`badge-ptype ptype-${p.parking_type}`}>{p.parking_type}</span>
                </td>
                <td>
                  {#if p.parking_type === "private"}
                    {#if p.manager_name && p.manager_name !== "—"}
                      <span class="manager-badge">👤 {p.manager_name}</span>
                    {:else}
                      <span class="text-muted">Unassigned</span>
                    {/if}
                  {:else}
                    <span class="text-muted">—</span>
                  {/if}
                </td>
                <td class="col-cap"><strong>{p.capacity}</strong></td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  </div>

  <!-- Places Summary -->
  <div class="summary-card">
    <div class="summary-header">
      <h4>📍 Registered Places ({places.length})</h4>
    </div>
    <div class="places-grid">
      {#each places as pl}
        <div class="place-pill">
          <span class="place-city">{pl.city_name}</span>
          <span class="place-name">{pl.name}</span>
          <span class="place-count">
            {parkings.filter((p) => p.place_id === pl.id).length} stands
          </span>
        </div>
      {:else}
        <div class="empty-li">No places registered yet.</div>
      {/each}
    </div>
  </div>
</div>

<style>
  .locations-admin {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .admin-top-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
    background: #fafafa;
    border: 1px solid var(--border-color);
    padding: 1rem 1.25rem;
    border-radius: 0.75rem;
  }

  .admin-subtitle {
    font-size: 0.85rem;
    color: var(--text-muted);
    margin-top: 0.2rem;
    font-family: monospace;
    font-weight: 600;
  }

  .btn-group {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
    align-items: center;
  }

  .btn-action {
    background: var(--card-bg-subtle);
    border: 1px solid var(--border-color);
    padding: 0.4rem 0.85rem;
    border-radius: 0.5rem;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    color: var(--text-main);
    transition: all 0.15s;
  }

  .btn-action:hover {
    background: var(--input-bg);
  }

  .btn-highlight {
    background: var(--primary-color);
    color: white;
    border-color: var(--primary-color);
  }

  .btn-highlight:hover {
    background: var(--primary-hover);
  }

  .btn-refresh {
    background: var(--card-bg-subtle);
    color: var(--text-main);
    border: 1px solid var(--border-color);
    padding: 0.4rem 0.65rem;
    border-radius: 0.5rem;
    cursor: pointer;
    font-weight: 700;
  }

  .form-card {
    background: var(--highlight-box);
    border: 2px dashed var(--primary-color);
    border-radius: 0.75rem;
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
  }

  .form-card h4 {
    margin: 0;
    color: var(--text-main);
    font-size: 1rem;
  }

  .form-row, .form-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 0.6rem;
    align-items: center;
  }

  .form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 0.75rem;
  }

  input[type="text"], input[type="number"], select {
    padding: 0.5rem 0.75rem;
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    font-size: 0.9rem;
    background: var(--input-bg);
    color: var(--text-main);
  }

  .form-buttons {
    display: flex;
    gap: 0.5rem;
  }

  .btn-submit {
    background: var(--primary-color);
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 0.5rem;
    font-weight: 600;
    cursor: pointer;
  }

  .btn-cancel {
    background: var(--card-bg-subtle);
    color: var(--text-main);
    border: 1px solid var(--border-color);
    padding: 0.5rem 0.85rem;
    border-radius: 0.5rem;
    font-weight: 600;
    cursor: pointer;
  }

  .table-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 0.75rem;
    overflow: hidden;
  }

  .table-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.85rem 1.25rem;
    background: var(--card-header-bg);
    border-bottom: 1px solid var(--border-color);
  }

  .table-header h4 {
    margin: 0;
    font-size: 1.05rem;
    color: var(--text-main);
  }

  .badge-tag {
    font-size: 0.75rem;
    font-weight: 700;
    font-family: monospace;
    color: var(--text-muted);
    background: var(--card-bg-subtle);
    border: 1px solid var(--border-color);
    padding: 0.2rem 0.5rem;
    border-radius: 0.25rem;
  }

  .table-responsive {
    overflow-x: auto;
  }

  .data-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9rem;
    text-align: left;
  }

  .data-table th, .data-table td {
    padding: 0.75rem 1rem;
    border-bottom: 1px solid var(--border-color);
    color: var(--text-main);
  }

  .data-table th {
    background: var(--card-header-bg);
    color: var(--text-muted);
    font-size: 0.75rem;
    text-transform: uppercase;
    font-weight: 700;
  }

  .col-city {
    color: var(--text-muted);
    font-weight: 600;
  }

  .col-place {
    color: var(--text-main);
  }

  .col-stand {
    color: var(--text-main);
  }

  .col-cap {
    text-align: right;
    font-variant-numeric: tabular-nums;
  }

  .badge-ptype {
    padding: 0.2rem 0.55rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: uppercase;
  }

  .ptype-private {
    background: #e0f2fe;
    color: #0369a1;
  }

  .ptype-public {
    background: #fef3c7;
    color: #92400e;
  }

  .manager-badge {
    background: #dcfce7;
    color: #15803d;
    padding: 0.2rem 0.55rem;
    border-radius: 0.375rem;
    font-weight: 600;
    font-size: 0.85rem;
  }

  .text-muted { color: #94a3b8; font-size: 0.85rem; }

  .summary-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 0.75rem;
    padding: 1.25rem;
  }

  .summary-header {
    margin-bottom: 0.85rem;
  }

  .summary-header h4 {
    margin: 0;
    font-size: 1rem;
    color: var(--text-main);
  }

  .places-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 0.75rem;
  }

  .place-pill {
    background: #f8fafc;
    border: 1px solid var(--border-color);
    border-radius: 0.5rem;
    padding: 0.65rem 0.85rem;
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }

  .place-city {
    font-size: 0.75rem;
    color: var(--primary-color);
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .place-name {
    font-size: 0.95rem;
    font-weight: 600;
    color: var(--text-main);
  }

  .place-count {
    font-size: 0.8rem;
    color: var(--text-muted);
  }

  .table-loading, .table-empty {
    padding: 2rem;
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
