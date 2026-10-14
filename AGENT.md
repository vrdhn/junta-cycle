# junta-cycle (jc) - Agent Policies & Workflows

## Core Policies
1. **Zero Assumptions**: Do not assume anything; ask for clarification.
2. **Minimal Code Units**: Small files, small functions.
3. **No File Searching Overhead**: Never waste time searching for files; ask.
4. **Scope of AGENT.md**: Contains ONLY active policies and operational workflows. No past-looking status logs, no future-looking roadmaps, and no data inventory.
5. **Isolated Runtimes**: Never use system-installed runtimes. All tools (Node.js, npm, Supabase CLI) are maintained strictly in `~/.cache/junta-cycle` and managed via `jctool`.
6. **Zero Memory Spread**: All agent policy memory resides in this file (`AGENT.md`). Never store memory or state in `$HOME` or other ad-hoc files.

## Architecture & Code Policies
1. **Logic in TypeScript**: All business logic (QR codes, lock combinations, debug endpoints, authorization) lives in TypeScript handlers (Svelte frontend and Supabase Edge Functions).
2. **Lean PostgreSQL (No RLS)**: PostgreSQL is used strictly as a relational data store. Row Level Security (RLS) is disabled. Keep SQL lean with minimal triggers.
3. **No Fallback Data**: Never mask backend failures with client-side mock/fallback data. Endpoints must fail transparently and display errors to the user.
4. **Responsive Styling**: Pure minimal CSS that scales seamlessly from wide desktop screens to mobile devices.
5. **Hosting**: Static frontend hosted on GitHub Pages (`gh-pages` branch).

## Security & Secrets Policy
1. **Secrets Location**: Sensitive configurations reside in `config.json` under `"secrets"`.
2. **Strict Encryption**: Every secret value in `config.json` must be encrypted with prefix `enc-v1:` using OpenSSL AES-256-CBC with PBKDF2 (100,000 iterations and salt).
3. **No Plaintext on Disk**: Unencrypted secrets block CLI execution immediately. Decryption to plaintext files on disk is prohibited.
4. **Passphrase Verification**: User passphrases are validated against `secrets.password_check`.

## Workflows & CLI (`./jctool`)
- `./jctool install`: Installs Node.js, npm, and Supabase CLI into `~/.cache/junta-cycle`.
- `./jctool check`: Verifies local runtimes, credentials, and Supabase keys.
- `./jctool encrypt`: Encrypts plaintext secrets in `config.json` into `enc-v1:` format.
- `./jctool build`: Builds Svelte frontend into `frontend/dist` with SPA route handling.
- `./jctool dev`: Runs local Vite development server.
- `./jctool db-migrate`: Applies pending migrations to Supabase transactionally (`supabase db push`).
- `./jctool db-clean` (or `dbclean`): Drops all tables, triggers, and resets migration history for fresh starts.
- `./jctool db-status`: Displays migration status (local vs remote).
- `./jctool db-demo`: Populates database with 10 demo users from `supabase/seed.sql`.
- `./jctool db-new <name>`: Generates a new timestamped migration file.
- `./jctool db-query`: Executes SQL queries or scripts against the Supabase database.
- `./jctool func-deploy [name]`: Deploys Supabase Edge Functions.
- `./jctool publish`: Full deployment pipeline: runs migrations, deploys edge functions, and deploys frontend to `gh-pages`.
