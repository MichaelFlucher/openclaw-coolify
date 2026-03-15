# AGENTS.md

## Repo Notes

This repository contains the Coolify-oriented OpenClaw deployment and bootstrap
logic.

Read this first when working on runtime or deployment issues:

- `docs/diagnostics/openclaw-browser-recovery-overview.md`

## Current Operational State

- OpenClaw is pinned to `2026.3.13`
- the OpenClaw container should use `restart: unless-stopped`
- browser config normalization happens in `scripts/bootstrap.sh`
- `scripts/ensure-managed-browser.sh` is the current watchdog workaround for
  managed-browser startup issues in the containerized setup

## Files To Check For OpenClaw Runtime Issues

- `docker-compose.yaml`
- `Dockerfile`
- `scripts/bootstrap.sh`
- `scripts/ensure-managed-browser.sh`
- `docs/diagnostics/openclaw-browser-recovery-overview.md`

## Browser-Specific Note

If OpenClaw's own browser launcher fails but Chromium itself works manually,
the watchdog script is the expected fallback. Do not remove it without testing
fresh container startup, browser status, and Telegram flow end-to-end.
