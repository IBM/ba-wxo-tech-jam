#!/usr/bin/env bash
# setup-adk.sh - Install and configure the watsonx Orchestrate ADK CLI (macOS / Linux).
#
# Automates "Appendix: ADK CLI Setup Guide" in
# lab-guides/Introduction to watsonx Orchestrate.md (sections A.1 - A.5).
#
# Every dependency is checked first (existence AND version); nothing is installed
# or changed if it is already in place and recent enough.
#
# Usage:
#   ./labs/adk-setup/setup-adk.sh [options]
#
# Options:
#   -d, --dir <path>        Lab workspace directory holding the .venv   (default: ./wxo-labs)
#   -n, --env-name <name>   ADK environment name                        (default: trinity-lab)
#   -u, --url <url>         wxO service instance URL   (or env WXO_URL; prompted if omitted)
#   -k, --api-key <key>     wxO API key                (or env WXO_API_KEY; prompted, hidden, if omitted)
#       --skip-env          Install/verify the ADK only; do not configure an environment
#   -y, --yes               Do not ask before installing Homebrew or Python
#   -h, --help              Show this help
#
# Tip: prefer the WXO_API_KEY environment variable or the hidden prompt over --api-key,
# which is visible in the process list and shell history.

set -euo pipefail

MIN_PYTHON="3.11"
MIN_ADK="2.15"
PACKAGE="ibm-watsonx-orchestrate"

WORKSPACE_DIR="./wxo-labs"
ENV_NAME="trinity-lab"
WXO_URL="${WXO_URL:-}"
WXO_API_KEY="${WXO_API_KEY:-}"
SKIP_ENV=0
ASSUME_YES=0

# ---------------------------------------------------------------- helpers
info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*" >&2; }
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
  for cand in python3.12 python3.11 python3.13 python3 python; do
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

# install_python_linux -> install Python 3.11+ (package manager first, then uv; no sudo for uv)
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
  uv python install 3.11
  local uvpy
  uvpy="$(uv python find 3.11)" || fail "uv could not locate the Python 3.11 it just installed."
  export PATH="$(dirname "$uvpy"):$PATH"
}

# ---------------------------------------------------------------- arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)      WORKSPACE_DIR="${2:?missing value for $1}"; shift 2 ;;
    -n|--env-name) ENV_NAME="${2:?missing value for $1}"; shift 2 ;;
    -u|--url)      WXO_URL="${2:?missing value for $1}"; shift 2 ;;
    -k|--api-key)  WXO_API_KEY="${2:?missing value for $1}"; shift 2 ;;
    --skip-env)    SKIP_ENV=1; shift ;;
    -y|--yes)      ASSUME_YES=1; shift ;;
    -h|--help)     usage ;;
    *)             fail "Unknown option: $1 (use --help)" ;;
  esac
done

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
          fail "Python $MIN_PYTHON+ is required. Install Homebrew (https://brew.sh) then run: brew install python@3.11"
        fi
      fi
      if confirm "Install Python 3.11 with Homebrew now?"; then
        brew install python@3.11
        PYTHON="$(find_python)" || fail "Python 3.11 was installed but is not on PATH. Open a new terminal and re-run this script."
      else
        fail "Python $MIN_PYTHON+ is required. Install it with: brew install python@3.11"
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
if [[ $SKIP_ENV -eq 1 ]]; then
  info "Step 5/5: skipped (--skip-env)"
  echo
  info "ADK setup complete (pre-event mode). When the event begins:"
  echo "  1. Log in to the wxO TechJam tenant and retrieve your credentials:"
  echo "     - Click your user profile (top-right) → Settings"
  echo "     - Select API details tab"
  echo "     - Copy the Service instance URL and generate an API key"
  echo "  2. Re-run this script WITHOUT --skip-env to configure the environment:"
  echo "     ./labs/adk-setup/setup-adk.sh -u <URL>"
  echo
else
  info "Step 5/5: configuring wxO environment '$ENV_NAME'"

  if "$ORCH" env list 2>/dev/null | grep -Eq "(^|[^A-Za-z0-9_-])${ENV_NAME}($|[^A-Za-z0-9_-])"; then
    ok "Environment '$ENV_NAME' is already registered - skipping 'env add'"
  else
    if [[ -z "$WXO_URL" ]]; then
      read -r -p "wxO service instance URL (Settings > API details): " WXO_URL
    fi
    [[ -n "$WXO_URL" ]] || fail "A service instance URL is required."
    "$ORCH" env add -n "$ENV_NAME" -u "$WXO_URL" --type mcsp
    ok "Environment '$ENV_NAME' added"
  fi

  if [[ -z "$WXO_API_KEY" ]]; then
    read -r -s -p "wxO API key (input hidden): " WXO_API_KEY
    echo
  fi
  [[ -n "$WXO_API_KEY" ]] || fail "An API key is required."
  "$ORCH" env activate "$ENV_NAME" -a "$WXO_API_KEY"
  ok "Environment '$ENV_NAME' activated"

  info "Verifying connectivity"
  "$ORCH" agents list >/dev/null || fail "'orchestrate agents list' failed - check the URL and API key."
  ok "Connected to wxO"
fi

# ---------------------------------------------------------------- done
echo
ok "ADK setup complete (ADK $ADK_VER)."
echo "  Activate the virtual environment in each new terminal with:"
echo "    source $VENV_DIR/bin/activate"
echo "  Tokens expire after 2 hours of inactivity; refresh with:"
echo "    orchestrate env activate $ENV_NAME"
