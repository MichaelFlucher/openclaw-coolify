#!/usr/bin/env bash
set -euo pipefail

# Fix Docker container egress when Docker is configured with:
#   "iptables": false
# by ensuring UFW before.rules has the required NAT and FORWARD rules.
#
# This script is idempotent and safe to run multiple times.

UFW_BEFORE_RULES="/etc/ufw/before.rules"
TS="$(date +%Y%m%d_%H%M%S)"

NAT_RULE='-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE'
FWD_RULE_IN='-A ufw-before-forward -i docker0 -j ACCEPT'
FWD_RULE_OUT='-A ufw-before-forward -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT'

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root: sudo $0"
    exit 1
  fi
}

require_file() {
  if [[ ! -f "${UFW_BEFORE_RULES}" ]]; then
    echo "Missing ${UFW_BEFORE_RULES}. Is UFW installed?"
    exit 1
  fi
}

ensure_rule_in_section() {
  local section_start="$1"
  local rule="$2"
  local file="$3"

  if grep -Fqx -- "${rule}" "${file}"; then
    echo "Rule already present: ${rule}"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v start="${section_start}" -v needle="${rule}" '
    BEGIN { in_section=0; inserted=0 }
    $0==start { in_section=1 }
    in_section && $0=="COMMIT" && inserted==0 {
      print needle
      inserted=1
    }
    { print }
    in_section && $0=="COMMIT" { in_section=0 }
  ' "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
  echo "Inserted rule: ${rule}"
}

main() {
  require_root
  require_file

  cp "${UFW_BEFORE_RULES}" "${UFW_BEFORE_RULES}.bak.${TS}"
  echo "Backup created: ${UFW_BEFORE_RULES}.bak.${TS}"

  ensure_rule_in_section "*nat" "${NAT_RULE}" "${UFW_BEFORE_RULES}"
  ensure_rule_in_section "*filter" "${FWD_RULE_IN}" "${UFW_BEFORE_RULES}"
  ensure_rule_in_section "*filter" "${FWD_RULE_OUT}" "${UFW_BEFORE_RULES}"

  echo
  echo "Reloading UFW..."
  ufw disable >/dev/null
  ufw --force enable >/dev/null
  ufw status verbose

  echo
  echo "Testing container DNS + egress..."
  docker run --rm alpine getent hosts deb.debian.org || true
  docker run --rm alpine sh -c "apk add --no-cache curl >/dev/null && curl -I https://deb.debian.org" || true

  echo
  echo "Done."
  echo "If DNS still fails, share:"
  echo "  - iptables -t nat -S"
  echo "  - iptables -S FORWARD"
}

main "$@"
