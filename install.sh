#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Elias-Lee-SC/rime-array30-classic-plus.git}"
RIME_DIR="${RIME_DIR:-$HOME/Library/Rime}"
SQUIRREL_APP="/Library/Input Methods/Squirrel.app"
RIME_DEPLOYER="$SQUIRREL_APP/Contents/MacOS/rime_deployer"
SQUIRREL_BIN="$SQUIRREL_APP/Contents/MacOS/Squirrel"
SQUIRREL_SHARED="$SQUIRREL_APP/Contents/SharedSupport"

log() {
  printf '%s\n' "==> $*"
}

die() {
  printf '%s\n' "Error: $*" >&2
  exit 1
}

ensure_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "this installer is for macOS Squirrel only."
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  log "Homebrew not found. Installing Homebrew first..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  command -v brew >/dev/null 2>&1 || die "Homebrew installation finished, but brew is not on PATH. Open a new Terminal window and run this script again."
}

install_squirrel() {
  if [[ -d "$SQUIRREL_APP" ]]; then
    log "Squirrel is already installed."
    return
  fi

  log "Installing Squirrel via Homebrew..."
  brew install --cask squirrel-app
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return
  fi

  log "Git not found. Installing git via Homebrew..."
  brew install git
}

install_rime_config() {
  mkdir -p "$(dirname "$RIME_DIR")"

  if [[ -d "$RIME_DIR/.git" ]]; then
    log "Updating existing Rime config repository at $RIME_DIR..."
    git -C "$RIME_DIR" pull --ff-only
    return
  fi

  if [[ -e "$RIME_DIR" ]] && [[ -n "$(find "$RIME_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    local backup_dir
    backup_dir="$RIME_DIR.backup.$(date +%Y%m%d-%H%M%S)"
    log "Existing Rime directory found. Moving it to $backup_dir..."
    mv "$RIME_DIR" "$backup_dir"
  fi

  log "Cloning Rime config from $REPO_URL..."
  git clone "$REPO_URL" "$RIME_DIR"
}

deploy_rime() {
  [[ -x "$RIME_DEPLOYER" ]] || die "rime_deployer not found at $RIME_DEPLOYER."
  [[ -x "$SQUIRREL_BIN" ]] || die "Squirrel binary not found at $SQUIRREL_BIN."

  log "Deploying Rime config..."
  "$RIME_DEPLOYER" --build "$RIME_DIR" "$SQUIRREL_SHARED" "$RIME_DIR/build"

  log "Reloading Squirrel..."
  "$SQUIRREL_BIN" --reload
}

main() {
  ensure_macos
  ensure_homebrew
  install_squirrel
  ensure_git
  install_rime_config
  deploy_rime

  log "Done."
  log "If Squirrel is not shown in the input menu, add it in macOS System Settings > Keyboard > Input Sources."
}

main "$@"
