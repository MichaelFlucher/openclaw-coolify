# Node.js security base update — 2026-10-21

## Scope

Pin the Docker base from the moving node:lts-bookworm-slim tag to
node:24.22.1-bookworm-slim for the October 2026 Node.js security release.
OpenClaw stays pinned to 2026.10.2. This is not an OpenClaw runtime upgrade;
no configuration-schema migration, Doctor repair, bridge release, model change,
index deletion, or state-file repair is requested or performed.

The initial checkpoint changed only the Dockerfile Node base and this document.
The preservation preflight adds the narrowly scoped browser helper/install fix
described below. Compose environment, volumes, restart policy, global model
inheritance, Go 1.23.4 copy stage and application version pins remain untouched.

## Preparation verification (completed)

- [x] Fresh production-branch receipt: origin/coolify at c12a9485b4d7219e87490b23a3fbe3544f806133, clean isolated worktree.
- [x] Read AGENTS.md and both mandatory upgrade/browser recovery documents.
- [x] Verify stage chain: base -> system-tools -> runtimes -> dependencies -> final.
  No later stage replaces Node. The separate Go stage only supplies /usr/local/go.
- [x] Assigned sandbox runs the patched official node:24.22.1-bookworm-slim image:
  Node v24.22.1, bundled OpenSSL 3.5.9, Brotli 1.2.0, Linux arm64.
  These are sandbox observations, not claims about a rebuilt production image.
- [x] Preserve OpenClaw 2026.10.2 in Dockerfile, Compose build default and .env.example.
- [ ] Build/release verification and production rollout: **not performed here**.

Changing the base invalidates downstream layers. Existing unpinned apt packages,
CLI installers and application transitive packages can resolve differently on a
fresh build even though this patch changes only Node. Capture the built image
identity and actual tool/runtime versions before rollout; do not describe a future
full build as byte-for-byte identical apart from Node.

## Before a later rollout

1. Read the current operational notes and inspect live container/image/version,
   Coolify build arguments, gateway status, active jobs and actual state mounts.
   Production deployment authority is coolify, not the repository default main.
2. Take and verify a private full-state backup of all mounted state/config/workspace
   volumes plus necessary private environment/secrets; record prior image digest,
   production commit and container settings. Verify archive integrity and that
   recovery can restore consistent SQLite state, credentials and browser profiles.
   Do not commit backups or runtime configuration to this public repository.
3. Preserve current operational exceptions: browser-on-demand/watchdog pause marker,
   owned browser profile and login data, native embedding wrapper/index and idle
   unloading, intentionally paused auxiliary services, model inheritance and Opus
   specialization. Read current notes: the historical browser overview and memory
   degradation description are not proof of the current live state. Review bootstrap
   copying/starting repository watchdog helpers before replacing the live image;
   preserve current pause/on-demand behavior rather than silently re-enabling it.
4. Build without changing OPENCLAW_VERSION. Verify the resulting image really runs
   Node 24.22.1 and OpenClaw 2026.10.2, and inspect bundled Node OpenSSL/Brotli.
   No application schema migration is expected from this patch. If startup requests
   one, stop and investigate rather than invoking Doctor automatically.
5. Coordinate the Docker/Coolify-owned replacement and rollback window. Push only
   once to coolify and observe its automatic deployment; do not duplicate deployments.

## After rollout (must be observed, not assumed)

- [ ] Actual container image/version matches the intended security build; restart
  policy is unless-stopped; health is stable without a restart loop.
- [ ] Gateway readiness and local HTTP health succeed; configuration is accepted.
- [ ] Telegram polling and one authorized end-to-end user response work without
  duplicate polling conflicts or a second gateway owning the same state.
- [ ] Browser works on demand using the existing profile; CDP on the configured
  port works when requested. Restore/preserve idle pause behavior afterward.
- [ ] Local memory provider/index and compatible native embedding wrapper remain
  intact. Check current memory status/deep diagnostics and bounded semantic recall;
  preserve configured idle unloading. Do not switch to paid embeddings or erase
  indexes to silence a warning.
- [ ] An isolated model request succeeds with no tools and no channel delivery;
  global model inheritance and intentional specialist configuration remain intact.
- [ ] Scheduled work, job continuity and intentional auxiliary-service pauses are
  unchanged. Record real regressions and unfinished checks explicitly.

## Recovery ordering

