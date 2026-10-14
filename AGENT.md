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
  - `./jctool check`: Verifies Node/npm runtime in cache, Git/GitHub credentials, and Supabase keys.

## Current Status & Next Steps
- Node.js (v22.11.0) and npm (10.9.0) successfully installed in `~/.cache/junta-cycle/nodejs`.
- `./jctool check` runs cleanly and reports status.
- Next: Supabase credentials configuration and project scaffolding.

