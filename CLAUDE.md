# OpenClaw Coolify - Project Notes

## Branch Strategy

- **`main`** — Tracks the upstream openclaw-coolify repo. Keep clean; do not push custom changes here.
- **`coolify`** — Deployment branch for Coolify. All custom config, patches, and features go here.
- **Feature branches** (e.g. `nvidia-api-agent`) — Branch off `coolify`, merge back into `coolify`.

When merging, always target `coolify`, never `main`.

## Model Setup

### Default agent (main)

| Priority | Model | Provider |
|----------|-------|----------|
| **Primary** | `google/gemini-3-flash-preview` | Google (custom provider, v1beta) |
| **Fallback 1** | `nvidia/moonshotai/kimi-k2-thinking` | NVIDIA NIM |
| **Fallback 2** | `nvidia/moonshotai/kimi-k2-instruct` | NVIDIA NIM |
| **Fallback 3** | `nvidia/moonshotai/kimi-k2.5` | NVIDIA NIM |

### Additional agents

| Agent ID | Model | Provider |
|----------|-------|----------|
| `claude_opus` | `anthropic/claude-opus-4-6` | Anthropic |
| `gemini_pro` | `google/gemini-2.5-pro` | Google (custom provider, v1beta) |

### Provider notes

- **Google Gemini**: Requires a custom `models.providers.google` block with `baseUrl: "https://generativelanguage.googleapis.com/v1beta"` and `api: "google-generative-ai"`. The built-in provider in OpenClaw `2026.2.3-1` uses the v1 endpoint which does NOT support `systemInstruction`, `tools`, or `functionCall`/`functionResponse` fields. Always use **v1beta**.
- **NVIDIA NIM**: Requires `api: "openai-completions"` (NOT `"openai-responses"`). Kimi K2.5 is often overloaded on the free tier. **Must have an auth profile** (`nvidia:default` with `type: "api_key"`) in both `openclaw.json` (`auth.profiles`) and `agents/main/agent/auth-profiles.json` — without it, fallbacks silently skip NVIDIA models even if the provider has an `apiKey` in its config.
- **Anthropic**: Custom provider with `api: "anthropic-messages"`. Requires `ANTHROPIC_API_KEY` env var.

Fallback chain is configured in `agents.list[].model.fallbacks` and auto-triggered when all auth profiles for a provider fail. **Every provider in the fallback chain needs an auth profile** — providers without one are skipped silently.

## Troubleshooting

- **"Unknown model" after changing models**: Sessions cache the model name. Clear sessions at `/data/.openclaw/agents/main/sessions/` and restart the container.
- **"Unknown name functionCall/systemInstruction"**: Google API v1 vs v1beta mismatch. Ensure the custom google provider uses `v1beta` base URL.
- **Model shows "missing" in `openclaw models list`**: The model ID doesn't exist in the built-in catalog for this OpenClaw version. Add it as a custom provider model instead.
- **Fallbacks not triggering on 429**: Check that every fallback provider has an auth profile in `auth-profiles.json`. Without one, the provider is considered unavailable and skipped. Error log will show `"All models failed (1)"` — the `(1)` means only the primary was attempted.
- **Gemini auth not working**: Run `openclaw onboard --non-interactive --accept-risk --auth-choice gemini-api-key --gemini-api-key <key> --skip-channels --skip-skills --skip-health --skip-ui --skip-daemon`. Note: onboard may reset `gateway.bind` to `loopback` — fix it back to `lan`.

## Key Paths (inside container)

- Config: `/data/.openclaw/openclaw.json` (persistent volume, auto-reloaded on change)
- Sessions: `/data/.openclaw/agents/main/sessions/` (clear these when switching models)
- Auth profiles: `/data/.openclaw/agents/main/agent/auth-profiles.json`
- Logs: `/tmp/openclaw/openclaw-YYYY-MM-DD.log`
- Bootstrap: `scripts/bootstrap.sh` (only generates config if none exists)
