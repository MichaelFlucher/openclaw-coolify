# OpenClaw upgrade and recovery — 2026-10-13

## Verified outcome

The Coolify deployment was upgraded from runtime `2026.7.1-2` to `2026.10.2`.
The deployment repository previously defaulted to `2026.5.12`; a Coolify build
variable overrode that default. Both repository pins and the production
`OPENCLAW_VERSION` variable were updated to `2026.10.2`.

Last verified:

- Docker container healthy, with restart policy `unless-stopped`.
- Gateway ready; local HTTP check returned `200`.
- Main and worker Telegram bots started polling.
- Browser CDP endpoint on `127.0.0.1:18800` returned `200`.
- An isolated main-agent request returned `OK` using `openai/gpt-6.1-sol`,
  through the Codex harness, with no tools invoked and no channel delivery.
- Main has no model override, and global subagent model pins were removed.
- Repository worktree was clean before these documentation changes.

This does **not** mean every Doctor finding is resolved. Local semantic memory
is degraded, an old native task remains retained, and other advisory findings
are listed below. Version `2026.10.3` became available during the work; it was
not deployed. Recheck the registry rather than treating this document as a
current release recommendation.

## Deployment layout and authority

- Public repository: `MichaelFlucher/openclaw-coolify`.
- Deployment branch: `coolify`; pushes automatically trigger Coolify builds.
- Build pack: Docker Compose. Application UUID `n008s4kcocc08g88gcgcgogg`, ID `9`.
- Change the repository pins in `Dockerfile`, `docker-compose.yaml`, and
  `.env.example`, and check Coolify's **production/build-time** version variable.
  Do not accidentally update a preview variable instead.
- Coolify API access is local-only. Private credential location and host access
  details belong in `/home/mflu/AGENTS.md`, not in this public repository.
- Active state/config: `/data/.openclaw/openclaw.json` and SQLite databases
  underneath `/data/.openclaw/state` and each agent directory.
- Main workspace: `/data/openclaw-workspace`.
- Named volume suffixes: `openclaw-data`, `openclaw-config`,
  `openclaw-workspace`; resolve exact project-prefixed names before maintenance.
- Container names change on deployment; discover them with `docker ps`.
- Configuration migrated from `agents.list` to keyed `agents.entries` and from
  legacy model allowlists to `agents.defaults.modelPolicy.allow`. Use the live
  CLI/schema rather than writing obsolete paths from old documentation.

The user requested runtime updates through OpenClaw's CLI/gateway and global
model inheritance wherever possible. A specific exception was later approved
for transcript corrections; it is not blanket authority for direct state edits.

## Original model failure

The Telegram session had an explicit GPT 6.1 Sol override, while main and the
heartbeat still used GPT 5.6 Sol. Logs showed `Unknown model: openai/gpt-6.1-sol`
for Telegram, although a fresh CLI catalog later recognized GPT 6.1 Sol.
There were also earlier subscription-limit and capacity errors for GPT 5.6 Sol.

OpenClaw commands removed main's primary, utility, and subagent overrides, the
global subagent model pin, and the Telegram session override. Global primary
remained GPT 6.1 Sol; global utility remained GPT 5.6 Terra. The intentional Opus
specialist model was preserved. The post-upgrade inference test confirmed that
the global GPT 6.1 Sol model actually works.

## Build and startup fixes committed

- `7c8b621`: pin deployment to OpenClaw `2026.10.2`.
- `b5dea9f`: initially add bounded retries for the stalled Go archive download.
- `fa4506a`: replace that download with the same Go `1.23.4` toolchain copied
  from the official `golang:1.23.4-bookworm` multi-platform image.
- `259470e`: remove retired browser profile `color` from normalization and
  fresh-config seeding. Doctor removed it, but the old bootstrap re-added it on
  every restart, making `2026.10.2` reject the configuration.

The browser watchdog workaround remains in place. Do not remove it based only
on a successful gateway startup.

## Database and transcript migration

The initial new-image startup refused shared-state migration (`audit-events-v2`).
Direct target-release Doctor then refused older plugin/workspace state. The
supported legacy bridge was `2026.9.5`; this should have been checked before the
initial deployment.

