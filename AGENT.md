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
  - `./jctool encrypt`: Encrypts plaintext strings under `"secrets"` in `config.json` with prefix `enc-v1:` using OpenSSL AES-256-CBC PBKDF2.
  - `./jctool decrypt`: Decrypts `enc-v1:` strings in `config.json` using console-prompted passphrase.

## Configuration & Secrets Management
- File: `config.json`
- Top-level `"secrets"` object contains sensitive service configurations (e.g. `"supabase"`: `url`, `anon_key`).
- Encryption scheme: OpenSSL AES-256-CBC, PBKDF2 with 100,000 iterations and salt.
- Encrypted format: `enc-v1:<base64-ciphertext>`
- Passphrase is asked interactively from the console (hidden input via `getpass`).

## Current Status & Next Steps
- Node.js (v22.11.0) and npm (10.9.0) managed in `~/.cache/junta-cycle/nodejs`.
- Converted `jctool` to Python stdlib; tested `install`, `check`, `encrypt`, and `decrypt`.
- Initial `config.json` template created.


