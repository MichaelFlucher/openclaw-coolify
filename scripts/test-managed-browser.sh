#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
tmp="$(mktemp -d)"
daemon=""
trap 'if [ -n "$daemon" ]; then kill "$daemon" 2>/dev/null || true; wait "$daemon" 2>/dev/null || true; fi; rm -rf "$tmp"' EXIT
mkdir -p "$tmp/state" "$tmp/workspace" "$tmp/bin"
export OPENCLAW_STATE_DIR="$tmp/state" OPENCLAW_WORKSPACE="$tmp/workspace" TEST_BROWSER="$tmp/bin/browser" TEST_READY="$tmp/ready" TEST_LAUNCHES="$tmp/launches"
export PATH="$tmp/bin:$PATH"
source scripts/install-managed-browser.sh
# Never replace a private/customized helper, including its file mode.
printf '# custom private helper\n' > "$tmp/custom"
chmod 600 "$tmp/custom"
custom_before="$(sha256sum "$tmp/custom")"
install_managed_browser scripts/ensure-managed-browser.sh "$tmp/custom"
[ "$custom_before" = "$(sha256sum "$tmp/custom")" ]
[ "$(stat -c %a "$tmp/custom")" = 600 ]
ln -s "$tmp/missing-private-helper" "$tmp/private-link"
install_managed_browser scripts/ensure-managed-browser.sh "$tmp/private-link"
[ -L "$tmp/private-link" ]
[ ! -e "$tmp/missing-private-helper" ]
install_managed_browser scripts/ensure-managed-browser.sh "$tmp/fresh"
cmp scripts/ensure-managed-browser.sh "$tmp/fresh"
# Use exact legacy source from the parent commit, supplied only by the test runner.
if [ -n "${LEGACY_BROWSER_HELPER:-}" ]; then
  cp "$LEGACY_BROWSER_HELPER" "$tmp/legacy"
  install_managed_browser scripts/ensure-managed-browser.sh "$tmp/legacy"
  cmp scripts/ensure-managed-browser.sh "$tmp/legacy"
fi
# Paused automatic startup must not need config, launch tools, or clear the marker.
touch "$tmp/state/browser-watchdog.paused"
bash scripts/ensure-managed-browser.sh
[ ! -e "$tmp/workspace/browser-monitor.log" ]
[ -e "$tmp/state/browser-watchdog.paused" ]
cat > "$tmp/bin/jq" <<'STUB'
#!/usr/bin/env bash
case "$2" in
  *executablePath*) echo "$TEST_BROWSER" ;;
  *cdpPort*) echo 18800 ;;
  *) echo true ;;
esac
STUB
cat > "$tmp/bin/curl" <<'STUB'
#!/usr/bin/env bash
[ -e "$TEST_READY" ]
STUB
cat > "$tmp/bin/browser" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_LAUNCHES"
touch "$TEST_READY"
STUB
cat > "$tmp/bin/sleep" <<'STUB'
#!/usr/bin/env bash
/bin/sleep 0.05
STUB
chmod +x "$tmp/bin/"*
touch "$tmp/state/openclaw.json"
# Explicit --once bypasses pause and concurrent calls launch exactly once.
bash scripts/ensure-managed-browser.sh --once & a=$!
bash scripts/ensure-managed-browser.sh --once & b=$!
wait "$a"; wait "$b"
[ "$(wc -l < "$TEST_LAUNCHES")" = 1 ]
grep -q -- "--user-data-dir=$tmp/state/browser-profile-openclaw" "$TEST_LAUNCHES"
[ -e "$tmp/state/browser-watchdog.paused" ]
bash scripts/ensure-managed-browser.sh --once
[ "$(wc -l < "$TEST_LAUNCHES")" = 1 ]
# Only one automatic daemon may own the watchdog, even with healthy CDP.
rm "$tmp/state/browser-watchdog.paused"
: > "$tmp/workspace/browser-monitor.log"
bash scripts/ensure-managed-browser.sh & daemon=$!
for _ in {1..30}; do
  if grep -q 'watchdog started' "$tmp/workspace/browser-monitor.log"; then break; fi
  /bin/sleep 0.05
done
bash scripts/ensure-managed-browser.sh
[ "$(grep -c 'watchdog started' "$tmp/workspace/browser-monitor.log")" = 1 ]
# Creating the persistent pause marker also settles a running daemon.
touch "$tmp/state/browser-watchdog.paused"
wait "$daemon"; daemon=""
[ "$(wc -l < "$TEST_LAUNCHES")" = 1 ]
echo 'PASS: pause, on-demand, profile preservation, install/custom/legacy, concurrent launch and daemon deduplication'