The first target Doctor had already advanced shared SQLite beyond the bridge's
supported schema. With the gateway stopped, the pre-migration shared-state
directory was restored and the newer directory retained separately. Bridge
Doctor migrated the plugin install index, agent databases, provider catalogs,
authentication and pairing records, workspace setup, cron/heartbeat state, and
legacy session history. Target Doctor then advanced databases to current schemas.
Approximately 36,000 transcript events were imported during the bridge pass.

Built-in recovery refused inconsistent retained JSONL data. After explicit user
approval, a guarded metadata repair preserved originals and corrected:

- Two session header IDs to agree with their transcript filenames.
- Two main-agent events whose SQLite equivalents contained migrated media fields.
- Two worker-agent context labels changed by Doctor from the legacy
  `(untrusted metadata)` label to the newer OpenClaw context marker.

The repairs checked that events matched outside those specific metadata fields.
Authored message content was preserved. OpenClaw's subsequent session import
reported canonical history verified; remaining source-retention notices related
to plugin migrations. Originals and migration receipts must be retained.

## Maintenance-container lessons

- Offline migrations must run with the Docker-owned gateway stopped.
- Supply the real application's environment privately; missing provider
  environment can produce misleading configuration/authentication findings.
- Use `--init`. A maintenance container with `sleep` as PID 1 left a defunct
  helper behind and an updater stalled during process settlement.
- Preserve hostname when recovering an interrupted updater. Its ledger checks
  recorded hostname and process liveness; a replacement hostname was refused.
- `openclaw update repair --no-restart` still performed native-service health
  observation in this environment. Do not assume it verifies a separate
  Coolify-owned container correctly.
- The final offline repair's plugin phase updated three packages. Its later
  configuration check failed because managed local embeddings could not initialize.
  After confirming there were no active migration children and the serving
  container was healthy, the lingering updater was interrupted with SIGINT and
  the maintenance container stopped. The updater was **not** reported as a
  fully successful repair; interrupted update-ledger notices may remain.
- Temporary maintenance containers and private recovery artifacts were left
  intact, not pruned. Host-specific paths are documented in the workspace file.

## Remaining limitations

### Local semantic memory

`memory.search.provider` remains `local`; indexes were preserved. The old
in-process `node-llama-cpp` runtime was removed in favor of a managed
`llama-server`. Doctor and gateway logs report degraded semantic recall.

The supported local setup command was attempted:

```sh
openclaw models --agent main auth login --provider llama-cpp --method local
```

Automatic setup refused: the verified Linux ARM64 binary needs glibc 2.38+,
while this Bookworm image has 2.36. A compatible `llama-server` build and its
absolute path are needed, or a separately considered base-image upgrade.
Do not silently switch to paid remote embeddings, change the chat model, or
erase the memory index. Validate with `openclaw memory status --deep` after setup.

### Historical Codex task and other notices

One retained native Codex task lacked original requester/session/lifecycle and
connection ownership facts. The plugin preserved it instead of inventing
delivery authority. This did not prevent the verified GPT 6.1 Sol request.
Do not mark it delivered, fabricate ownership, or delete its history just to
silence a migration notice.

Webwright reported missing capability consent; its update was skipped. Existing
skill metadata for `web-utils` lacks a description and is skipped by the indexer.
Doctor also reported legacy cron sender-policy restrictions and unset command
ownership. These were not broadened or reauthorized during the upgrade.

## Future upgrade checklist

1. Read release/migration requirements and inspect the real installed version,
   active schema, plugins, and Coolify build variables.
2. Create and verify a full-state backup; individual files and Doctor recovery
   copies are not equivalent. Keep all recovery material private.
3. Plan any bridge migration before advancing SQLite. Older binaries refuse
   newer schemas; do not attempt an image-only downgrade against migrated data.
4. Update pins and production build variables, then push the deployment branch
   once. Check for an automatic deployment before requesting another via API.
5. Preserve browser recovery, model inheritance, state volumes, and credentials.
6. Verify actual container version and stable health, gateway readiness, channel
   polling, browser CDP, and isolated inference without delivery/tools.
7. Report feature regressions and unfinished migrations explicitly; neither
   Coolify's `finished` status nor HTTP `200` proves all features work.

Primary references: [OpenClaw upgrades](https://docs.openclaw.ai/install/updating)
and [session SQLite recovery](https://docs.openclaw.ai/cli/doctor/sqlite-maintenance).
