#!/bin/bash

# ============================================================
#  AD Connectivity Diagnostic Script for RHEL
# ============================================================

DOMAIN=""
REALM=""
DC=""
TEST_USER=""
VERBOSE=0
DC_LIST=""
WRITE_DEFAULT_CONFIG=0
INSTALL_DEPS=0

# Colors
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
WHITE="\033[97m"
BOLD="\033[1m"
RED="\033[31m"
RESET="\033[0m"

# -----------------------------
#  Default YAML Renderer
# -----------------------------
print_default_yaml() {
cat <<'EOF'
# AD Connectivity Diagnostic Tool Configuration
# ---------------------------------------------
# This file defines default AD connection parameters.
# CLI flags always override YAML values.
#
# domain:  AD DNS domain (lowercase)
# realm:   Kerberos realm (uppercase)
# dc:      Preferred domain controller
# user:    Kerberos principal for kinit testing
# verbose: true/false

domain: ad.example.com
realm: AD.EXAMPLE.COM
dc: dc01.ad.example.com
user: admin@AD.EXAMPLE.COM
verbose: false
EOF
}

# -----------------------------
#  YAML Config Loader
# -----------------------------
load_yaml_config() {
  local file="$1"
  [[ ! -f "$file" ]] && return 0

  while IFS=":" read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)

    case "$key" in
      domain)   DOMAIN="$value" ;;
      realm)    REALM="$value" ;;
      dc)       DC="$value" ;;
      user)     TEST_USER="$value" ;;
      verbose)  [[ "$value" == "true" ]] && VERBOSE=1 ;;
    esac
  done < <(grep -v '^\s*#' "$file" | grep ':')
}

# -----------------------------
#  OS Detection
# -----------------------------
detect_os() {
  local id="" ver=""
  if [[ -f /etc/os-release ]]; then
    id=$(. /etc/os-release && echo "$ID")
    ver=$(. /etc/os-release && echo "${VERSION_ID%%.*}")
  elif [[ -f /etc/redhat-release ]]; then
    grep -qi "Red Hat"   /etc/redhat-release && id="rhel"
    grep -qi "AlmaLinux" /etc/redhat-release && id="almalinux"
    grep -qi "Rocky"     /etc/redhat-release && id="rocky"
    ver=$(grep -oP '[0-9]+' /etc/redhat-release | head -1)
  fi
  echo "${id}:${ver}"
}

is_supported_os() {
  local pair id ver
  pair=$(detect_os)
  id="${pair%%:*}"
  ver="${pair##*:}"
  case "$id" in
    rhel|almalinux|rocky)
      [[ "$ver" == "8" || "$ver" == "9" ]] && return 0 ;;
  esac
  return 1
}

