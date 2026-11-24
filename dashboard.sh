#!/usr/bin/env bash
# Linux system dashboard for Fedora and Ubuntu Server.
# Each section is a function. A missing command prints a message
# and the rest of the dashboard still runs.

if [ -z "${BASH_VERSION:-}" ]; then
  printf '%s\n' "dashboard.sh must be run with bash, for example: ./dashboard.sh" >&2
  exit 1
fi

set -u
set -o pipefail

export LC_ALL=C
export LANG=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || SCRIPT_DIR="."

# Thresholds. dashboard.conf can replace these. The file is parsed as
# data and is never sourced, so a config line cannot run a command.
CPU_WARN=70
CPU_CRIT=90
MEM_WARN=75
MEM_CRIT=90
SWAP_WARN=40
SWAP_CRIT=75
DISK_WARN=80
DISK_CRIT=90
LOAD_WARN_PER_CPU=0.70
LOAD_CRIT_PER_CPU=1.00
CONN_WARN=100
CONN_CRIT=300

WATCH=0
LOG_FILE=""
CONFIG_ARG=""
NO_COLOR_FLAG=0
CONFIG_PATH="built-in defaults"
CURSOR_HIDDEN=0

BOLD=""
DIM=""
RESET=""
GREEN=""
YELLOW=""
RED=""
CYAN=""

usage() {
  cat <<'EOF'
Usage: ./dashboard.sh [options]

Show health and status for a Fedora or Ubuntu Server machine.

Options:
  --watch           Clear and redraw every 5 seconds
  --log FILE        Append a plain-text snapshot to FILE
  --config FILE     Read thresholds from FILE
                    (default: dashboard.conf next to this script)
  --no-color        Do not use ANSI colors
  -h, --help        Show this help

Examples:
  chmod +x dashboard.sh
  ./dashboard.sh
  ./dashboard.sh --watch
  ./dashboard.sh --log "$HOME/dashboard.log"
  ./dashboard.sh --config ./dashboard.conf --no-color
EOF
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

init_colors() {
  if (( NO_COLOR_FLAG )) || [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
    return 0
  fi
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RED=$'\033[31m'
  CYAN=$'\033[36m'
}

paint() {
  local level="$1"
  local text="$2"
  local color=""
  case "$level" in
    ok) color="$GREEN" ;;
    warn) color="$YELLOW" ;;
    crit) color="$RED" ;;
  esac
  if [[ -n "$color" ]]; then
    printf '%s%s%s' "$color" "$text" "$RESET"
  else
    printf '%s' "$text"
  fi
}

status_word() {
  case "$1" in
    ok) printf 'OK' ;;
    warn) printf 'WARNING' ;;
    crit) printf 'CRITICAL' ;;
    *) printf 'UNKNOWN' ;;
  esac
}

unavailable() {
  printf '  %s\n' "$(paint warn "[unavailable] $1")"
}

section() {
  printf '\n%s== %s ==%s\n' "${BOLD}${CYAN}" "$1" "$RESET"
}

kv() {
  printf '  %-16s %s\n' "$1" "$2"
}

level_for() {
  awk -v v="$1" -v w="$2" -v c="$3" 'BEGIN {
    if ((v + 0) >= (c + 0)) print "crit"
    else if ((v + 0) >= (w + 0)) print "warn"
    else print "ok"
  }'
}

assign_threshold() {
  local key="$1"
  local val="$2"
  case "$key" in
    CPU_WARN|CPU_CRIT|MEM_WARN|MEM_CRIT|SWAP_WARN|SWAP_CRIT|DISK_WARN|DISK_CRIT|CONN_WARN|CONN_CRIT)
      [[ "$val" =~ ^[0-9]+$ ]] || return 1
      printf -v "$key" '%s' "$val"
      ;;
    LOAD_WARN_PER_CPU|LOAD_CRIT_PER_CPU)
      [[ "$val" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
      printf -v "$key" '%s' "$val"
      ;;
    *)
      return 1
      ;;
  esac
}

