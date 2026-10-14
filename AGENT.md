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
  - `./jctool install`: Installs Node.js, npm, and Supabase CLI into `~/.cache/junta-cycle` (isolated, non-system).
  - `./jctool check`: Verifies Node/npm runtime, Supabase CLI, Git/GitHub credentials, and Supabase keys in `config.json`.
  - `./jctool encrypt`: Encrypts plaintext strings under `"secrets"` in `config.json` with prefix `enc-v1:` using OpenSSL AES-256-CBC PBKDF2, and saves `password_check`.
  - `./jctool build`: Builds the Svelte frontend into `frontend/dist` using cached node/npm.
  - `./jctool dev`: Launches Vite dev server for local frontend testing.
  - `./jctool db-migrate`: Applies pending migrations to Supabase transactionally with automatic rollback using `supabase db push`.
  - `./jctool db-status`: Displays migration status (local vs remote) using `supabase migration list`.
  - `./jctool db-new <name>`: Generates a new timestamped migration file in `supabase/migrations/`.
  - `./jctool db-query`: Executes SQL queries or files against Supabase (e.g. `./jctool db-query 'SELECT 1;'`).
  - `./jctool publish`: Runs `db-migrate` first; if successful, builds and publishes frontend to `gh-pages`.


## Directory Structure
- `frontend/`: Svelte + TypeScript + Vite web app (landing page, mobile-friendly styles).
- `supabase/`:
  - `supabase/migrations/`: Timestamped `.sql` migration files (e.g., `20261014000000_roles_and_profiles.sql`).

## Configuration & Secrets Management
- File: `config.json`
- Top-level `"secrets"` object contains sensitive service configurations (e.g. `"supabase"`: `url`, `anon_key`, `database-password`).
- **Strict Encryption Policy**: All values under `"secrets"` must always be encrypted with prefix `enc-v*:`. If any value is unencrypted, `jctool` immediately terminates execution with an error telling the user to run `./jctool encrypt` (except for `jctool encrypt` itself).
- **No Decrypt Command**: Decryption to plaintext disk is disallowed.
- **Passphrase Verification**: The passphrase itself is encrypted with itself and stored as `secrets.password_check`. When a passphrase is provided, it is validated against this secret.
- Encryption scheme: OpenSSL AES-256-CBC, PBKDF2 with 100,000 iterations and salt.
- Encrypted format: `enc-v1:<base64-ciphertext>`

## Database Architecture
- **Migrations Engine**: Supabase CLI native migration engine (`supabase db push`, `supabase migration list`).
- **Transactional Rollback**: Each migration file executes in an atomic transaction; on failure, all changes in that file are rolled back.
- **Tracking Table**: `supabase_migrations.schema_migrations` maintained automatically by Supabase.
- **`public.allowed_roles`**: Table storing allowed roles (`rider`, `manager`, `superuser`).
- **`public.profiles`**: 1-to-1 extension of `auth.users`, storing `email`, `full_name`, and `roles text[]`.
- **Integrity**: `validate_roles()` check constraint ensures all elements in `profiles.roles` exist in `allowed_roles`.
- **Authorization**: `public.has_role(check_role)` helper function enables fast RLS checks (superuser automatically matches).
- **Trigger**: `on_auth_user_created` trigger automatically provisions a `profiles` entry with `roles = array['rider']` on signup.

## Current Status & Next Steps
- Standardized on Supabase CLI's transactional migration engine with `supabase/migrations/20261014000000_roles_and_profiles.sql`.
- Ready to apply migration using `./jctool db-migrate`.
- Next: Wire up Supabase Auth login with pre-configured test users.
- Next: Wire up Supabase Auth login with pre-configured test users.









