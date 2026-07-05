#!/usr/bin/env bash
set -euo pipefail

# Requires: ESP_PATH, ESP_IDF_VERSION (e.g. "v6.0.2" or "v4.3") to be set in the environment.
# Optional: ESP_TARGET (e.g. "esp32", "esp32,esp32s3") — chip target(s) to install
#           tools for. Defaults to "all" if unset, which installs tools for
#           every supported target.
ESP_TARGET="${ESP_TARGET:-all}"

# Optional: LEGACY_PYTHON_BIN — path/name of the Python interpreter to use
#           for the legacy (<5.0) install.sh flow. Defaults to "python3"
#           (whatever that resolves to on PATH already). Old ESP-IDF
#           versions pin dependency versions from their era and often fail
#           to build under modern Python (e.g. 3.12 removed distutils,
#           which many old pinned packages' setup.py relies on) — set this
#           to an older interpreter (e.g. "python3.9") to avoid that.
LEGACY_PYTHON_BIN="${LEGACY_PYTHON_BIN:-python3}"
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

# Ensure the base install directory exists. We deliberately do NOT create
# ESP_PATH/${ESP_IDF_VERSION} here — both branches build into a /tmp
# directory first (owned by the current user throughout, avoiding any
# root-owned-directory permission clashes with unprivileged git/pip/etc.),
# then copy the finished result into ESP_PATH and fix ownership at the end.
sudo mkdir -p "${ESP_PATH}"
sudo chown "${USER}:${USER}" "${ESP_PATH}"

if [ "$idf_major" -ge 5 ]; then
  # ------------------------------------------------------------------------
  # Modern path (>=5.0): install via EIM
  # ------------------------------------------------------------------------
  log "ESP-IDF ${ESP_IDF_VERSION} >= v5.0 — installing via EIM (target: ${ESP_TARGET})"

  log "Installing EIM"
  sudo bash ./scripts/esp-idf/install-eim.sh

  log "Installing ESP-IDF ${ESP_IDF_VERSION} with EIM"
  eim install -i "${ESP_IDF_VERSION}" -p /tmp/esp-idf -t "${ESP_TARGET}"

  log "Copying installed ESP-IDF into ${ESP_PATH}"
  sudo cp -r "/tmp/esp-idf/${ESP_IDF_VERSION}" "${ESP_PATH}/${ESP_IDF_VERSION}"
  rm -rf "/tmp/esp-idf/${ESP_IDF_VERSION}"

  # Set ownership of ESP-IDF installation dir to current user, now that
  # the copy is complete
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
  log "ESP-IDF ${ESP_IDF_VERSION} < v5.0 — EIM does not support this version; using legacy install (target: ${ESP_TARGET})"

  IDF_TMP_DIR="/tmp/esp-idf-legacy/${ESP_IDF_VERSION}"
  IDF_FINAL_DIR="${ESP_PATH}/${ESP_IDF_VERSION}"

  mkdir -p "$(dirname "$IDF_TMP_DIR")"

  if [ -d "${IDF_TMP_DIR}/.git" ]; then
    log "Existing clone found at ${IDF_TMP_DIR}, skipping clone"
  else
    log "Cloning ESP-IDF ${ESP_IDF_VERSION}"
    git clone -b "${ESP_IDF_VERSION}" --recursive \
      https://github.com/espressif/esp-idf.git "${IDF_TMP_DIR}"
  fi

  log "Running legacy install.sh (python: ${LEGACY_PYTHON_BIN})"
  (
    cd "${IDF_TMP_DIR}"

    # install.sh detects its interpreter by running `which python3`/`which
    # python` — there's no clean env-var override for this in old ESP-IDF
    # versions. So if a specific interpreter was requested, build a small
    # shim directory with python3/python symlinks pointing at it, and put
    # that at the front of PATH for just this command.
    if [ "${LEGACY_PYTHON_BIN}" != "python3" ]; then
      resolved_python="$(command -v "${LEGACY_PYTHON_BIN}")" || {
        err "LEGACY_PYTHON_BIN '${LEGACY_PYTHON_BIN}' not found on PATH"
        exit 1
      }
      shim_dir="$(mktemp -d)"
      ln -s "${resolved_python}" "${shim_dir}/python3"
      ln -s "${resolved_python}" "${shim_dir}/python"
      export PATH="${shim_dir}:${PATH}"
      log "Using ${resolved_python} for install.sh (via PATH shim)"
    fi

    ./install.sh "${ESP_TARGET}"

    if [ -n "${shim_dir:-}" ]; then
      rm -rf "${shim_dir}"
    fi
  )

  log "Copying installed ESP-IDF into ${ESP_PATH}"
  sudo cp -r "${IDF_TMP_DIR}" "${IDF_FINAL_DIR}"
  rm -rf "${IDF_TMP_DIR}"

  # Set ownership of ESP-IDF installation dir to current user, now that
  # the copy is complete
  sudo chown -R "${USER}:${USER}" "${IDF_FINAL_DIR}"

  log "Activating the ESP-IDF ${ESP_IDF_VERSION} virtual environment (legacy export.sh)"

  EXPORT_SCRIPT="${IDF_FINAL_DIR}/export.sh"
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