If the new container is unhealthy, preserve logs and first inspect image/version,
configuration acceptance, gateway readiness and resource failures. Use Docker/Coolify
lifecycle controls, not native systemd/LaunchAgent lifecycle commands. Stop the
Docker-owned gateway before offline state work and do not run two owners against
the same SQLite databases. Revert to the recorded prior image only after confirming
that schemas were not advanced. For unexpected state/schema changes, use the
verified consistent full backup and the documented migration requirements; never
run an older bridge against newer SQLite schemas. A necessary maintenance container
must use --init, the same state mounts and privately supplied environment, with
hostname preserved across interrupted repair. Preserve original artifacts and do
not invent transcript ownership or clear indexes.

Coolify finished/HTTP 200 alone is not functional acceptance. Complete and record
all relevant post-rollout checks before marking the security task done.

## References

- https://nodejs.org/en/blog/vulnerability/october-2026-security-releases
- [Latest repository upgrade/recovery](openclaw-upgrade-2026-10-13.md)
- [Historical browser fallback](openclaw-browser-recovery-overview.md)

## Browser/embedding preservation preflight (repository checkpoint)

The live helper was inspected read-only. It matched the repository's legacy
helper, which did not implement the documented pause marker or --once option.
Bootstrap copied that helper over the persistent workspace and always launched
it. A persisted browser-watchdog.paused file alone therefore did not make the
old startup path safe. This is a concrete pre-rollout regression risk, not proof
that an old customized implementation was preserved.

The checkpoint fixes that path without starting or stopping live services:

- Bootstrap suppresses automatic browser startup while the persisted pause marker
  exists. The helper also checks it on entry and between monitoring iterations.
- Explicit --once starts/checks CDP once and exits; it does not clear the pause
  marker or change the existing profile path. Existing ready CDP is reused.
- Kernel file locks serialize launch decisions and deduplicate watchdog daemons;
  browser children do not retain those locks. Broad pkill-by-port is removed.
- The installer upgrades only the exact legacy helper checksum, or installs into
  an absent destination. Other existing helpers are kept byte-for-byte, including
  their file mode. It does not overwrite private operational customization.
- Stub-only tests exercise pause/no startup, --once, concurrent launch, daemon
  deduplication, profile argument preservation and fresh/legacy/custom installation.
  Run bash scripts/test-managed-browser.sh; the test runner may additionally supply
  LEGACY_BROWSER_HELPER pointing to the unchanged pre-checkpoint helper. No actual
  browser, gateway, package installation or production lifecycle is invoked.

The compatible native embedding wrapper was inspected read-only. It executes
its persisted compatibility loader/libraries and llama-server under
/data/.openclaw/tools/llama.cpp and appends --sleep-idle-seconds 60. The compatible
loader, native server and GGUF model are present under /data. The live container
mounts /data as the existing project-prefixed openclaw-data named volume; the
legacy config/workspace named volumes remain mounted separately. Thus those
embedding files and all state/index paths survive an image replacement provided
those exact mounts are retained. No wrapper, index, model configuration, provider
or runtime state was edited. Runtime unload/semantic behavior after replacement
remains a post-rollout check, not established by file persistence alone.

### Private backup and recovery handoff (not executed in preflight)

The repository has no complete full-state backup/restore utility. Its
scripts/migrate-to-data.sh is a layout migration helper, not a coherent backup.
Existing Docker volume/lifecycle tooling, tar, gzip, sha256sum and sqlite3 are
available; prefer the established private operational backup tooling if present.
Do not run the old bridge or Doctor to prepare this Node-only update.

Before self-rollout, the operator must discover/record the exact current mounts,
container/image identity and privately retained runtime environment. Preserve all
three existing named volumes: openclaw-data, openclaw-config and
openclaw-workspace, with their actual project prefixes. The data scope includes
active SQLite/WAL files, agent/plugin state, credentials, models/indexes, native
embedding loader/libraries/wrapper, pause marker, browser profiles/login data and
the persistent workspace. Capture any external bind-mounted paths separately if
the freshly discovered mount receipt contains them.

A coherent full-state copy or storage snapshot requires the authorized owning
Docker gateway to be stopped, with no second owner/writer or maintenance process
using the same state. Retain originals, ownership/mode metadata and the previous
image; keep backup material private and outside these volumes/public Git. Verify
archive/snapshot integrity and coverage, plus a restore/readability check of the
copied SQLite files in an isolated recovery location. An inventory/hash receipt
alone is not a full backup. No archive, snapshot, restore test or stop was performed
in this bounded source preflight.

If replacement fails, collect bounded logs, stop the new owner, and restore the
recorded old image against unchanged schemas. If state was unexpectedly migrated,
restore the verified coherent state backup rather than running the old image or
bridge against newer schemas. Preserve the same named mounts and hostname where
required by the retained update ledger. Never delete old state, browser logins,
indexes or backup artifacts to make startup pass. OpenClaw remains 2026.10.2;
any unexpected migration request is a blocker to investigate.
