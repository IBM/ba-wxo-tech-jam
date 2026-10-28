#!/usr/bin/env bash
# setup-adk-event.sh - Install the watsonx Orchestrate ADK CLI and connect it to the wxO tenant (on event day).
#
# Automates "Appendix: ADK CLI Setup Guide" in
# lab-guides/Setup & Event Credentials.md (sections A.1 - A.5).
#
# Verifies Python and the ADK CLI (installing if needed), then registers and
# activates the wxO environment using credentials from labs/event.env.
#
# Every dependency is checked first (existence AND version); nothing is installed
# or changed if it is already in place and recent enough.
#
# Usage:
#   ./labs/adk-setup/setup-adk-event.sh [options]
#
# Options:
#   -e, --email <address>   Your event e-mail address. Looks up your SOR user ID and password from the
#                           Jam User Management app and writes them to sorUsername / sorPassword in labs/event.env.
#                           Without -e, non-blank sorUsername AND sorPassword in labs/event.env are used as they are
#                           (a message says so); otherwise the e-mail address is asked for. An address that does not look
#                           valid has to be confirmed or replaced. An address that is not registered in SOR stops the script.
#                           The script also stops when labs/event.env does not exist (start it from the right workspace).
#   -l, --location <name>   Jam location used for the lookup            (default: APAC)
#   -d, --dir <path>        Lab workspace directory holding the .venv   (default: ./wxo-labs)
#   -n, --env-name <name>   ADK environment name                        (default: trinity-lab)
#   -s, --sor-url <url>     SOR base URL               (labs/event.env → env SOR_URL → prompted); saved to sorURL in labs/event.env
#   -u, --url <url>         wxO service instance URL   (labs/event.env → env WXO_URL → prompted)
#   -k, --api-key <key>     wxO API key                (labs/event.env → env WXO_API_KEY → prompted, hidden)
#                           Saved to wxoAPIKey in labs/event.env (only when it differs) so --activate can reuse it.
#   -a, --activate          Only refresh the wxO token (e.g. after it expired): re-activates the registered environment
#                           with the wxoAPIKey from labs/event.env (asks for it only if missing) and exits. Skips the
#                           Python/ADK checks and every other prompt.
#   -r, --reset             Only removes the registered wxO environment and blanks wxoAPIKey, sorUsername and
#                           sorPassword in labs/event.env, then exits. It does not install anything, ask questions or
#                           create a new environment: run the script again without --reset to register it afresh.
#                           sorURL and wxoServiceInstanceURL are left untouched.
#   -y, --yes               Do not ask before installing Homebrew or Python
#   -h, --help              Show this help
#
# Anything still missing (e-mail, API key, URL) is asked for once, up front, before the install steps start.
# Tip: fill in labs/event.env once and run this script without -u/-k — it reads the file automatically.
# If you do pass -u/-k explicitly, those values take precedence over event.env.

set -euo pipefail

MIN_PYTHON="3.12"
MIN_ADK="2.15"
PACKAGE="ibm-watsonx-orchestrate"

CRED_URL="https://jam-usermanagement-jam-usermanagement.swat-dev-roks-vpc-02-464887bc828751e1b00625ca9211fbca-0000.eu-de.containers.appdomain.cloud/UserManagement/RetrieveUserCredential.jsp"
CRED_USER_TYPE="CP4BA"
DEFAULT_KEYGEN_URL="https://github.com/IBM/ba-wxo-tech-jam/blob/main/lab-guides/Generate%20Your%20wxO%20API%20Key.md"
WXO_KEYGEN_URL=""   # wxoKeyGenUrl from labs/event.env; DEFAULT_KEYGEN_URL when missing
EMAIL=""
LOCATION="APAC"
WORKSPACE_DIR="./wxo-labs"
ENV_NAME="trinity-lab"
# Environment variables are only a fallback (below event.env), so stash them and start empty.
_ENV_SOR_URL="${SOR_URL:-}"; _ENV_WXO_URL="${WXO_URL:-}"; _ENV_WXO_API_KEY="${WXO_API_KEY:-}"
SOR_URL=""
SOR_URL_FROM_FILE=""
WXO_URL=""
WXO_URL_FROM_FILE=""
WXO_API_KEY_FROM_FILE=""
API_KEY_FROM_CLI=0
HAVE_SOR_USER=0
HAVE_SOR_PASS=0
WXO_API_KEY=""
RESET=0
ACTIVATE=0
ASSUME_YES=0
ENV_CHANGES=()