# -----------------------------
#  RHEL Repo Availability Check
# -----------------------------
check_rhel_repos() {
  local ver="$1"
  echo -e "${CYAN}Checking RHEL subscription and repo status...${RESET}"

  if ! command -v subscription-manager >/dev/null 2>&1; then
    echo -e "${RED}subscription-manager not found — cannot check repos.${RESET}"
    return 1
  fi

  local sub_status
  sub_status=$(subscription-manager status 2>&1)
  if ! echo "$sub_status" | grep -qi "Current"; then
    echo -e "${RED}System is not subscribed or subscription is invalid:${RESET}"
    echo "$sub_status"
    return 1
  fi
  echo -e "${GREEN}Subscription: OK${RESET}"

  local required_repos=(
    "rhel-${ver}-for-x86_64-baseos-rpms"
    "rhel-${ver}-for-x86_64-appstream-rpms"
  )
  local missing_repos=()
  local enabled_repos
  enabled_repos=$(subscription-manager repos --list-enabled 2>/dev/null \
    | grep 'Repo ID' | awk '{print $NF}')

  for repo in "${required_repos[@]}"; do
    if echo "$enabled_repos" | grep -q "$repo"; then
      echo -e "${GREEN}Repo enabled: $repo${RESET}"
    else
      echo -e "${RED}Repo NOT enabled: $repo${RESET}"
      missing_repos+=("$repo")
    fi
  done

  if [[ ${#missing_repos[@]} -gt 0 ]]; then
    echo -e "${YELLOW}To enable missing repos, run:${RESET}"
    for repo in "${missing_repos[@]}"; do
      echo "  subscription-manager repos --enable=$repo"
    done
    return 1
  fi

  echo -e "${GREEN}All required repos are enabled.${RESET}"
  return 0
}

# -----------------------------
#  Compact Help Screen (no scrolling)
# -----------------------------
usage() {
  echo -e "${CYAN}${BOLD}AD Connectivity Diagnostic Tool${RESET}"
  echo -e "Checks DNS, network, Kerberos, and AD domain controller health."
  echo
  echo -e "${CYAN}Usage:${RESET}"
  echo -e "  $0 -d DOMAIN -r REALM -c DC -u USER [options]"
  echo
  echo -e "${GREEN}Required:${RESET}"
  echo -e "  -d, --domain DOMAIN     AD DNS domain"
  echo -e "  -r, --realm REALM       Kerberos realm"
  echo -e "  -c, --dc HOSTNAME       Preferred domain controller"
  echo -e "  -u, --user PRINCIPAL    Kerberos principal"
  echo
  echo -e "${YELLOW}Optional:${RESET}"
  echo -e "      --install-deps      Install all required packages"
  echo -e "  -v, --verbose           Verbose output"
  echo -e "  -h, --help              Short help"
  echo -e "      --help-all          Full detailed help"
  echo -e "      --write-default-config  Write default YAML config"
  echo
  echo -e "${CYAN}Config file:${RESET}"
  echo -e "  ${MAGENTA}$HOME/.local/share/ad-connectivity/config.yaml${RESET}"
  echo -e "  CLI flags override YAML values."
  echo
  echo -e "${CYAN}Example:${RESET}"
  echo -e "  $0 -d ad.example.com -r AD.EXAMPLE.COM -c dc01 -u admin@AD.EXAMPLE.COM"
  echo
  exit 1
}

# -----------------------------
#  Full Help Screen (--help-all)
# -----------------------------
usage_long() {
  echo -e "${CYAN}${BOLD}AD Connectivity Diagnostic Tool — Full Help${RESET}"
  echo
  echo -e "${CYAN}Usage:${RESET}"
  echo -e "  $0 -d DOMAIN -r REALM -c DC -u USER [options]"
  echo
  echo -e "${GREEN}Required arguments:${RESET}"
  echo -e "  -d, --domain DOMAIN        AD DNS domain (e.g. ad.example.com)"
  echo -e "  -r, --realm REALM          Kerberos realm (e.g. AD.EXAMPLE.COM)"
  echo -e "  -c, --dc HOSTNAME          Preferred domain controller"
  echo -e "  -u, --user PRINCIPAL       Kerberos principal"
  echo
  echo -e "${YELLOW}Optional arguments:${RESET}"
  echo -e "      --install-deps       Install all required packages"
  echo -e "  -v, --verbose              Show detailed discovery and adcli output"
  echo -e "  -h, --help                 Show short help"
  echo -e "      --help-all             Show full help"
  echo -e "      --write-default-config Write default YAML config file"
  echo
  echo -e "${CYAN}Configuration:${RESET}"
  echo -e "  YAML config file:"
  echo -e "    ${MAGENTA}$HOME/.local/share/ad-connectivity/config.yaml${RESET}"
  echo -e "  CLI flags override YAML values."
  echo
  echo -e "${CYAN}System requirements:${RESET}"
  echo -e "  • RHEL 7/8/9 recommended"
  echo -e "  • Commands: nc, dig, kinit, adcli"
  echo -e "  • DNS must resolve SRV records"
  echo
  echo -e "${CYAN}What this tool does:${RESET}"
  echo -e "  • Discovers all domain controllers via DNS SRV"
  echo -e "  • Tests connectivity to *every* discovered DC"
  echo -e "  • Tests Kerberos authentication (kinit)"
  echo -e "  • Runs adcli discovery and join validation"
  echo -e "  • Performs forward, reverse, and SRV DNS checks"
  echo -e "  • Logs all commands for reproducibility"
  echo
  echo -e "${CYAN}Examples:${RESET}"
  echo -e "  $0 -d ad.example.com -r AD.EXAMPLE.COM -c dc01 -u admin@AD.EXAMPLE.COM"
  echo -e "  $0 --domain ad.example.com --realm AD.EXAMPLE.COM --dc dc01 --user admin@AD.EXAMPLE.COM"
  echo
  exit 0
}

# -----------------------------
#  Argument Parsing
# -----------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain) DOMAIN="$2"; shift 2 ;;
    -r|--realm) REALM="$2"; shift 2 ;;
    -c|--dc) DC="$2"; shift 2 ;;
    -u|--user) TEST_USER="$2"; shift 2 ;;
    -v|--verbose) VERBOSE=1; shift ;;
    --install-deps) INSTALL_DEPS=1; shift ;;
    --write-default-config) WRITE_DEFAULT_CONFIG=1; shift ;;
    --help-all) usage_long ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# -----------------------------
