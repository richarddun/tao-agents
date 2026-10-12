#!/usr/bin/env bash
# ── System Sentinel: Inventory ────────────────────────────────────────
# Read-only inventory of a workstation's security posture. Makes no
# changes and requires no elevated privileges; checks that cannot be
# performed without admin are reported as "unknown".
#
# Output: JSON to stdout. Errors to stderr.
# Usage: ./inventory.sh [--pretty]

set -uo pipefail

PRETTY=0
[ "${1:-}" = "--pretty" ] && PRETTY=1

emit() { printf '%s\t%s\n' "$1" "$2"; }

# ── OS ────────────────────────────────────────────────────────────────
OS_NAME="unknown"; OS_FAMILY="unknown"; OS_VERSION="unknown"
case "$(uname -s)" in
    Darwin)
        OS_FAMILY="macos"; OS_NAME="macOS"
        OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo unknown)" ;;
    Linux)
        OS_FAMILY="linux"
        if [ -r /etc/os-release ]; then
            OS_NAME="$(. /etc/os-release; echo "${NAME:-Linux}")"
            OS_VERSION="$(. /etc/os-release; echo "${VERSION_ID:-unknown}")"
        else
            OS_NAME="Linux"; OS_VERSION="$(uname -r)"
        fi ;;
    *) OS_NAME="$(uname -s)"; OS_VERSION="$(uname -r)" ;;
esac

# ── Identity & load ───────────────────────────────────────────────────
HOSTNAME_V="$(hostname 2>/dev/null || echo unknown)"
KERNEL="$(uname -r 2>/dev/null || echo unknown)"
UPTIME_S="$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo unknown)"
LOADAVG="$(uptime 2>/dev/null | sed 's/.*load average[s]*: //' || echo unknown)"
CPU_COUNT="$( (nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null) || echo unknown)"

# ── Memory ────────────────────────────────────────────────────────────
MEM_TOTAL="unknown"; MEM_AVAIL="unknown"; SWAP_TOTAL="unknown"; SWAP_USED="unknown"
if [ -r /proc/meminfo ]; then
    MEM_TOTAL="$(awk '/^MemTotal:/{printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
    MEM_AVAIL="$(awk '/^MemAvailable:/{printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
    SWAP_TOTAL="$(awk '/^SwapTotal:/{printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
    SWAP_USED="$(awk '/^SwapTotal:/{t=$2}/^SwapFree:/{f=$2}END{if(t>0)printf "%.0f%%", (t-f)/t*100; else print "0%"}' /proc/meminfo)"
elif [ "$OS_FAMILY" = "macos" ]; then
    MEM_TOTAL="$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f GiB", $1/1073741824}' || echo unknown)"
fi

# ── Disk ──────────────────────────────────────────────────────────────
DISK="$(df -Pk / /home 2>/dev/null | awk 'NR>1{printf "%s=%s|", $6, $5}' || true)"

# ── Services / ports ──────────────────────────────────────────────────
RUNNING_SERVICES="unknown"
if command -v systemctl >/dev/null 2>&1; then
    RUNNING_SERVICES="$(systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null | wc -l | tr -d ' ')"
elif command -v launchctl >/dev/null 2>&1; then
    RUNNING_SERVICES="$(launchctl list 2>/dev/null | wc -l | tr -d ' ')"
fi

LISTENING="unknown"
if command -v ss >/dev/null 2>&1; then
    LISTENING="$(ss -tuln 2>/dev/null | awk 'NR>1{print $1"/"$5}' | sort -u | paste -sd, - || true)"
elif command -v netstat >/dev/null 2>&1; then
    LISTENING="$(netstat -an 2>/dev/null | awk '/LISTEN/{print $1"/"$4}' | sort -u | paste -sd, - || true)"
fi

# ── Firewall ──────────────────────────────────────────────────────────
FIREWALL="unknown"
if command -v ufw >/dev/null 2>&1; then
    FIREWALL="ufw:$(ufw status 2>/dev/null | head -1 | awk '{print $2}' || echo unknown)"
elif command -v firewall-cmd >/dev/null 2>&1; then
    FIREWALL="firewalld:$(firewall-cmd --state 2>/dev/null || echo unknown)"
elif [ "$OS_FAMILY" = "macos" ]; then
    FIREWALL="pf:$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo unknown)"
fi

# ── Disk encryption ───────────────────────────────────────────────────
ENCRYPTION="unknown"
if command -v lsblk >/dev/null 2>&1; then
    if lsblk -o FSTYPE 2>/dev/null | grep -q crypto; then ENCRYPTION="luks-present"; else ENCRYPTION="none-detected"; fi
elif [ "$OS_FAMILY" = "macos" ]; then
    ENCRYPTION="$(fdesetup status 2>/dev/null || echo unknown)"
fi

# ── Pending updates ───────────────────────────────────────────────────
UPDATES="unknown"
if command -v apt >/dev/null 2>&1; then
    UPDATES="$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)"
elif command -v dnf >/dev/null 2>&1; then
    UPDATES="$(dnf -q check-update 2>/dev/null | grep -c '^[a-zA-Z]' || true)"
elif [ "$OS_FAMILY" = "macos" ]; then
    UPDATES="$(softwareupdate -l 2>/dev/null | grep -c '\* Label' || true)"
fi

# ── Privileged users ──────────────────────────────────────────────────
PRIV_USERS="unknown"
if command -v getent >/dev/null 2>&1; then
    PRIV_USERS="$(getent group sudo wheel 2>/dev/null | awk -F: '{if($4!="")print $4}' | paste -sd, - || true)"
fi

# ── Assembled report ──────────────────────────────────────────────────
{
    emit os_name "$OS_NAME"
    emit os_family "$OS_FAMILY"
    emit os_version "$OS_VERSION"
    emit hostname "$HOSTNAME_V"
    emit kernel "$KERNEL"
    emit uptime_seconds "$UPTIME_S"
    emit load_average "$LOADAVG"
    emit cpu_count "$CPU_COUNT"
    emit memory_total "$MEM_TOTAL"
    emit memory_available "$MEM_AVAIL"
    emit swap_total "$SWAP_TOTAL"
    emit swap_used "$SWAP_USED"
    emit disks "$DISK"
    emit running_services "$RUNNING_SERVICES"
    emit listening "$LISTENING"
    emit firewall "$FIREWALL"
    emit disk_encryption "$ENCRYPTION"
    emit pending_updates "$UPDATES"
    emit privileged_users "$PRIV_USERS"
    emit privilege_level "$( [ "$(id -u)" -eq 0 ] && echo root || echo standard )"
} | PRETTY="$PRETTY" python3 -c '
import json, os, sys
d = {}
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    k, _, v = line.partition("\t")
    d[k] = v
out = {"inventory_version": "1.0", "fields": d}
json.dump(out, sys.stdout, indent=2 if os.environ.get("PRETTY") == "1" else None)
sys.stdout.write("\n")
'