# ---------------------------------------------------------------- helpers
info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*" >&2; }
# hilite <text> -> bold green: for the messages the user must not miss
hilite() { printf '\033[1;32m[INFO] %s\033[0m\n' "$*"; }
fail() { printf '\033[31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# ver_ge A B -> success when version A >= version B (numeric, dot-separated)
ver_ge() {
  local IFS=. i
  local -a a=($1) b=($2)
  for i in 0 1 2; do
    local x="${a[i]:-0}" y="${b[i]:-0}"
    x="${x//[^0-9]/}"; y="${y//[^0-9]/}"
    (( ${x:-0} > ${y:-0} )) && return 0
    (( ${x:-0} < ${y:-0} )) && return 1
  done
  return 0
}

# python_version <exe> -> prints "major.minor.patch" or nothing when unusable
python_version() {
  "$1" -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null || true
}

# find_python -> prints path of the first interpreter that satisfies MIN_PYTHON
find_python() {
  local cand path ver
  for cand in python3.12 python3.13 python3 python; do
    path="$(command -v "$cand" 2>/dev/null || true)"
    [[ -n "$path" ]] || continue
    ver="$(python_version "$path")"
    [[ -n "$ver" ]] || continue
    if ver_ge "$ver" "$MIN_PYTHON"; then
      echo "$path"
      return 0
    fi
    warn "Found $path ($ver) but Python $MIN_PYTHON or later is required." >&2
  done
  return 1
}

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# run_root <cmd...> -> run as root, using sudo when not already root
run_root() {
  if [[ $EUID -eq 0 ]]; then "$@"
  elif command -v sudo >/dev/null 2>&1; then sudo "$@"
  else fail "Root privileges are required to run '$*' but sudo is not available."
  fi
}

# pkg_install <pkg...> -> install with the distribution's package manager
pkg_install() {
  if command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update -y && run_root apt-get install -y "$@"
  elif command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y "$@"
  elif command -v pacman >/dev/null 2>&1; then
    run_root pacman -Sy --noconfirm "$@"
  else
    return 1
  fi
}

# install_python_linux -> install Python 3.12+ (package manager first, then uv; no sudo for uv)
install_python_linux() {
  if command -v apt-get >/dev/null 2>&1; then
    confirm "Install Python with apt (needs sudo)?" && pkg_install python3 python3-pip python3-venv || true
  elif command -v dnf >/dev/null 2>&1; then
    confirm "Install Python with dnf (needs sudo)?" && pkg_install python3 python3-pip || true
  elif command -v pacman >/dev/null 2>&1; then
    confirm "Install Python with pacman (needs sudo)?" && pkg_install python python-pip || true
  fi
  if find_python >/dev/null 2>&1; then return 0; fi

  warn "The distribution's Python is older than $MIN_PYTHON (or unavailable)."
  if ! command -v uv >/dev/null 2>&1; then
    confirm "Install uv (https://astral.sh/uv, user-space, no sudo) to get Python $MIN_PYTHON?" \
      || fail "Python $MIN_PYTHON+ is required. See https://developer.watson-orchestrate.ibm.com/getting_started/installing"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    command -v uv >/dev/null 2>&1 || fail "uv was installed but is not on PATH. Open a new terminal and re-run this script."
  fi
  uv python install 3.12
  local uvpy
  uvpy="$(uv python find 3.12)" || fail "uv could not locate the Python 3.12 it just installed."
  export PATH="$(dirname "$uvpy"):$PATH"
}

# report_env_changes -> list the event.env entries this run changed (secrets masked). Runs on every exit
# (trap below), so the list is also shown when the script fails after it had already updated the file.
report_env_changes() {
  [[ ${#ENV_CHANGES[@]} -gt 0 ]] || return 0
  local entry
  echo
  info "${EVENT_ENV_FILE:-event.env} has been updated with the following changes:"
  for entry in "${ENV_CHANGES[@]}"; do echo "    - $entry"; done
}
trap report_env_changes EXIT

# set_env_value <key> <value> <file> -> set key=value in an env file (replace the line, or append).
# A real change (old value differs from the new one) is remembered for report_env_changes.
set_env_value() {
  local key="$1" val="$2" file="$3" tmp old shown
  [[ -f "$file" ]] || : > "$file"
  old="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | head -n1 | sed -e 's/^[^=]*=//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true)"
  if [[ "$old" != "$val" ]]; then
    if [[ -z "$val" ]]; then
      shown="$key (cleared)"
    elif [[ "$key" == "sorPassword" || "$key" == "wxoAPIKey" ]]; then
      shown="$key=********"
    else
      shown="$key=$val"
    fi
    ENV_CHANGES+=("$shown")
  fi
  tmp="$(mktemp)"
  KEY="$key" VAL="$val" awk '
    BEGIN { k = ENVIRON["KEY"]; v = ENVIRON["VAL"]; done = 0 }
    $0 ~ ("^[[:space:]]*" k "[[:space:]]*=") { print k "=" v; done = 1; next }
    { print }
    END { if (!done) print k "=" v }
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

# valid_email <address> -> success when the address looks like name@domain.tld
valid_email() {
  local re="^[A-Za-z0-9._%+'-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$"
  [[ "$1" =~ $re ]]
}

# check_email -> make sure $EMAIL looks valid. If it does not, ask the user to confirm it is the right address
# (accept it as is) or to enter a new one, until the address is valid or confirmed.
check_email() {
  local reply
  while ! valid_email "$EMAIL"; do
    warn "'$EMAIL' does not look like a valid e-mail address."
    read -r -p "Is it the right e-mail address? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] && return 0
    read -r -p "Event e-mail address (used to look up sorUsername/sorPassword): " EMAIL
    [[ -n "$EMAIL" ]] || fail "An e-mail address is required. Pass -e or enter it when asked."
  done
}

# show_keygen_hint <sor-user> -> tell the user how to generate the wxO API key (only when no key is known yet,
# because the key is asked for right after)
show_keygen_hint() {
  [[ -z "$WXO_API_KEY" ]] || return 0
  echo
  hilite "Please write down your SOR user name: $1"
  hilite "Follow this link to generate your wxO API key: ${WXO_KEYGEN_URL:-$DEFAULT_KEYGEN_URL}"
  hilite "Use your SOR user name ($1) as the API key name."
  hilite "Once the API key is generated, enter it below to continue the ADK setup."
}

# fetch_sor_credentials -> POST the e-mail to the Jam User Management app and store the
# returned user ID / password in event.env (sorUsername / sorPassword)
fetch_sor_credentials() {
  local html user pass
  info "Retrieving SOR credentials for $EMAIL ($LOCATION)"
  html="$(curl -fsS -m 30 \
      --data-urlencode "EmailAddressTextbox=$EMAIL" \
      --data-urlencode "jamLocationCombox=$LOCATION" \
      --data-urlencode "UserType=$CRED_USER_TYPE" \
      "$CRED_URL" | tr -d '\r')" \
    || fail "Could not retrieve credentials from the Jam User Management app (check network/VPN, the e-mail address and --location)."
  if printf '%s' "$html" | grep -qi 'registration list'; then
    fail "Could not find the e-mail address $EMAIL in SOR. Please contact the tech-jam team to register the e-mail address and try again."
  fi
  user="$(printf '%s\n' "$html" | sed -n 's|.*<b>User ID:[[:space:]]*</b>[[:space:]]*\([^<]*\)<.*|\1|p' | head -n1 | sed 's/[[:space:]]*$//')"
  pass="$(printf '%s\n' "$html" | sed -n 's|.*<b>Password:[[:space:]]*</b>[[:space:]]*\([^<]*\)<.*|\1|p' | head -n1 | sed 's/[[:space:]]*$//')"
  [[ -n "$user" && -n "$pass" ]] \
    || fail "No user ID / password found in the response for $EMAIL. Check the e-mail address and --location (Americas / APAC)."
  set_env_value sorUsername "$user" "$EVENT_ENV_FILE"
  set_env_value sorPassword "$pass" "$EVENT_ENV_FILE"
  ok "Saved sorUsername=$user and sorPassword=******** to $EVENT_ENV_FILE"
  show_keygen_hint "$user"
}

# save_api_key -> keep the API key in event.env (only when it differs from what is stored) so that
# --activate can refresh the token later without asking for it again
save_api_key() {
  [[ -n "$WXO_API_KEY" && "$WXO_API_KEY" != "$WXO_API_KEY_FROM_FILE" ]] || return 0
  set_env_value wxoAPIKey "$WXO_API_KEY" "$EVENT_ENV_FILE"
  WXO_API_KEY_FROM_FILE="$WXO_API_KEY"
  ok "Saved wxoAPIKey to $EVENT_ENV_FILE"
}

# resolve_api_key -> decide where the wxO API key comes from and say so:
# -k on the command line, else a non-blank wxoAPIKey in event.env, else WXO_API_KEY, else ask.
resolve_api_key() {
  if [[ -n "$WXO_API_KEY" ]]; then
    if [[ $API_KEY_FROM_CLI -eq 1 ]]; then
      info "Will use the wxO API key from the command line"
    elif [[ -n "$WXO_API_KEY_FROM_FILE" ]]; then
      info "Will use the wxO API key (wxoAPIKey) from $EVENT_ENV_FILE"
    else
      info "Will use the wxO API key from the WXO_API_KEY environment variable"
    fi
  else
    read -r -s -p "wxO API key (wxoAPIKey; input hidden): " WXO_API_KEY
    echo
  fi
}

# env_registered -> success when the ADK environment $ENV_NAME is registered ($ORCH must be set)
env_registered() { "$ORCH" env list 2>/dev/null | grep -Eq "(^|[^A-Za-z0-9_-])${ENV_NAME}($|[^A-Za-z0-9_-])"; }

# ---------------------------------------------------------------- event.env
EVENT_ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/event.env"
# Read labs/event.env (one directory up from this script) and populate SOR_URL, WXO_URL
# and WXO_API_KEY from it when they were not already set via CLI or environment.
# Precedence: CLI param > event.env (sorURL / wxoServiceInstanceURL / wxoAPIKey) > SOR_URL / WXO_URL / WXO_API_KEY env vars > interactive prompt.
# (event.env is read before arg parsing; the arg-parser overwrites when params are supplied.)
_EVENT_ENV="$(dirname "$0")/../event.env"
if [[ -f "$_EVENT_ENV" ]]; then
    while IFS= read -r _line || [[ -n "$_line" ]]; do
        [[ "$_line" =~ ^[[:space:]]*# ]] && continue
        [[ "$_line" != *=* ]] && continue
        _k="${_line%%=*}"; _v="${_line#*=}"
        _k="${_k// /}"; _v="${_v// /}"
        [[ -z "$_v" ]] && continue
        [[ "$_k" == "sorUsername" ]] && HAVE_SOR_USER=1
        [[ "$_k" == "sorPassword" ]] && HAVE_SOR_PASS=1
        [[ "$_k" == "wxoKeyGenUrl" ]] && WXO_KEYGEN_URL="$_v"
        [[ "$_k" == "sorURL"                && -z "$SOR_URL"     ]] && { SOR_URL="$_v"; SOR_URL_FROM_FILE="$_v"; }
        [[ "$_k" == "wxoServiceInstanceURL" && -z "$WXO_URL"     ]] && { WXO_URL="$_v"; WXO_URL_FROM_FILE="$_v"; }
        [[ "$_k" == "wxoAPIKey"             && -z "$WXO_API_KEY" ]] && { WXO_API_KEY="$_v"; WXO_API_KEY_FROM_FILE="$_v"; }
    done < "$_EVENT_ENV"
fi
unset _EVENT_ENV _line _k _v

# ---------------------------------------------------------------- arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e|--email)    EMAIL="${2:?missing value for $1}"; shift 2 ;;
    -l|--location) LOCATION="${2:?missing value for $1}"; shift 2 ;;
    -d|--dir)      WORKSPACE_DIR="${2:?missing value for $1}"; shift 2 ;;
    -n|--env-name) ENV_NAME="${2:?missing value for $1}"; shift 2 ;;
    -s|--sor-url)  SOR_URL="${2:?missing value for $1}"; shift 2 ;;
    -u|--url)      WXO_URL="${2:?missing value for $1}"; shift 2 ;;
    -k|--api-key)  WXO_API_KEY="${2:?missing value for $1}"; API_KEY_FROM_CLI=1; shift 2 ;;
    -a|--activate) ACTIVATE=1; shift ;;
    -r|--reset)    RESET=1; shift ;;
    -y|--yes)      ASSUME_YES=1; shift ;;
    -h|--help)     usage ;;
    *)             fail "Unknown option: $1 (use --help)" ;;
  esac