#  Install Required Packages
# -----------------------------
if [[ "$INSTALL_DEPS" == "1" ]]; then
  OS_PAIR=$(detect_os)
  OS_ID="${OS_PAIR%%:*}"
  OS_VER="${OS_PAIR##*:}"

  echo -e "${CYAN}Detected OS: ${OS_ID} ${OS_VER}${RESET}"

  if ! is_supported_os; then
    echo -e "${RED}Unsupported OS: ${OS_ID} ${OS_VER}. Supported: RHEL 8/9, AlmaLinux 8/9, Rocky Linux 8/9.${RESET}"
    exit 1
  fi

  # On RHEL, verify subscription and repos before attempting install
  if [[ "$OS_ID" == "rhel" ]]; then
    if ! check_rhel_repos "$OS_VER"; then
      echo -e "${RED}Repo check failed. Fix subscription/repos before installing.${RESET}"
      exit 1
    fi
  fi

  PACKAGES=(nmap-ncat bind-utils krb5-workstation adcli realmd)
  echo -e "${YELLOW}Packages:${RESET} ${PACKAGES[*]}"

  DNF_CMD=dnf
  if [[ $EUID -ne 0 ]]; then
    echo -e "${CYAN}Using sudo for installation${RESET}"
    DNF_CMD="sudo dnf"
  fi

  $DNF_CMD install -y "${PACKAGES[@]}"

  echo -e "${GREEN}All dependencies installed.${RESET}"
  exit 0
fi

# -----------------------------
#  Config File Handling
# -----------------------------
CONFIG_FILE="$HOME/.local/share/ad-connectivity/config.yaml"

if [[ "$WRITE_DEFAULT_CONFIG" == "1" ]]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  print_default_yaml > "$CONFIG_FILE"
  echo "Default config written to: $CONFIG_FILE"
  exit 0
fi

if [[ -f "$CONFIG_FILE" ]]; then
  load_yaml_config "$CONFIG_FILE"
fi

# -----------------------------
#  Validate Required Args
# -----------------------------
if [[ -z "$DOMAIN" || -z "$REALM" || -z "$DC" || -z "$TEST_USER" ]]; then
  echo "ERROR: Missing required arguments (or YAML config incomplete)."
  usage
fi

# -----------------------------
#  Logging Setup
# -----------------------------
LOGFILE="/var/log/ad-connectivity-$(date +%Y%m%d-%H%M%S).log"
touch "$LOGFILE" 2>/dev/null || LOGFILE="./ad-connectivity.log"

echo "Logging to: $LOGFILE"
echo "=== AD Connectivity Diagnostic Log ===" >> "$LOGFILE"
echo "Started: $(date)" >> "$LOGFILE"
echo >> "$LOGFILE"

