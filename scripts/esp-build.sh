#!/usr/bin/env bash

set -euo pipefail

# ESP-CSI Toolkit firmware build script

# Clone repo

echo "Cloning the ESP32 CSI Toolkit repo"
git clone https://github.com/StevenMHernandez/ESP32-CSI-Tool "third_party/esp32-csi-toolkit"

cd "third_party/esp32-csi-toolkit/passive" # For Passive CSI collection (Used as a passive-RX)

# Configure the connection settings for the ESP-IDF

echo "Configuring ESP-IDF to connect to ESP32"
idf.py menuconfig

# Build the firmware
echo "Building firmware"
idf.py build