done

[[ $ACTIVATE -eq 0 || $RESET -eq 0 ]] || fail "--activate and --reset cannot be combined."

[[ -f "$EVENT_ENV_FILE" ]] \
  || fail "labs/event.env was not found (looked for $EVENT_ENV_FILE). The script must be started from the right workspace: run it from the Tech Jam repository, e.g. ./labs/adk-setup/setup-adk-event.sh."

# ---------------------------------------------------------------- --reset (remove only)
# Removes the registered environment and blanks the saved API key and SOR credentials, then stops. Nothing is installed,
# asked or re-created; run the script again without --reset to register the environment afresh.
if [[ $RESET -eq 1 ]]; then
  info "Resetting: removing environment '$ENV_NAME'"
  ORCH="$WORKSPACE_DIR/.venv/bin/orchestrate"
  if [[ ! -x "$ORCH" ]]; then
    ORCH="$(command -v orchestrate 2>/dev/null || true)"
  fi
  if [[ -z "$ORCH" ]]; then
    ok "orchestrate CLI not found - no environment to remove"
  elif env_registered; then
    "$ORCH" env remove -n "$ENV_NAME" || fail "Could not remove environment '$ENV_NAME'."
    ok "Environment '$ENV_NAME' removed"
  else
    ok "Environment '$ENV_NAME' is not registered - nothing to remove"
  fi
  if [[ -n "$WXO_API_KEY_FROM_FILE" ]]; then
    set_env_value wxoAPIKey "" "$EVENT_ENV_FILE"
    ok "Cleared wxoAPIKey in $EVENT_ENV_FILE"
  fi
  if [[ $HAVE_SOR_USER -eq 1 ]]; then
    set_env_value sorUsername "" "$EVENT_ENV_FILE"
    ok "Cleared sorUsername in $EVENT_ENV_FILE"
  fi
  if [[ $HAVE_SOR_PASS -eq 1 ]]; then
    set_env_value sorPassword "" "$EVENT_ENV_FILE"
    ok "Cleared sorPassword in $EVENT_ENV_FILE"
  fi
  echo "  Run ./setup-adk-event.sh again (without --reset) to register the environment."
  exit 0