# -----------------------------
#  Command Wrapper
# -----------------------------
run_cmd() {
  local CMD="$*"
  echo -e "${CYAN}▶ $CMD${RESET}"
  echo ">>> $CMD" >> "$LOGFILE"
  eval "$CMD" 2>&1 | tee -a "$LOGFILE"
  echo >> "$LOGFILE"
}

# -----------------------------
#  Prerequisite Checks
# -----------------------------
echo "=== Checking prerequisites ==="
echo "Log file: $LOGFILE"

REQUIRED_CMDS=(nc dig kinit adcli)

for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo -e "${RED}Missing command: $cmd${RESET}"
    MISSING=1
  else
    [[ $VERBOSE -eq 1 ]] && echo -e "${GREEN}Found: $cmd${RESET}"
  fi
done

if [[ $MISSING -eq 1 ]]; then
  echo "Install missing packages before running."
  exit 1
fi

# OS check
if ! is_supported_os; then
  OS_PAIR=$(detect_os)
  echo -e "${YELLOW}WARNING: Unsupported OS (${OS_PAIR%%:*} ${OS_PAIR##*:}). Tested on RHEL/AlmaLinux/Rocky 8 or 9.${RESET}"
fi

echo

# ============================================================
#  Functions
# ============================================================

discover_dcs() {
  echo "=== Discovering Domain Controllers via DNS SRV ==="
  DC_LIST=$(run_cmd dig +short _ldap._tcp.$DOMAIN SRV | awk '{print $4}' | sed 's/\.$//')

  if [[ -z "$DC_LIST" ]]; then
    echo "No domain controllers discovered via SRV records."
    return 1
  fi

  echo "Discovered DCs:"
  echo "$DC_LIST" | sed 's/^/  - /'
  echo
}

test_dc_connectivity() {
  echo "=== Testing Connectivity to All Discovered DCs ==="

  for dc in $DC_LIST; do
    echo "Testing DC: $dc"
    for port in 53 88 389 445 464; do
      echo -n "  Port $port: "
      run_cmd nc -z -w2 "$dc" "$port" && echo "OK" || echo "FAIL"
    done
    echo
  done
}

# ============================================================
#  Tests
# ============================================================

discover_dcs
if [[ $? -eq 0 ]]; then
  test_dc_connectivity
else
  echo "Skipping DC connectivity tests due to discovery failure."
fi

echo "=== Network Connectivity to Specified DC ($DC) ==="
for port in 53 88 389 445 464; do
  echo -n "Port $port: "
  run_cmd nc -z -w2 "$DC" "$port" && echo "OK" || echo "FAIL"
done

echo
echo "=== DNS Resolution ==="
run_cmd dig +short "$DC"

run_cmd dig +short _kerberos._tcp.$DOMAIN SRV
run_cmd dig +short _ldap._tcp.$DOMAIN SRV

echo
echo "=== Reverse Lookup ==="
IP=$(dig +short "$DC")
run_cmd dig +short -x "$IP"

echo
echo "=== Kerberos Test ==="
echo "Attempting kinit (you will be prompted for password)..."
run_cmd kinit -V "$TEST_USER"
run_cmd klist

echo
echo "=== adcli: Domain Discovery ==="
if adcli info "$DOMAIN" >/dev/null 2>&1; then
  echo "adcli info: OK"
  [[ $VERBOSE -eq 1 ]] && run_cmd adcli info "$DOMAIN"
else
  echo "adcli info: FAILED"
fi

echo
echo "=== adcli: Verbose Discovery ==="
run_cmd adcli info --verbose "$DOMAIN"

echo
echo "=== adcli: Join Test (if joined) ==="
if [ -f /etc/krb5.keytab ]; then
  run_cmd adcli testjoin -D "$DOMAIN"
else
  echo "No keytab found — skipping testjoin"
fi

echo
echo "=== Completed ==="
echo "Full log saved to: $LOGFILE"
