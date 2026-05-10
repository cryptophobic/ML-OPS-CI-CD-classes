#!/usr/bin/env bash
# install_dev_tools.sh — idempotent setup of Docker, Docker Compose, Python 3.9+,
# pip, and Python ML deps (torch, torchvision, pillow, Django) on Debian/Ubuntu.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

LOG_FILE="${LOG_FILE:-$(pwd)/install.log}"
PY_MIN_MAJOR=3
PY_MIN_MINOR=9
read -ra PIP_PACKAGES <<<"${PIP_PACKAGES:-torch torchvision pillow Django}"

# ---- logging ----------------------------------------------------------------
exec > >(tee -a "$LOG_FILE") 2>&1
log()  { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
step() { log "==> $*"; }

# ---- helpers ----------------------------------------------------------------
need_root() {
    if [ "$(id -u)" -ne 0 ]; then
        SUDO="sudo"
        command -v sudo >/dev/null 2>&1 || {
            log "ERROR: not root and sudo not available"; exit 1;
        }
    else
        SUDO=""
    fi
}

apt_update_once() {
    if [ -z "${APT_UPDATED:-}" ]; then
        step "apt-get update"
        $SUDO apt-get update -y
        APT_UPDATED=1
    fi
}

apt_install() {
    apt_update_once
    $SUDO apt-get install -y --no-install-recommends "$@"
}

have() { command -v "$1" >/dev/null 2>&1; }

python_ok() {
    have python3 || return 1
    python3 - <<EOF
import sys
sys.exit(0 if sys.version_info >= (${PY_MIN_MAJOR}, ${PY_MIN_MINOR}) else 1)
EOF
}

pip_have() {
    # $1 = importable module name (e.g. torch, torchvision, PIL, django)
    python3 -c "import $1" >/dev/null 2>&1
}

# ---- installers -------------------------------------------------------------
ensure_docker() {
    if have docker; then
        step "docker already installed: $(docker --version)"
        return
    fi
    step "installing docker.io"
    apt_install docker.io
}

ensure_compose() {
    if docker compose version >/dev/null 2>&1; then
        step "docker compose plugin present: $(docker compose version | head -1)"
        return
    fi
    if have docker-compose; then
        step "legacy docker-compose present: $(docker-compose --version)"
        return
    fi
    step "installing docker-compose-plugin"
    if ! apt_install docker-compose-plugin 2>/dev/null; then
        log "docker-compose-plugin unavailable; falling back to docker-compose"
        apt_install docker-compose
    fi
}

ensure_python() {
    if python_ok; then
        step "python3 satisfies >=${PY_MIN_MAJOR}.${PY_MIN_MINOR}: $(python3 --version)"
        return
    fi
    step "installing python3 + venv via apt"
    apt_install python3 python3-venv python3-dev
    if python_ok; then
        return
    fi
    step "apt python3 too old; installing pyenv + Python 3.11"
    apt_install make build-essential libssl-dev zlib1g-dev libbz2-dev \
        libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev \
        xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev git
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    if [ ! -d "$PYENV_ROOT" ]; then
        git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
    fi
    export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
    eval "$(pyenv init -)"
    pyenv install -s 3.11.9
    pyenv global 3.11.9
    hash -r
    python_ok || { log "ERROR: pyenv Python install did not satisfy version check"; exit 1; }
}

ensure_pip() {
    if have pip3; then
        step "pip3 already present: $(pip3 --version)"
        return
    fi
    step "installing pip"
    if ! apt_install python3-pip 2>/dev/null; then
        curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3
    fi
}

ensure_pip_packages() {
    declare -A IMPORT_NAME=(
        [torch]=torch
        [torchvision]=torchvision
        [pillow]=PIL
        [Django]=django
    )
    local missing=()
    for pkg in "${PIP_PACKAGES[@]}"; do
        if pip_have "${IMPORT_NAME[$pkg]}"; then
            step "pip pkg $pkg already importable"
        else
            missing+=("$pkg")
        fi
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        return
    fi
    step "pip installing: ${missing[*]}"
    pip3 install --no-cache-dir --upgrade "${missing[@]}"
}

# ---- summary ----------------------------------------------------------------
print_versions() {
    step "version summary"
    have docker          && docker --version          || log "docker:           MISSING"
    docker compose version >/dev/null 2>&1 && docker compose version | head -1 \
                         || (have docker-compose && docker-compose --version) \
                         || log "docker compose:   MISSING"
    have python3         && python3 --version         || log "python3:          MISSING"
    have pip3            && pip3 --version            || log "pip3:             MISSING"
    for pkg in torch torchvision PIL django; do
        python3 -c "import $pkg; print('${pkg}:', getattr($pkg, '__version__', 'unknown'))" \
            2>/dev/null || log "$pkg: MISSING"
    done
}

# ---- main -------------------------------------------------------------------
main() {
    step "install_dev_tools.sh start (log: $LOG_FILE)"
    need_root
    ensure_docker
    ensure_compose
    ensure_python
    ensure_pip
    ensure_pip_packages
    print_versions
    step "install_dev_tools.sh done"
}

main "$@"