fi

# Environment-variable fallback: only for values neither the CLI nor event.env provided.
SOR_URL="${SOR_URL:-$_ENV_SOR_URL}"; WXO_URL="${WXO_URL:-$_ENV_WXO_URL}"; WXO_API_KEY="${WXO_API_KEY:-$_ENV_WXO_API_KEY}"
unset _ENV_SOR_URL _ENV_WXO_URL _ENV_WXO_API_KEY

# ---------------------------------------------------------------- --activate (token refresh only)
# Tokens expire after 2 hours of inactivity. Re-activating the already registered environment only
# needs the API key, so skip the Python/ADK checks and every other prompt.
if [[ $ACTIVATE -eq 1 ]]; then
  info "Refreshing the wxO token for environment '$ENV_NAME'"
  ORCH="$WORKSPACE_DIR/.venv/bin/orchestrate"
  if [[ ! -x "$ORCH" ]]; then
    ORCH="$(command -v orchestrate 2>/dev/null || true)"
    [[ -n "$ORCH" ]] || fail "orchestrate CLI not found in $WORKSPACE_DIR/.venv or on PATH. Run this script without --activate first to install the ADK."
  fi
  env_registered || fail "Environment '$ENV_NAME' is not registered. Run this script without --activate first."
  resolve_api_key
  [[ -n "$WXO_API_KEY" ]] || fail "An API key is required. Pass -k or enter it when asked."
  "$ORCH" env activate "$ENV_NAME" -a "$WXO_API_KEY" || fail "Could not activate environment '$ENV_NAME' - check the API key."
  ok "Environment '$ENV_NAME' activated"
  save_api_key
  "$ORCH" agents list >/dev/null || fail "'orchestrate agents list' failed - check the API key and wxoServiceInstanceURL."
  ok "Connected to wxO"
  exit 0
