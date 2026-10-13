# AGENTS.md

## Repo Notes

This repository contains the Coolify-oriented OpenClaw deployment and bootstrap
logic.

Read this first when working on runtime or deployment issues:

- `docs/diagnostics/openclaw-upgrade-2026-10-13.md` (latest upgrade and recovery)
- `docs/diagnostics/openclaw-browser-recovery-overview.md`

## Current Operational State

- OpenClaw is pinned to `2026.10.2` (Coolify's `OPENCLAW_VERSION` must match)
- Deployment branch is `coolify`; pushing it automatically triggers Coolify.
- This repository is public. Never commit credentials, runtime configuration,
  transcripts, environment files with values, database copies, or private backups.
- Prefer OpenClaw's CLI/gateway for runtime changes; preserve global model
  inheritance instead of adding redundant main-agent/session overrides.
- the OpenClaw container should use `restart: unless-stopped`
- browser config normalization happens in `scripts/bootstrap.sh`
- `scripts/ensure-managed-browser.sh` is the current watchdog workaround for
  managed-browser startup issues in the containerized setup
- Go `1.23.4` is copied from its official multi-platform Docker image; archive
  downloads stalled during the upgrade. Do not reintroduce the hanging download.
- Browser profile `color` is retired. The normalizer must remove it, not re-add it.
- After the 2026-10-13 upgrade, main inherits global `openai/gpt-6.1-sol` and
  an isolated inference test succeeded. The Opus specialist remains explicitly
  configured; the global utility model is independent.
- Local semantic memory is degraded: the new llama.cpp server installer requires
  glibc 2.38+ on ARM64, but the Bookworm container has glibc 2.36. Chat is healthy.
  Preserve the memory index; do not switch to a paid embedding provider or clear
  the index just to make Doctor pass.

## Upgrade precautions

- Check the target release's migration requirements before replacing the image.
  Old legacy state required Doctor on bridge release `2026.9.5`, then Doctor on
  the target. Do not run an older bridge against newer SQLite schemas.
- Take and verify a full-state backup before schema migrations. Automatic
  migration copies and individual config/database copies are not full backups.
- Stop the Docker-owned gateway before offline maintenance; do not substitute
  native systemd/LaunchAgent lifecycle commands for Docker ownership.
- Use temporary maintenance containers with `--init`, the same state volumes,
  and the application's environment supplied privately. Preserve the container
  hostname across interrupted repair attempts because the update ledger records
  hostname and driver process identity.
- Do not declare success from Coolify's `finished` status alone. Check actual
  version, stable container health, configuration, gateway readiness, Telegram
  polling, browser CDP, and an isolated model request without delivery or tools.
- Historical transcript inconsistencies were repaired with explicit user approval
  and originals retained. Future file-level repairs need evidence and authority;
  never invent requester facts to force a native task migration.

## Files To Check For OpenClaw Runtime Issues

- `docker-compose.yaml`
- `Dockerfile`
- `scripts/bootstrap.sh`
- `scripts/ensure-managed-browser.sh`
- `docs/diagnostics/openclaw-browser-recovery-overview.md`
- `docs/diagnostics/openclaw-upgrade-2026-10-13.md`

## Browser-Specific Note

If OpenClaw's own browser launcher fails but Chromium itself works manually,
the watchdog script is the expected fallback. Do not remove it without testing
fresh container startup, browser status, and Telegram flow end-to-end.
