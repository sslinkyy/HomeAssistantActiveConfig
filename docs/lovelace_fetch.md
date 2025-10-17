Lovelace (Storage UI) export
============================

This repo is set up to version only the Lovelace Storage UI files under `.storage/` while keeping the rest of `.storage/` ignored.

Two ways to export from your HA instance:

PowerShell (Windows)
- Env vars: `HASS_URL` (e.g., `http://homeassistant:8123`), `HASS_TOKEN` (long‑lived access token)
- Run: `scripts/fetch_lovelace.ps1 -BaseUrl $env:HASS_URL -Token $env:HASS_TOKEN`

Bash (Linux/macOS/WSL)
- Env vars: `HASS_URL`, `HASS_TOKEN`
- Requires: `curl`, `jq`
- Run: `HASS_URL=... HASS_TOKEN=... bash scripts/fetch_lovelace.sh`

Files saved
- `.storage/lovelace` (default dashboard config)
- `.storage/lovelace_resources` (resources)
- `.storage/lovelace_dashboards` (list of dashboards)
- `.storage/lovelace.<id>` (config for each additional dashboard)

Commit
- `git add .storage/lovelace*`
- `git commit -m "Track Lovelace Storage UI source of truth"`
- `git push`