fi

# ---------------------------------------------------------------- collect inputs
# Ask for everything that is still missing up front, so the rest of the script runs unattended.
# Skipped for values already supplied via CLI options, labs/event.env or environment variables.
# The e-mail is only needed to look up sorUsername/sorPassword: with -e the credentials are fetched again;
# without -e they are used from event.env when both are non-blank, otherwise the e-mail is asked for.
# The address is checked and looked up right away, so an unregistered address stops the script before anything else is asked.
if [[ -n "$EMAIL" ]]; then
  :   # -e given: sorUsername/sorPassword are fetched and overwrite the file values
elif [[ $HAVE_SOR_USER -eq 1 && $HAVE_SOR_PASS -eq 1 ]]; then
  info "Will use sorUsername and sorPassword from $EVENT_ENV_FILE"
else
  info "sorUsername and sorPassword are not set in $EVENT_ENV_FILE - they will be looked up from your e-mail address."
  read -r -p "Event e-mail address (used to look up sorUsername/sorPassword): " EMAIL
  [[ -n "$EMAIL" ]] || fail "An e-mail address is required: sorUsername/sorPassword are not set in $EVENT_ENV_FILE. Pass -e or enter it when asked."
fi
if [[ -n "$EMAIL" ]]; then
  check_email
  fetch_sor_credentials
