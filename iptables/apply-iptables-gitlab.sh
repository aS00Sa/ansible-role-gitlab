#!/usr/bin/env bash
set -euo pipefail

##https://docs.gitlab.com/administration/package_information/defaults/
##GitLab Rails	Yes	Port		80 or 443
##GitLab Shell	Yes	Port		22
##NGINX status	Yes	Port		8060

PORTS_TCP="${PORTS_TCP:-22,80,443,8060,24819}"
ALLOW_ICMP="${ALLOW_ICMP:-1}"
ALLOW_ICMPV6="${ALLOW_ICMPV6:-1}"

usage() {
  cat <<'EOF'
Apply strict inbound firewall rules for a GitLab host.

Defaults:
  - INPUT/FORWARD policy: DROP
  - OUTPUT policy: ACCEPT
  - Allow: loopback, ESTABLISHED/RELATED, NEW tcp to PORTS_TCP (default 22,80,443,8060,24819)
  - Optionally allow ICMP/ICMPv6 (enabled by default)
  - Save via netfilter-persistent if available

Environment variables:
  PORTS_TCP="22,80,443,8060,24819"
  ALLOW_ICMP=1|0
  ALLOW_ICMPV6=1|0

Examples:
  sudo PORTS_TCP="22,443" ./scripts/apply-iptables-gitlab.sh
  sudo ALLOW_ICMP=0 ALLOW_ICMPV6=0 ./scripts/apply-iptables-gitlab.sh
EOF
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "ERROR: must be run as root (use sudo)." >&2
    exit 1
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

timestamp() { date -u +"%Y%m%dT%H%M%SZ"; }

backup_rules() {
  local ts outdir
  ts="$(timestamp)"
  outdir="/root/iptables-backups"
  mkdir -p "$outdir"

  if have_cmd iptables-save; then
    iptables-save > "${outdir}/rules.v4.${ts}.bak"
  fi
  if have_cmd ip6tables-save; then
    ip6tables-save > "${outdir}/rules.v6.${ts}.bak"
  fi
  echo "Backed up current rules to ${outdir}/rules.v[46].${ts}.bak (if commands exist)."
}

apply_v4() {
  if ! have_cmd iptables; then
    echo "WARN: iptables not found; skipping IPv4 rules." >&2
    return 0
  fi

  iptables -w -F
  iptables -w -X

  iptables -w -P INPUT DROP
  iptables -w -P FORWARD DROP
  iptables -w -P OUTPUT ACCEPT

  iptables -w -A INPUT -i lo -j ACCEPT
  iptables -w -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  if [[ "${ALLOW_ICMP}" == "1" ]]; then
    iptables -w -A INPUT -p icmp -j ACCEPT
  fi

  iptables -w -A INPUT -p tcp -m multiport --dports "${PORTS_TCP}" -m conntrack --ctstate NEW -j ACCEPT
}

apply_v6() {
  if ! have_cmd ip6tables; then
    echo "WARN: ip6tables not found; skipping IPv6 rules." >&2
    return 0
  fi

  ip6tables -w -F
  ip6tables -w -X

  ip6tables -w -P INPUT DROP
  ip6tables -w -P FORWARD DROP
  ip6tables -w -P OUTPUT ACCEPT

  ip6tables -w -A INPUT -i lo -j ACCEPT
  ip6tables -w -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  if [[ "${ALLOW_ICMPV6}" == "1" ]]; then
    ip6tables -w -A INPUT -p ipv6-icmp -j ACCEPT
  fi

  ip6tables -w -A INPUT -p tcp -m multiport --dports "${PORTS_TCP}" -m conntrack --ctstate NEW -j ACCEPT
}

persist_if_possible() {
  if have_cmd netfilter-persistent; then
    netfilter-persistent save
    echo "Saved rules via netfilter-persistent."
    return 0
  fi

  if have_cmd systemctl && systemctl list-unit-files 2>/dev/null | grep -q '^netfilter-persistent\.service'; then
    systemctl enable --now netfilter-persistent >/dev/null 2>&1 || true
    netfilter-persistent save
    echo "Enabled and saved rules via netfilter-persistent."
    return 0
  fi

  echo "NOTE: netfilter-persistent not found; rules applied but not saved." >&2
  echo "      On Debian/Ubuntu, install 'iptables-persistent' to persist across reboot." >&2
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  require_root
  backup_rules

  apply_v4
  apply_v6
  persist_if_possible

  echo "Done. Allowed inbound TCP ports: ${PORTS_TCP}"
}

main "$@"
