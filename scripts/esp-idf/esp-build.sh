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

# Source the ESP-IDF venv
echo "Sourcing ESP-IDF version ${ESP_IDF_VERSION}"
# source ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh
# bash -c 'source ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh && idf.py build' bash
# eval "$(sh ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh -e)"

set -euo pipefail

# ESP-CSI Toolkit firmware build script

# Clone repo


if [ ! -d "third_party/esp32-csi-toolkit" ]; then

    echo "Cloning the ESP32 CSI Toolkit repo"

    git clone https://github.com/StevenMHernandez/ESP32-CSI-Tool "third_party/esp32-csi-toolkit"

else
    echo "ESP32 CSI Toolkit repo already cloned, continuing"
fi 

cd "third_party/esp32-csi-toolkit/passive" # For Passive CSI collection (Used as a passive-RX)

# Configure the connection settings for the ESP-IDF

# Select version of 

eim-esp-build