fi
if [[ -z "$SOR_URL" ]]; then
  read -r -p "SOR base URL (sorURL; Enter to skip): " SOR_URL
fi
resolve_api_key
[[ -n "$WXO_API_KEY" ]] || fail "A wxO API key is required: wxoAPIKey is not set in $EVENT_ENV_FILE. Pass -k or enter it when asked."
if [[ -z "$WXO_URL" ]]; then
  read -r -p "wxO service instance URL (wxoServiceInstanceURL; Enter to skip if the environment is already registered): " WXO_URL
fi

if [[ -n "$SOR_URL" && "$SOR_URL" != "$SOR_URL_FROM_FILE" ]]; then
  set_env_value sorURL "$SOR_URL" "$EVENT_ENV_FILE"
  ok "Saved sorURL=$SOR_URL to $EVENT_ENV_FILE"
fi
if [[ -n "$WXO_URL" && "$WXO_URL" != "$WXO_URL_FROM_FILE" ]]; then
  set_env_value wxoServiceInstanceURL "$WXO_URL" "$EVENT_ENV_FILE"
  ok "Saved wxoServiceInstanceURL=$WXO_URL to $EVENT_ENV_FILE"
fi

# ---------------------------------------------------------------- 1. Python
info "Step 1/5: checking Python $MIN_PYTHON or later"
PYTHON=""
if ! PYTHON="$(find_python)"; then
  warn "No suitable Python found."
  case "$(uname -s)" in
    Darwin)
      # Homebrew may be installed but not on PATH in this shell.
      if ! command -v brew >/dev/null 2>&1; then
        for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
          [[ -x "$b" ]] && { eval "$("$b" shellenv)"; break; }
        done
      fi
      if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew is not installed."
        if confirm "Install Homebrew now (official installer from brew.sh; needs sudo and may install Xcode Command Line Tools)?"; then
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
          for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [[ -x "$b" ]] && { eval "$("$b" shellenv)"; break; }
          done
          command -v brew >/dev/null 2>&1 || fail "Homebrew was installed but 'brew' is not on PATH. Open a new terminal and re-run this script."
          ok "Homebrew installed"
        else
          fail "Python $MIN_PYTHON+ is required. Install Homebrew (https://brew.sh) then run: brew install python@3.12"
        fi
      fi
      if confirm "Install Python 3.12 with Homebrew now?"; then
        brew install python@3.12
        PYTHON="$(find_python)" || fail "Python 3.12 was installed but is not on PATH. Open a new terminal and re-run this script."
      else
        fail "Python $MIN_PYTHON+ is required. Install it with: brew install python@3.12"
      fi
      ;;
    Linux)
      install_python_linux
      PYTHON="$(find_python)" || fail "Python $MIN_PYTHON+ could not be installed. See https://developer.watson-orchestrate.ibm.com/getting_started/installing"
      ;;
    *) fail "Unsupported OS $(uname -s). Use labs/adk-setup/setup-adk.ps1 on Windows." ;;
  esac
