# Node.js security base update — 2026-10-21

## Scope

Pin the Docker base from the moving node:lts-bookworm-slim tag to
node:24.22.1-bookworm-slim for the October 2026 Node.js security release.
OpenClaw stays pinned to 2026.10.2. This is not an OpenClaw runtime upgrade;
no configuration-schema migration, Doctor repair, bridge release, model change,
index deletion, or state-file repair is requested or performed.

Only the Dockerfile Node base line and this document change. Compose environment,
volumes, restart policy, bootstrap/browser scripts, global model inheritance,
Go 1.23.4 copy stage and application version pins remain untouched.

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
