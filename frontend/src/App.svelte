<script lang="ts">
  function handleLogin() {
    alert("Supabase Auth flow will start here.");
  }
</script>

<main class="welcome-container">
  <div class="hero-card">
    <div class="logo-icon">🚲</div>
    <h1>Welcome to Junta Cycles</h1>
    <p class="tagline">Smart community bicycle sharing for your daily commute.</p>

    <div class="action-section">
      <button class="btn-primary" on:click={handleLogin}>
        Login
      </button>
    </div>
  </div>
</main>

<style>
  .welcome-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
  }

  .hero-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 1rem;
    padding: 2.5rem 1.5rem;
    width: 100%;
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
</style>