fi
ok "Python $(python_version "$PYTHON") at $PYTHON"

# ---------------------------------------------------------------- 2. venv + pip
info "Step 2/5: checking venv module and pip"
if ! "$PYTHON" -c 'import venv, ensurepip' >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1 && [[ "$(uname -s)" == "Linux" ]]; then
    pyver="$(python_version "$PYTHON" | cut -d. -f1,2)"
    info "The 'venv' module is missing - installing python${pyver}-venv"
    confirm "Install python${pyver}-venv with apt (needs sudo)?" \
      && pkg_install "python${pyver}-venv" python3-venv || true
  fi
  "$PYTHON" -c 'import venv, ensurepip' >/dev/null 2>&1 \
    || fail "The Python 'venv' module is missing for $PYTHON. Install it (e.g. 'sudo apt-get install -y python3-venv') or reinstall Python, then re-run."
fi
ok "venv module available"

VENV_DIR="$WORKSPACE_DIR/.venv"
VENV_PY="$VENV_DIR/bin/python"

if [[ -x "$VENV_PY" ]]; then
  VENV_VER="$(python_version "$VENV_PY")"
  if [[ -n "$VENV_VER" ]] && ver_ge "$VENV_VER" "$MIN_PYTHON"; then
    ok "Existing virtual environment found ($VENV_DIR, Python $VENV_VER)"
  else
    fail "Existing virtual environment $VENV_DIR uses Python ${VENV_VER:-unknown} (< $MIN_PYTHON). Delete it ('rm -rf $VENV_DIR') and re-run."
  fi
