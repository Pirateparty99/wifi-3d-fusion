#!/usr/bin/env bash

err() { printf '\033[1;31m[esp-build]\033[0m %s\n' "$1" >&2; }

# Prints a build-success message and how to flash the just-built firmware.
# Exported so it's callable from inside the bash -c subshells below (a
# plain function definition wouldn't be visible to a child bash process
# otherwise).
print_build_success() {
    echo ""
    echo "======================================================"
    echo "Build successful!"
    echo "======================================================"
    echo ""
    echo "Project directory: $(pwd)"
    echo ""

    local ports port uname_s example_port
    ports="$(ls /dev/ttyUSB* /dev/ttyACM* /dev/cu.usbserial-* /dev/cu.SLAB_USBtoUART* 2>/dev/null || true)"
    uname_s="$(uname -s 2>/dev/null || echo unknown)"

    if [ -n "$ports" ]; then
        port="$(echo "$ports" | head -n1)"
        echo "Detected device on: $port"
        if [ "$(echo "$ports" | wc -l)" -gt 1 ]; then
            echo "(Other candidates also found — using the first. Full list:)"
            echo "$ports" | sed 's/^/  /'
        fi
        echo ""
        echo "To flash this build, run:"
        echo "  idf.py -p $port flash"
        echo ""
        echo "To flash and open the serial monitor in one step, run:"
        echo "  idf.py -p $port flash monitor"
    else
        echo "No device detected on any serial port."
        echo "Plug in your ESP32 and check again with:"
        if [ "$uname_s" = "Darwin" ]; then
            example_port="/dev/cu.usbserial-1420"
            echo "  ls /dev/cu.*"
        else
            example_port="/dev/ttyUSB0"
            echo "  ls /dev/ttyUSB* /dev/ttyACM*"
        fi
        echo ""
        echo "Once connected, it will typically show up as something like:"
        echo "  $example_port"
        echo ""
        echo "Then flash with:"
        echo "  idf.py -p $example_port flash"
    fi
    echo ""
}
export -f print_build_success

activate_eim_env() {
  echo "Activating the ESP-IDF ${ESP_IDF_VERSION} virtual environment"

  local activate_script="$HOME/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh"
  if [ ! -f "$activate_script" ]; then
    err "Activation script not found: $activate_script"
    exit 1
  fi

  bash -c '
    source "$1"
    export PATH="$(printf "%s" "$PATH" | sed -E "s#([^/])\.espressif/#\1/.espressif/#g")"
    idf.py --version
  ' bash "$activate_script"
}

# EIM-installed ESP-IDF build function
eim-esp-build() {

    # Export the venv activation function to allow subshell to call it
    export -f activate_eim_env

    bash -c '
        set -euo pipefail

        activate_eim_env

        source ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh

        echo "Configuring ESP-IDF to connect to ESP32"

        idf.py menuconfig
        idf.py set-target esp32

        # Build the firmware
        echo "Building firmware"
        idf.py build

        print_build_success
    ' bash
}

# Sources the legacy export.sh script and runs a smoke test.
activate_legacy_env() {
  local idf_final_dir="$1"
  local export_script="${idf_final_dir}/export.sh"

  echo "Activating the ESP-IDF ${ESP_IDF_VERSION} virtual environment (legacy export.sh)"

  if [ ! -f "$export_script" ]; then
    err "Legacy export.sh not found: $export_script"
    exit 1
  fi

  bash -c '
    source "$1"
    idf.py --version
  ' bash "$export_script"
}

# Legacy (<5.0) ESP-IDF build function
legacy-esp-build () {
    # legacy export.sh needs IDF_PATH set — derive it from ESP_PATH/ESP_IDF_VERSION
    # (matching the layout the install script produces) unless it's already
    # been set explicitly. Using ${VAR:-} throughout so this stays safe under
    # `set -u` even when ESP_PATH/IDF_PATH aren't set at all.
    if [ -z "${IDF_PATH:-}" ]; then
        if [ -z "${ESP_PATH:-}" ]; then
            err "Neither IDF_PATH nor ESP_PATH is set. Set one of them (or export"
            err "IDF_PATH directly) before running legacy-esp-build."
            exit 1
        fi
        export IDF_PATH="${ESP_PATH}/${ESP_IDF_VERSION}"
    fi

    if [ ! -f "${IDF_PATH}/export.sh" ]; then
        err "export.sh not found at '${IDF_PATH}/export.sh'."
        err "Check that ESP_PATH and ESP_IDF_VERSION are set correctly, or set IDF_PATH directly."
        exit 1
    fi

    # Export the venv activation function to allow subshell to call it
    export -f activate_legacy_env

    bash -c '
        set -euo pipefail

        # Source the legacy ESP-IDF venv

        idf_final_dir="${ESP_PATH}/${ESP_IDF_VERSION}"
        activate_legacy_env "$idf_final_dir"

        source "${IDF_PATH}/export.sh"

        echo "Configuring ESP-IDF to connect to ESP32"

        idf.py menuconfig
        idf.py set-target esp32

        # Build the firmware
        echo "Building firmware"
        idf.py build

        print_build_success
    ' bash
}

# Function for grabbing the ESP-IDF major release version for version check
get_idf_major_version() {
  local version="$1" major
  major="${version#v}"
  major="${major%%.*}"
  if ! [[ "$major" =~ ^[0-9]+$ ]]; then
    err "Could not parse major version from ESP_IDF_VERSION='${version}'"
    exit 1
  fi
  echo "$major"
}


main() {
    # Source the ESP-IDF venv
    echo "Sourcing ESP-IDF version ${ESP_IDF_VERSION}"
    # source ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh
    # bash -c 'source ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh && idf.py build' bash
    # eval "$(sh ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh -e)"

    set -euo pipefail

    local idf_major
    idf_major="$(get_idf_major_version "${ESP_IDF_VERSION}")"

    # ESP-CSI Toolkit firmware build script

    # Clone repo if it does not exist
    if [ ! -d "third_party/esp32-csi-toolkit" ]; then

        echo "Cloning the ESP32 CSI Toolkit repo"

        git clone https://github.com/StevenMHernandez/ESP32-CSI-Tool "third_party/esp32-csi-toolkit"

    else
        echo "ESP32 CSI Toolkit repo already cloned, continuing"
    fi 

    cd "third_party/esp32-csi-toolkit/passive" # For Passive CSI collection (Used as a passive-RX)

    # Configure the connection settings for the ESP-IDF

    # Run ESP build based on installed ESP-IDF version

    if [ "$idf_major" -ge 5 ]; then
        eim-esp-build
    else
        legacy-esp-build
    fi
}

main "$@"