load_config() {
  local file="$1"
  local line="" key="" val=""
  if [[ ! -f "$file" ]]; then
    CONFIG_PATH="built-in defaults"
    return 0
  fi
  CONFIG_PATH="$file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    line=${line%%#*}
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      key=${BASH_REMATCH[1]}
      val=${BASH_REMATCH[2]}
      val="${val#"${val%%[![:space:]]*}"}"
      val="${val%"${val##*[![:space:]]}"}"
      val=${val#\"}
      val=${val%\"}
      if ! assign_threshold "$key" "$val"; then
        printf 'Warning: ignored config line: %s\n' "$line" >&2
      fi
    else
      printf 'Warning: ignored config line: %s\n' "$line" >&2
    fi
  done < "$file"
}

check_threshold_order() {
  local pair="" name="" w="" c=""
  local pairs=(
    "CPU:${CPU_WARN}:${CPU_CRIT}"
    "MEM:${MEM_WARN}:${MEM_CRIT}"
    "SWAP:${SWAP_WARN}:${SWAP_CRIT}"
    "DISK:${DISK_WARN}:${DISK_CRIT}"
    "LOAD:${LOAD_WARN_PER_CPU}:${LOAD_CRIT_PER_CPU}"
    "CONN:${CONN_WARN}:${CONN_CRIT}"
  )
  for pair in "${pairs[@]}"; do
    IFS=: read -r name w c <<<"$pair"
    if awk -v w="$w" -v c="$c" 'BEGIN { exit !((w + 0) >= (c + 0)) }'; then
      printf 'Warning: %s warning threshold (%s) is not below the critical threshold (%s).\n' \
        "$name" "$w" "$c" >&2
    fi
  done
}

os_id() {
  local id=""
  if [[ -r /etc/os-release ]]; then
    id=$(awk -F= 'tolower($1) == "id" {
      gsub(/"/, "", $2)
      print tolower($2)
      exit
    }' /etc/os-release)
  fi
  printf '%s\n' "$id"
}

os_pretty() {
  local pretty=""
  if [[ -r /etc/os-release ]]; then
    pretty=$(awk -F= 'tolower($1) == "pretty_name" {
      gsub(/"/, "", $2)
      print $2
      exit
    }' /etc/os-release)
  fi
  if [[ -z "$pretty" ]]; then
    if have_cmd uname; then
      pretty=$(uname -sr 2>/dev/null || true)
    else
      pretty="Unknown operating system"
    fi
  fi
  printf '%s\n' "$pretty"
}

cpu_count() {
  local n=""
  if have_cmd nproc; then
    n=$(nproc 2>/dev/null || true)
  fi
  if [[ -z "$n" || "$n" == "0" ]] && [[ -r /proc/cpuinfo ]]; then
    n=$(awk '/^processor/ { c++ } END { print c + 0 }' /proc/cpuinfo)
  fi
  if [[ -z "$n" || "$n" == "0" ]]; then
    n=1
  fi
  printf '%s\n' "$n"
}

# Sample one short interval. Idle includes iowait, which matches the
# usual "CPU is waiting" reading rather than counting wait as busy.
cpu_usage_percent() {
  local t1="" i1="" t2="" i2=""
  [[ -r /proc/stat ]] || return 1
  read -r t1 i1 < <(awk '/^cpu / { print ($2+$3+$4+$5+$6+$7+$8+$9), ($5+$6) }' /proc/stat) || true
  [[ -n "$t1" && -n "$i1" ]] || return 1
  sleep 0.25 || return 1
  read -r t2 i2 < <(awk '/^cpu / { print ($2+$3+$4+$5+$6+$7+$8+$9), ($5+$6) }' /proc/stat) || true
  [[ -n "$t2" && -n "$i2" ]] || return 1
  awk -v t1="$t1" -v i1="$i1" -v t2="$t2" -v i2="$i2" 'BEGIN {
    dt = t2 - t1
    di = i2 - i1
    if (dt <= 0) { printf "0.0"; exit }
    u = (dt - di) / dt * 100
    if (u < 0) u = 0
    if (u > 100) u = 100
    printf "%.1f", u
  }'
}

human_bytes() {
  awk -v b="$1" 'BEGIN {
    split("B KB MB GB TB PB", units, " ")
    v = b + 0
    i = 1
    while (v >= 1024 && i < 6) {
      v = v / 1024
      i++
    }
    printf "%.1f %s", v, units[i]
  }'
}

bar() {
  local pct="$1"
  local warn="$2"
  local crit="$3"
  local width="${4:-24}"
  local lvl="" filled="" i=0 glyph="" dashes="" num="" word=""
  lvl=$(level_for "$pct" "$warn" "$crit")
  filled=$(awk -v p="$pct" -v w="$width" 'BEGIN {
    if ((p + 0) < 0) p = 0
    if ((p + 0) > 100) p = 100
    printf "%d", int((p + 0) * w / 100 + 0.5)
  }')
  [[ "$filled" =~ ^[0-9]+$ ]] || filled=0
  for ((i = 0; i < filled; i++)); do glyph+="#"; done
  for ((i = filled; i < width; i++)); do dashes+="-"; done
  num=$(awk -v p="$pct" 'BEGIN { printf "%5.1f", p + 0 }')
  word=$(status_word "$lvl")
  printf '%s[%s%s%s]%s %s %s' \
    "$DIM" \
    "$(paint "$lvl" "$glyph")" \
    "$DIM" \
    "$dashes" \
    "$RESET" \
    "$(paint "$lvl" "${num}%")" \
    "$(paint "$lvl" "$word")"
}

print_banner() {
  printf '%sLINUX SYSTEM DASHBOARD%s\n' "$BOLD" "$RESET"
  printf '  %s\n' "$(os_pretty)"
  printf '  %s   %s   %s\n' \
    "$(paint ok "OK healthy")" \
    "$(paint warn "WARNING review")" \
    "$(paint crit "CRITICAL act")"
}

print_footer() {
  printf '\n%sThresholds: %s%s\n' "$DIM" "$CONFIG_PATH" "$RESET"
  printf '%sCPU %s/%s   MEM %s/%s   SWAP %s/%s   DISK %s/%s   LOAD/CPU %s/%s   CONN %s/%s%s\n' \
    "$DIM" \
    "$CPU_WARN" "$CPU_CRIT" \
    "$MEM_WARN" "$MEM_CRIT" \
    "$SWAP_WARN" "$SWAP_CRIT" \
    "$DISK_WARN" "$DISK_CRIT" \
    "$LOAD_WARN_PER_CPU" "$LOAD_CRIT_PER_CPU" \
    "$CONN_WARN" "$CONN_CRIT" \
    "$RESET"
  if (( WATCH == 0 )); then
    printf '%sRun ./dashboard.sh --watch to refresh every 5 seconds.%s\n' "$DIM" "$RESET"
  fi
}

show_system_info() {
  local host="unknown" kern="" up="" now=""
  section "SYSTEM INFO"
  if have_cmd hostname; then
    host=$(hostname 2>/dev/null || true)
  fi
  if [[ -z "$host" && -r /etc/hostname ]]; then
    host=$(< /etc/hostname)
    host=${host%$'\r'}
  fi
  if [[ -z "$host" ]]; then
    if have_cmd uname; then
      host=$(uname -n 2>/dev/null || true)
    fi
  fi
  [[ -n "$host" ]] || host="unknown"

  if have_cmd uname; then
    kern=$(uname -a 2>/dev/null || true)
  fi
  [[ -n "$kern" ]] || kern="[unavailable] Command 'uname' was not found."

  if have_cmd uptime; then
    up=$(uptime -p 2>/dev/null || true)
    if [[ -z "$up" ]]; then
      up=$(uptime 2>/dev/null || true)
    fi
  fi
  if [[ -z "$up" && -r /proc/uptime ]]; then
    up=$(awk '{
      s = int($1)
      d = int(s / 86400)
      h = int((s % 86400) / 3600)
      m = int((s % 3600) / 60)
      printf "%d days, %d hours, %d minutes", d, h, m
    }' /proc/uptime)
  fi
  [[ -n "$up" ]] || up="[unavailable] Could not read uptime."

  now=$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || true)
  [[ -n "$now" ]] || now="[unavailable] Command 'date' was not found."

  kv "Hostname" "$host"
  kv "Kernel" "$kern"
  kv "Uptime" "$up"
  kv "Date/time" "$now"
}

show_cpu_memory() {
  local load1="" load5="" load15="" cpus="" lpc="" lvl="" cpu=""
  local mt=0 mu=0 mf=0 ma=0 st=0 su=0 sf=0
  local mem_line="" mem_pct="" swap_pct=""
  section "CPU & MEMORY"

  if [[ -r /proc/loadavg ]]; then
    # -t keeps a stuck /proc read from freezing the dashboard.
    read -t 1 -r load1 load5 load15 _ < /proc/loadavg || load1=""
  elif have_cmd uptime; then
    local uptime_line="" loads=""
    uptime_line=$(uptime 2>/dev/null || true)
    loads=$(printf '%s\n' "$uptime_line" | awk -F'load average:' 'NF > 1 { print $2 }')
    loads=${loads//,/}
    read -r load1 load5 load15 <<<"$loads" || true
  fi

  cpus=$(cpu_count)
  if [[ -n "$load1" && -n "$load5" && -n "$load15" ]]; then
    lpc=$(awk -v l="$load1" -v n="$cpus" 'BEGIN {
      if ((n + 0) < 1) n = 1
      printf "%.2f", (l + 0) / n
    }')
    lvl=$(level_for "$lpc" "$LOAD_WARN_PER_CPU" "$LOAD_CRIT_PER_CPU")
    printf '  %-16s %s  (%s CPUs, %s per CPU)\n' \
      "Load average" \
      "$(paint "$lvl" "$load1  $load5  $load15") $(paint "$lvl" "$(status_word "$lvl")")" \
      "$cpus" \
      "$lpc"
  else
    unavailable "Load average is not available from /proc/loadavg or uptime."
  fi

  if cpu=$(cpu_usage_percent); then
    printf '  %-16s ' "CPU usage"
    bar "$cpu" "$CPU_WARN" "$CPU_CRIT" 24
    printf '\n'
  else
    unavailable "Could not sample CPU usage from /proc/stat."
  fi

  if have_cmd free; then
    mem_line=$(free -b 2>/dev/null | awk '
      /^Mem:/ {
        mt = $2; mu = $3; mf = $4
        if (NF >= 7) ma = $7
        else ma = $4
      }
      /^Swap:/ { st = $2; su = $3; sf = $4 }
      END {
        if (mt == "") exit 1
        printf "%s %s %s %s %s %s %s\n", mt+0, mu+0, mf+0, ma+0, st+0, su+0, sf+0
      }
    ') || mem_line=""
  fi
  if [[ -z "$mem_line" && -r /proc/meminfo ]]; then
    mem_line=$(awk '
      $1 == "MemTotal:" { mt = $2 * 1024 }
      $1 == "MemFree:" { mf = $2 * 1024 }
      $1 == "MemAvailable:" { ma = $2 * 1024 }
      $1 == "SwapTotal:" { st = $2 * 1024 }
      $1 == "SwapFree:" { sf = $2 * 1024 }
      END {
        if (mt == "") exit 1
        if (ma == "") ma = mf + 0
        mu = mt - ma
        if (mu < 0) mu = 0
        su = (st + 0) - (sf + 0)
        if (su < 0) su = 0
        printf "%s %s %s %s %s %s %s\n", mt, mu, mf+0, ma, st+0, su, sf+0
      }
    ' /proc/meminfo) || mem_line=""
  fi
  if [[ -z "$mem_line" ]]; then
    unavailable "Memory figures need 'free' or /proc/meminfo."
    return
  fi
  read -r mt mu mf ma st su sf <<<"$mem_line"

  mem_pct=$(awk -v u="$mu" -v t="$mt" 'BEGIN {
    if ((t + 0) <= 0) printf "0.0"
    else printf "%.1f", (u + 0) / t * 100
  }')
  printf '  %-16s ' "Memory"
  bar "$mem_pct" "$MEM_WARN" "$MEM_CRIT" 24
  printf '\n'
  printf '    total %-12s used %-12s free %s\n' \
    "$(human_bytes "$mt")" "$(human_bytes "$mu")" "$(human_bytes "$mf")"
  printf '    available %s\n' "$(human_bytes "$ma")"

  if awk -v t="$st" 'BEGIN { exit !((t + 0) <= 0) }'; then
    printf '  %-16s %s\n' "Swap" "$(paint ok "none configured")"
  else
    swap_pct=$(awk -v u="$su" -v t="$st" 'BEGIN {
      if ((t + 0) <= 0) printf "0.0"
      else printf "%.1f", (u + 0) / t * 100
    }')
    printf '  %-16s ' "Swap"
    bar "$swap_pct" "$SWAP_WARN" "$SWAP_CRIT" 24
    printf '\n'
    printf '    total %-12s used %-12s free %s\n' \
      "$(human_bytes "$st")" "$(human_bytes "$su")" "$(human_bytes "$sf")"
  fi
}

show_disk() {
  local raw="" line="" pct="" lvl="" colored=""
  local root_pct="" fullest_pct=-1 fullest_mount=""
  section "DISK USAGE"
  if ! have_cmd df; then
    unavailable "Command 'df' was not found."
    return
  fi

  raw=$(df -h --output=source,size,used,avail,pcent,target 2>/dev/null || true)
  if [[ -z "$raw" ]]; then
    raw=$(df -h 2>/dev/null || true)
  fi
  if [[ -z "$raw" ]]; then
    unavailable "df could not read mounted filesystems."
    return
  fi

  while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    if [[ "$line" == Filesystem* ]]; then
      printf '  %s\n' "$line"
      continue
    fi
    pct=""
    if [[ "$line" =~ ([0-9]+)% ]]; then
      pct=${BASH_REMATCH[1]}
      lvl=$(level_for "$pct" "$DISK_WARN" "$DISK_CRIT")
      colored=$(paint "$lvl" "${pct}%")
      printf '  %s\n' "${line/"${pct}%"/$colored}"
      if (( pct > fullest_pct )); then
        fullest_pct=$pct
        fullest_mount=$(awk '{ print $NF }' <<<"$line")
      fi
      if [[ "$line" =~ [[:space:]]/$ ]]; then
        root_pct=$pct
      fi
    else
      printf '  %s\n' "$line"
    fi
  done <<<"$raw"

  if [[ -n "$root_pct" || "$fullest_pct" -ge 0 ]]; then
    printf '\n  Capacity\n'
  fi
  if [[ -n "$root_pct" ]]; then
    printf '  %-16s ' "Root (/)"
    bar "$root_pct" "$DISK_WARN" "$DISK_CRIT" 24
    printf '\n'
  fi
  if [[ "$fullest_pct" -ge 0 && "$fullest_mount" != "/" ]]; then
    printf '  %-16s ' "Fullest"
    bar "$fullest_pct" "$DISK_WARN" "$DISK_CRIT" 24
    printf '  %s\n' "$fullest_mount"
  fi
}

print_top() {
  local label="$1"
  local field="$2"
  local out="" first="" reason=""
  if ! out=$(ps -eo pid,user,pcpu,pmem,comm --sort=-"$field" 2>&1); then
    reason=$(printf '%s\n' "$out" | awk 'NR == 1 { print; exit }')
    unavailable "ps could not list processes by ${label}. ${reason}"
    return
  fi
  first=$(printf '%s\n' "$out" | awk 'NR == 1 { print; exit }')
  if [[ "$first" != *PID* ]]; then
    unavailable "ps output was not recognized for ${label}."
    return
  fi
  printf '  Top 5 by %s\n' "$label"
  printf '%s\n' "$out" | awk 'NR <= 6 { printf "  %s\n", $0 }'
}

show_top_processes() {
  section "TOP PROCESSES"
  if ! have_cmd ps; then
    unavailable "Command 'ps' was not found."
    return
  fi
  print_top "CPU" "pcpu"
  printf '\n'
  print_top "memory" "pmem"
}

le_hex_ip() {
  local h="${1,,}"
  if [[ ! "$h" =~ ^[0-9a-f]{8}$ ]]; then
    printf '%s\n' "unknown"
    return 1
  fi
  printf '%d.%d.%d.%d\n' \
    "$((16#${h:6:2}))" \
    "$((16#${h:4:2}))" \
    "$((16#${h:2:2}))" \
    "$((16#${h:0:2}))"
}

read_default_route_proc() {
  local iface="" dest="" gw="" flags=""
  [[ -r /proc/net/route ]] || return 1
  while read -r iface dest gw flags _; do
    [[ "$iface" == "Iface" ]] && continue
    if [[ "$dest" == "00000000" ]]; then
      printf '%s %s\n' "$iface" "$(le_hex_ip "$gw")"
      return 0
    fi
  done < /proc/net/route
  return 1
}

count_established() {
  local n="" proc_count=0 f="" part=0
  if have_cmd ss; then
    if n=$(ss -tn state established 2>/dev/null); then
      printf '%s\n' "$n" | awk 'NR > 1 { c++ } END { print c + 0 }'
      return 0
    fi
  fi
  if [[ -r /proc/net/tcp || -r /proc/net/tcp6 ]]; then
    for f in /proc/net/tcp /proc/net/tcp6; do
      [[ -r "$f" ]] || continue
      part=$(awk 'NR > 1 && $4 == "01" { c++ } END { print c + 0 }' "$f")
      proc_count=$((proc_count + part))
    done
    printf '%s\n' "$proc_count"
    return 0
  fi
  return 1
}

show_network() {
  local route="" iface="" gw="" addr="" global_line="" conns="" clvl="" proc_route=""
  section "NETWORK"

  if have_cmd ip; then
    route=$(ip -4 route show default 2>/dev/null | awk 'NR == 1 { print; exit }') || true
    if [[ -n "$route" ]]; then
      iface=$(awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }' <<<"$route")
      gw=$(awk '{ for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }' <<<"$route")
    fi
    if [[ -n "$iface" ]]; then
      addr=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk 'NR == 1 { print $4; exit }') || true
    fi
    if [[ -z "$addr" ]]; then
      global_line=$(ip -4 -o addr show scope global 2>/dev/null | awk 'NR == 1 { print; exit }') || true
      if [[ -n "$global_line" ]]; then
        [[ -n "$iface" ]] || iface=$(awk '{ print $2 }' <<<"$global_line")
        addr=$(awk '{ print $4 }' <<<"$global_line")
      fi
    fi
  else
    unavailable "Command 'ip' was not found. Falling back to /proc and hostname."
    if proc_route=$(read_default_route_proc 2>/dev/null); then
      iface=${proc_route%% *}
      gw=${proc_route#* }
    fi
    if have_cmd hostname; then
      addr=$(hostname -I 2>/dev/null | awk '{ print $1 }') || true
    fi
  fi

  [[ -n "$iface" ]] || iface="none"
  [[ -n "$gw" ]] || gw="none"
  [[ -n "$addr" ]] || addr="none"
  kv "Interface" "$iface"
  kv "IPv4" "$addr"
  kv "Gateway" "$gw"

  if conns=$(count_established); then
    clvl=$(level_for "$conns" "$CONN_WARN" "$CONN_CRIT")
    printf '  %-16s %s TCP  %s\n' \
      "Established" \
      "$(paint "$clvl" "$conns")" \
      "$(paint "$clvl" "$(status_word "$clvl")")"
  else
    unavailable "Could not count established TCP connections."
  fi
}

# Fedora units are sshd, crond, and firewalld.
# Ubuntu Server units are ssh, cron, and ufw.
# Try the native name first so the two VMs show the difference.
check_service() {
  local label="$1"
  local cand="" found="" state="" lvl="warn" tried=""
  shift
  for cand in "$@"; do
    if systemctl cat "${cand}.service" >/dev/null 2>&1; then
      found="$cand"
      break
    fi
  done
  if [[ -z "$found" ]]; then
    tried="$*"
    tried=${tried// /, }
    printf '  %-12s %s\n' "$label" "$(paint warn "not installed (tried ${tried})")"
    return 1
  fi
  state=$(systemctl is-active "${found}.service" 2>/dev/null || true)
  [[ -n "$state" ]] || state="unknown"
  case "$state" in
    active) lvl="ok" ;;
    failed) lvl="crit" ;;
  esac
  printf '  %-12s %-20s %s\n' "$label" "${found}.service" "$(paint "$lvl" "$state")"
  return 0
}

show_services() {
  local missing=0
  section "SERVICES"
  if ! have_cmd systemctl; then
    unavailable "Command 'systemctl' was not found. Service status needs systemd."
    return
  fi
  case "$(os_id)" in
    ubuntu|debian|linuxmint|pop)
      check_service "SSH" ssh sshd || missing=$((missing + 1))
      check_service "Cron" cron crond || missing=$((missing + 1))
      check_service "Firewall" ufw firewalld nftables || missing=$((missing + 1))
      ;;
    *)
      check_service "SSH" sshd ssh || missing=$((missing + 1))
      check_service "Cron" crond cron || missing=$((missing + 1))
      check_service "Firewall" firewalld ufw nftables || missing=$((missing + 1))
      ;;
  esac
  if (( missing > 0 )); then
    check_service "Journal" systemd-journald || true
  fi
}

show_logins() {
  local online="" recent=""
  section "LOGINS & USERS"
  printf '  Currently logged in\n'
  if have_cmd who; then
    online=$(who 2>&1) || true
    if [[ -z "$online" ]]; then
      printf '  %s\n' "(nobody is logged in)"
    else
      printf '%s\n' "$online" | sed 's/^/  /'
    fi
  else
    unavailable "Command 'who' was not found."
  fi

  printf '\n  Last 3 login attempts\n'
  if have_cmd last; then
    recent=$(last -n 3 2>&1) || true
    if [[ -z "$recent" ]]; then
      printf '  %s\n' "(no login records)"
    else
      printf '%s\n' "$recent" | sed 's/^/  /'
    fi
  else
    unavailable "Command 'last' was not found."
  fi
}

show_log_errors() {
  local out=""
  section "RECENT LOG ERRORS"
  if ! have_cmd journalctl; then
    unavailable "Command 'journalctl' was not found."
    if [[ -r /var/log/syslog ]]; then
      printf '  Last matching lines from /var/log/syslog\n'
      grep -Ei 'error|fail|crit' /var/log/syslog 2>/dev/null | tail -n 5 | sed 's/^/  /' || true
    fi
    return
  fi
  if ! out=$(journalctl -p err -n 5 --no-pager -o short-iso 2>&1); then
    printf '%s\n' "$out" | sed 's/^/  /'
    return
  fi
  if [[ -z "$out" || "$out" == *"-- No entries --"* ]]; then
    printf '  %s\n' "No error-priority journal entries."
    return
  fi
  printf '%s\n' "$out" | sed 's/^/  /'
}

render() {
  print_banner
  show_system_info
  show_cpu_memory
  show_disk
  show_top_processes
  show_network
  show_services
  show_logins
  show_log_errors
  print_footer
}

strip_ansi() {
  sed -E $'s/\033\\[[0-9;]*[[:alpha:]]//g'
}

# Colors are chosen in the parent shell. render runs in a command
# substitution, where stdout is not a terminal.
emit() {
  local body=""
  body=$(render)
  printf '%s\n' "$body"
  if [[ -n "$LOG_FILE" ]]; then
    if ! {
      printf '\n===== %s =====\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
      printf '%s\n' "$body" | strip_ansi
    } >>"$LOG_FILE"; then
      printf 'Could not append to log file: %s\n' "$LOG_FILE" >&2
    fi
  fi
}

hide_cursor() {
  # tput can block when stdout is not a terminal.
  [[ -t 1 ]] || return 0
  if have_cmd tput && tput civis >/dev/null 2>&1; then
    CURSOR_HIDDEN=1
  fi
}

show_cursor() {
  if (( CURSOR_HIDDEN )); then
    tput cnorm >/dev/null 2>&1 || true
    CURSOR_HIDDEN=0
  fi
}

# A loop with clear, not an outer watch(1) call. That keeps --log and
# colors working, and it does not start another copy with --watch.
watch_loop() {
  if ! have_cmd sleep; then
    printf '%s\n' "[unavailable] Command 'sleep' was not found, so --watch cannot wait." >&2
    exit 1
  fi
  hide_cursor
  while true; do
    if [[ -t 1 ]] && have_cmd clear; then
      clear
    else
      printf '\033[H\033[2J'
    fi
    emit
    printf '\n  Refreshing every 5 seconds. Press Ctrl+C to stop.\n'
    sleep 5
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --watch)
        WATCH=1
        ;;
      --no-color)
        NO_COLOR_FLAG=1
        ;;
      --log)
        if [[ $# -lt 2 || "$2" == --* ]]; then
          printf '%s\n' "Error: --log needs a file path." >&2
          exit 1
        fi
        LOG_FILE=$2
        shift
        ;;
      --config)
        if [[ $# -lt 2 || "$2" == --* ]]; then
          printf '%s\n' "Error: --config needs a file path." >&2
          exit 1
        fi
        CONFIG_ARG=$2
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Error: unknown option: %s\n' "$1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  local conf=""
  parse_args "$@"
  init_colors
  conf="$CONFIG_ARG"
  if [[ -z "$conf" && -n "${DASHBOARD_CONFIG:-}" ]]; then
    conf="$DASHBOARD_CONFIG"
  fi
  if [[ -z "$conf" ]]; then
    conf="${SCRIPT_DIR}/dashboard.conf"
  fi
  if [[ -n "$CONFIG_ARG" && ! -f "$CONFIG_ARG" ]]; then
    printf 'Error: config file not found: %s\n' "$CONFIG_ARG" >&2
    exit 1
  fi
  load_config "$conf"
  check_threshold_order
  if (( WATCH )); then
    watch_loop
  else
    emit
  fi
}

trap 'show_cursor' EXIT
trap 'printf "\nStopped.\n"; exit 0' INT TERM
main "$@"
