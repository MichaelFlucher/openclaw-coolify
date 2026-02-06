# OpenClaw Coolify - Project Notes

## Branch Strategy

- **`main`** — Tracks the upstream openclaw-coolify repo. Keep clean; do not push custom changes here.
- **`coolify`** — Deployment branch for Coolify. All custom config, patches, and features go here.
- **Feature branches** (e.g. `nvidia-api-agent`) — Branch off `coolify`, merge back into `coolify`.

When merging, always target `coolify`, never `main`.

## NVIDIA NIM Models

Provider: `nvidia` | API type: `openai-completions` (Chat Completions, NOT Responses API)

| Model ID | Type | Notes |
|---|---|---|
| `moonshotai/kimi-k2-thinking` | Reasoning (primary) | Chain-of-thought, good availability |
| `moonshotai/kimi-k2-instruct` | Fast (fallback 1) | No reasoning, best availability |
| `moonshotai/kimi-k2.5` | Reasoning (fallback 2) | Often overloaded on free tier |

Fallback chain is configured in `agents.list[].model.fallbacks` and auto-triggered when all auth profiles for a provider fail.

## Key Paths (inside container)

- Config: `/data/.openclaw/openclaw.json` (persistent volume, auto-reloaded on change)
- Logs: `/tmp/openclaw/openclaw-YYYY-MM-DD.log`
- Bootstrap: `scripts/bootstrap.sh` (only generates config if none exists)