else
  info "Creating workspace and virtual environment in $VENV_DIR"
  mkdir -p "$WORKSPACE_DIR"
  "$PYTHON" -m venv "$VENV_DIR"
  ok "Virtual environment created"
fi

if ! "$VENV_PY" -m pip --version >/dev/null 2>&1; then
  info "pip missing in the virtual environment - bootstrapping with ensurepip"
  "$VENV_PY" -m ensurepip --upgrade
fi
ok "pip $("$VENV_PY" -m pip --version | awk '{print $2}')"

# ---------------------------------------------------------------- 3. ADK package
installed_adk_version() {
  "$VENV_PY" -m pip show "$PACKAGE" 2>/dev/null | awk '/^Version:/ {print $2}'
}

info "Step 3/5: checking ADK ($PACKAGE) version >= $MIN_ADK"
ADK_VER="$(installed_adk_version || true)"
if [[ -n "$ADK_VER" ]] && ver_ge "$ADK_VER" "$MIN_ADK"; then
  ok "ADK $ADK_VER already installed - no change needed"
else
  if [[ -n "$ADK_VER" ]]; then
    info "ADK $ADK_VER is older than $MIN_ADK - upgrading"
  else
    info "ADK not installed - installing"
  fi
  "$VENV_PY" -m pip install --upgrade "$PACKAGE"
  ADK_VER="$(installed_adk_version || true)"
  [[ -n "$ADK_VER" ]] && ver_ge "$ADK_VER" "$MIN_ADK" \
    || fail "After install, ADK version is '${ADK_VER:-none}' (need >= $MIN_ADK)."
  ok "ADK $ADK_VER installed"
fi

# ---------------------------------------------------------------- 4. CLI check
info "Step 4/5: verifying the orchestrate CLI"
ORCH="$VENV_DIR/bin/orchestrate"
[[ -x "$ORCH" ]] || fail "orchestrate executable not found at $ORCH"
"$ORCH" --version || fail "'orchestrate --version' failed."
ok "orchestrate CLI runs"

# ---------------------------------------------------------------- 5. environment
  info "Step 5/5: configuring wxO environment '$ENV_NAME'"

  if env_registered; then
    ok "Environment '$ENV_NAME' is already registered - skipping 'env add'"
  else
    if [[ -z "$WXO_URL" ]]; then
      read -r -p "wxO service instance URL (wxoServiceInstanceURL in labs/event.env): " WXO_URL
    fi
    [[ -n "$WXO_URL" ]] || fail "A service instance URL is required. Set wxoServiceInstanceURL in labs/event.env or pass -u."
    "$ORCH" env add -n "$ENV_NAME" -u "$WXO_URL" --type mcsp
    ok "Environment '$ENV_NAME' added"
  fi

  if [[ -z "$WXO_API_KEY" ]]; then
    read -r -s -p "wxO API key (wxoAPIKey in labs/event.env; input hidden): " WXO_API_KEY
    echo
  fi
  [[ -n "$WXO_API_KEY" ]] || fail "An API key is required. Set wxoAPIKey in labs/event.env or pass -k."
  "$ORCH" env activate "$ENV_NAME" -a "$WXO_API_KEY"
  ok "Environment '$ENV_NAME' activated"
  save_api_key   # only after a successful activation, so a mistyped key is never stored

  info "Verifying connectivity"
  "$ORCH" agents list >/dev/null || fail "'orchestrate agents list' failed — check wxoServiceInstanceURL and wxoAPIKey in labs/event.env."
  ok "Connected to wxO"

# ---------------------------------------------------------------- done
echo
ok "ADK setup complete (ADK $ADK_VER)."
echo "  Activate the virtual environment in each new terminal with:"
echo "    source $VENV_DIR/bin/activate"
echo "  Tokens expire after 2 hours of inactivity; refresh with:"
echo "    ./labs/adk-setup/setup-adk-event.sh --activate"
