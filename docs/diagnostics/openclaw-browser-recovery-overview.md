# OpenClaw Browser Recovery Overview

## Situation

On 2026-03-15, the OpenClaw container stopped responding over Telegram and the
browser tool was unavailable.

Two separate issues were involved:

1. The container exited cleanly after an internal gateway restart, but Docker
   did not restart it because the service used `restart: on-failure:10`.
2. After recovery and upgrade, OpenClaw's managed browser launcher still failed
   to bring Chromium up on the configured CDP port, even though Chromium itself
   worked when started manually.

## Root Causes

### 1. Container restart policy

The OpenClaw service was configured with:

```yaml
restart: on-failure:10
```

OpenClaw triggered a full internal process restart and exited with code `0`.
Docker treats that as a successful exit, so the container remained stopped.

### 2. Legacy browser profile config

The persisted config at `/data/.openclaw/openclaw.json` contained a legacy
browser profile shape:

```json
"browser": {
  "headless": true,
  "noSandbox": true,
  "defaultProfile": "openclaw",
  "profiles": {
    "openclaw": {
      "cdpPort": 18800,
      "driver": "clawd",
      "color": "#FF4500"
    }
  }
}
```

After the upgrade, the browser control service still saw Chromium on
`/usr/bin/chromium`, but `POST /start` returned HTTP `500` and left defunct
Chromium processes behind. Manual Chromium startup on `18800` worked, so the
launcher path was the failing piece.

## Changes Applied

### Deployment and versioning

- Changed OpenClaw restart policy to `unless-stopped` in
  `docker-compose.yaml`.
- Updated pinned OpenClaw version to `2026.3.13` in:
  - `docker-compose.yaml`
  - `.env.example`
  - `Dockerfile`
- Performed in-container OpenClaw upgrade from `2026.2.21-2` to `2026.3.13`.

### Bootstrap normalization

Updated `scripts/bootstrap.sh` to:

- remove stale `plugins.entries.google-antigravity-auth`
- normalize browser defaults
- remove legacy browser keys such as `driver` and `executablePath`
- retain `cdpPort: 18800` for the local managed profile
- seed a clean browser section for fresh installs

### Browser watchdog

Added `scripts/ensure-managed-browser.sh`.

Purpose:

- monitor the managed browser CDP endpoint on `127.0.0.1:18800`
- auto-start Chromium directly when CDP is down
- keep the browser usable even if OpenClaw's own launcher fails

Bootstrap now copies and starts this watchdog alongside the existing recovery
and monitoring scripts.

## Runtime Outcome

Current observed state after the fixes:

- container: healthy
- OpenClaw version: `2026.3.13`
- browser control API reachable on `127.0.0.1:18791`
- browser status:

```json
{
  "running": true,
  "cdpReady": true,
  "cdpHttp": true,
  "cdpPort": 18800
}
```

## Important Note

The browser availability is currently guaranteed by the watchdog workaround,
not by a confirmed fix in OpenClaw's own browser launcher. The launcher still
appears unreliable in this containerized setup.

That means:

- the repository now contains a durable operational workaround
- the running container has the workaround active
- a future upstream OpenClaw release may make the watchdog unnecessary

## Files Touched

- `docker-compose.yaml`
- `.env.example`
- `Dockerfile`
- `scripts/bootstrap.sh`
- `scripts/ensure-managed-browser.sh`

## Recommended Next Step

After committing and deploying these changes through the normal Coolify flow,
verify:

1. container restart survives a gateway-triggered full restart
2. Telegram still responds
3. browser control remains `running=true` after a fresh container start
