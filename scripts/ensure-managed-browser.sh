#!/bin/bash
set -euo pipefail

OPENCLAW_STATE="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
CONFIG_FILE="${OPENCLAW_STATE}/openclaw.json"
LOG_FILE="${OPENCLAW_WORKSPACE:-/data/openclaw-workspace}/browser-monitor.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

config_jq() {
  jq -r "$1 // empty" "$CONFIG_FILE" 2>/dev/null
}

find_browser() {
  local configured
  configured="$(config_jq '.browser.executablePath')"
  if [ -n "$configured" ] && [ -x "$configured" ]; then
    echo "$configured"
    return 0
  fi

  for bin in /usr/bin/chromium /usr/bin/chromium-browser /usr/bin/google-chrome /usr/bin/google-chrome-stable; do
    if [ -x "$bin" ]; then
      echo "$bin"
      return 0
    fi
  done

  return 1
}

cdp_ready() {
  curl -fsS "http://127.0.0.1:${CDP_PORT}/json/version" >/dev/null 2>&1
}

clear_stale_profile_lock() {
  local lock_target=""
  if [ -L "${USER_DATA_DIR}/SingletonLock" ]; then
    lock_target="$(readlink "${USER_DATA_DIR}/SingletonLock" || true)"
  fi

  if [ -n "$lock_target" ]; then
    local lock_pid="${lock_target##*-}"
    if ! ps -p "$lock_pid" >/dev/null 2>&1; then
      log "Removing stale Chromium profile lock (${lock_target})"
      rm -f \
        "${USER_DATA_DIR}/SingletonLock" \
        "${USER_DATA_DIR}/SingletonCookie" \
        "${USER_DATA_DIR}/SingletonSocket"
    fi
  fi
}

start_browser() {
  local browser_bin="$1"
  local args=(
    "--remote-debugging-address=127.0.0.1"
    "--remote-debugging-port=${CDP_PORT}"
    "--user-data-dir=${USER_DATA_DIR}"
    "--disable-dev-shm-usage"
    "--no-first-run"
    "--no-default-browser-check"
    "--disable-background-networking"
    "--disable-sync"
    "about:blank"
  )

  if [ "$HEADLESS" = "true" ]; then
    args+=("--headless")
  fi
  if [ "$NO_SANDBOX" = "true" ]; then
    args+=("--no-sandbox")
  fi

  mkdir -p "$USER_DATA_DIR"
  pkill -f "remote-debugging-port=${CDP_PORT}" >/dev/null 2>&1 || true
  clear_stale_profile_lock
  nohup "$browser_bin" "${args[@]}" >>"$LOG_FILE" 2>&1 &
}

if [ ! -f "$CONFIG_FILE" ] || ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  exit 0
fi

CDP_PORT="$(config_jq '.browser.profiles.openclaw.cdpPort')"
HEADLESS="$(config_jq '.browser.headless')"
NO_SANDBOX="$(config_jq '.browser.noSandbox')"
USER_DATA_DIR="${OPENCLAW_STATE}/browser-profile-openclaw"

if [ -z "$CDP_PORT" ]; then
  exit 0
fi
if [ -z "$HEADLESS" ]; then
  HEADLESS="true"
fi
if [ -z "$NO_SANDBOX" ]; then
  NO_SANDBOX="true"
fi

log "Managed browser watchdog started (cdpPort=${CDP_PORT})"

while true; do
  if ! cdp_ready; then
    if browser_bin="$(find_browser)"; then
      log "Starting managed browser via ${browser_bin}"
      start_browser "$browser_bin"

      for _ in 1 2 3 4 5; do
        sleep 2
        if cdp_ready; then
          log "Managed browser CDP is ready on ${CDP_PORT}"
          break
        fi
      done

      if ! cdp_ready; then
        log "Managed browser CDP did not become ready on ${CDP_PORT}"
      fi
    else
      log "No Chromium-based browser binary found"
    fi
  fi

  sleep 30
done
