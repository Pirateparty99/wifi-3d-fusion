#!/usr/bin/env bash

# EIM-installed ESP-IDF build function
eim-esp-build() {
    bash -c '
        source ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh
        
        echo "Configuring ESP-IDF to connect to ESP32"
        
        idf.py menuconfig
        idf.py set-target esp32

        # Build the firmware
        echo "Building firmware"
        idf.py build

    ' bash
}

legacy-esp-build () {
    source 
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