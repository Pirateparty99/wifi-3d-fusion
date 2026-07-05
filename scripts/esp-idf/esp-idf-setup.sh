#!/usr/bin/env bash
set -euo pipefail

# Requires: ESP_PATH, ESP_IDF_VERSION (e.g. "v6.0.2" or "v4.3") to be set in the environment.

log() { printf '\033[1;34m[esp-build]\033[0m %s\n' "$1"; }
err() { printf '\033[1;31m[esp-build]\033[0m %s\n' "$1" >&2; }

# --- Decide eim (>=5.0) vs legacy (<5.0) install path -----------------------
# eim's requirements-installer assumes the tools/requirements/*.txt layout,
# which ESP-IDF only introduced around v5.0. Pre-5.0 versions only have a
# flat tools/requirements.txt, so `eim install` fails for them with:
#   "Could not open requirements file: ''"
# We therefore only use eim for >=5.0, and fall back to the legacy
# install.sh/export.sh flow for anything older.
idf_major="${ESP_IDF_VERSION#v}"
idf_major="${idf_major%%.*}"
if ! [[ "$idf_major" =~ ^[0-9]+$ ]]; then
  err "Could not parse major version from ESP_IDF_VERSION='${ESP_IDF_VERSION}'"
  exit 1
fi

# Add execute permissions to ESP-IDF installation scripts
sudo chmod -R +x scripts/esp-idf/

# Create ESP-IDF installation directory
sudo mkdir -p "${ESP_PATH}/${ESP_IDF_VERSION}"

# `sudo mkdir` leaves this owned by root. The modern (eim) branch below
# doesn't care, since eim clones into /tmp/esp-idf and we chown after the
# fact — but the legacy branch clones directly into this directory as the
# current (unprivileged) user, so it needs to be writable now.
sudo chown -R "${USER}:${USER}" "${ESP_PATH}"

if [ "$idf_major" -ge 5 ]; then
  # ------------------------------------------------------------------------
  # Modern path (>=5.0): install via EIM
  # ------------------------------------------------------------------------
  log "ESP-IDF ${ESP_IDF_VERSION} >= v5.0 — installing via EIM"

  log "Installing EIM"
  sudo bash ./scripts/esp-idf/install-eim.sh

  log "Installing ESP-IDF ${ESP_IDF_VERSION} with EIM"
  eim install -i "${ESP_IDF_VERSION}" -p /tmp/esp-idf

  sudo mv "/tmp/esp-idf/${ESP_IDF_VERSION}" "${ESP_PATH}"

  # Set ownership of ESP-IDF installation dir to current user
  sudo chown -R "${USER}:${USER}" "${ESP_PATH}/${ESP_IDF_VERSION}"

  # Re-apply execute permissions after chown
  sudo chmod -R +x scripts/esp-idf/

  # Copy the espressif folder from root's home to the current user's home
  # echo "Copying espressif folder to ${USER}'s home"
  # sudo cp -r /root/.espressif/ ~/

  log "Activating the ESP-IDF ${ESP_IDF_VERSION} virtual environment"

  ACTIVATE_SCRIPT="$HOME/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh"
  if [ ! -f "$ACTIVATE_SCRIPT" ]; then
    err "Activation script not found: $ACTIVATE_SCRIPT"
    exit 1
  fi

  # NOTE on the two workarounds below:
  # 1. `bash -c '...' bash` fakes $0 to "bash" so the script's own
  #    is_sourced() check (which only allows $0 to look like a shell name)
  #    passes correctly, even though we're sourcing it from inside this
  #    non-shell-named wrapper script.
  # 2. The sed fixes a known typo in the generated PATH entries, which
  #    concatenate "$HOME" + ".espressif" without a "/" in between
  #    (e.g. ".../user1.espressif/tools/..." instead of
  #    ".../user1/.espressif/tools/...").
  # Keep any idf.py/build commands INSIDE this same bash -c block --
  # the PATH/function setup only exists within this subshell.
  bash -c '
    source "$1"
    export PATH="$(printf "%s" "$PATH" | sed -E "s#([^/])\.espressif/#\1/.espressif/#g")"
    idf.py --version
  ' bash "$ACTIVATE_SCRIPT"

else
  # ------------------------------------------------------------------------
  # Legacy path (<5.0): eim is not supported for this version, so clone and
  # bootstrap ESP-IDF directly with its own install.sh / export.sh scripts.
  # ------------------------------------------------------------------------
  log "ESP-IDF ${ESP_IDF_VERSION} < v5.0 — EIM does not support this version; using legacy install"

  IDF_CLONE_DIR="${ESP_PATH}/${ESP_IDF_VERSION}"

  if [ -d "${IDF_CLONE_DIR}/.git" ]; then
    log "Existing clone found at ${IDF_CLONE_DIR}, skipping clone"
  else
    log "Cloning ESP-IDF ${ESP_IDF_VERSION}"
    git clone -b "${ESP_IDF_VERSION}" --recursive \
      https://github.com/espressif/esp-idf.git "${IDF_CLONE_DIR}"
  fi

  log "Running legacy install.sh"
  (
    cd "${IDF_CLONE_DIR}"
    ./install.sh
  )

  # Set ownership of ESP-IDF installation dir to current user
  sudo chown -R "${USER}:${USER}" "${ESP_PATH}/${ESP_IDF_VERSION}"

  log "Activating the ESP-IDF ${ESP_IDF_VERSION} virtual environment (legacy export.sh)"

  EXPORT_SCRIPT="${IDF_CLONE_DIR}/export.sh"
  if [ ! -f "$EXPORT_SCRIPT" ]; then
    err "Legacy export.sh not found: $EXPORT_SCRIPT"
    exit 1
  fi

  bash -c '
    source "$1"
    idf.py --version
  ' bash "$EXPORT_SCRIPT"
fi

log "Done."