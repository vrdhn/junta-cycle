# junta-cycle (jc) - Agent Memory & Project Context

## Project Overview
**junta-cycle (jc)** is a SaaS platform enabling community bicycle sharing for commuting. Users can pick up a cycle, commute to their destination, lock and leave it, allowing others to unlock and use it.
- **Unlocking Mechanism**: Each cycle has a unique QR code identifying it and a physical combination number lock. Scanning the QR code provides the user with the number lock combination to unlock and start their ride.

## Tech Stack
- **Backend / Database**: Supabase (Free tier) - PostgreSQL, Auth, Row-Level Security (RLS), Edge Functions/REST API.
- **Frontend / Hosting**: GitHub Pages (Client-side static deployment).
- **Version Control**: GitHub.
- **Language**: TypeScript.

## Standing Instructions
1. **Do not assume anything, ask.**
2. **Small files, small functions.**
3. **Don't waste time searching for files, ever. ASK.**
4. **Tool & Dependency Management**: Do NOT use system installed runtimes. Manage all dependencies/tools in `~/.cache/junta-cycle`. `jctool` must manage and use this cached environment.
5. **Memory management**: All memory is stored in `AGENT.md` in the repo. No file in `$HOME` or elsewhere should store memory.

## Architecture & Technology Decisions
- **Framework**: Svelte with TypeScript.
- **Styling**: Minimal CSS, mobile-friendly / responsive.
- **Backend**: Supabase (free tier).
- **Hosting**: GitHub Pages.
- **Approach**: Minimal starting scope; defer complex billing, geofencing, and advanced flows.

## Tools & Workflows
- **`./jctool`**: Project management script in Python (standard library only, zero external dependencies).
  - `./jctool install`: Installs Node.js & npm into `~/.cache/junta-cycle/nodejs` (isolated, non-system).
  - `./jctool check`: Verifies Node/npm runtime in cache, Git/GitHub credentials, and Supabase keys in `config.json`.
  - `./jctool encrypt`: Encrypts plaintext strings under `"secrets"` in `config.json` with prefix `enc-v1:` using OpenSSL AES-256-CBC PBKDF2, and saves `password_check`.
  - `./jctool build`: Builds the Svelte frontend into `frontend/dist` using cached node/npm.
  - `./jctool dev`: Launches Vite dev server for local frontend testing.
  - `./jctool publish`: Builds the frontend and deploys directly to `gh-pages` branch on GitHub remote.

## Directory Structure
- `frontend/`: Svelte + TypeScript + Vite web app (landing page, mobile-friendly styles).
- `backend/`: SQL schemas, migrations, and Supabase functions.

## Configuration & Secrets Management
- File: `config.json`
- Top-level `"secrets"` object contains sensitive service configurations (e.g. `"supabase"`: `url`, `anon_key`, `database-password`).
- **Strict Encryption Policy**: All values under `"secrets"` must always be encrypted with prefix `enc-v*:`. If any value is unencrypted, `jctool` immediately terminates execution with an error telling the user to run `./jctool encrypt` (except for `jctool encrypt` itself).
- **No Decrypt Command**: Decryption to plaintext disk is disallowed.
- **Passphrase Verification**: The passphrase itself is encrypted with itself and stored as `secrets.password_check`. When a passphrase is provided, it is validated against this secret.
- Encryption scheme: OpenSSL AES-256-CBC, PBKDF2 with 100,000 iterations and salt.
- Encrypted format: `enc-v1:<base64-ciphertext>`

## Current Status & Next Steps
- Frontend created in `frontend/` with landing page (`frontend/src/App.svelte`).
- Added fixed top status bar (`frontend/src/lib/StatusBar.svelte`) checking Supabase Auth health (`/auth/v1/health`) every 5 seconds (green dot = Online, red dot = Offline).
- Updated `./jctool` to securely decrypt frontend public configuration (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`) in memory during `build` and `dev`.
- Next: Build/publish and wire up Supabase Auth to the Login button.







