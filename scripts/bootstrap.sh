#!/usr/bin/env bash
set -euo pipefail
bash scripts/install_all.sh
echo "Installed dependencies. Copying web templates for dashboard."
bash scripts/copy-web-templates.sh

# Install the ESP-IDF if it is not found locally
if [ ! -d ~/.esspressif ]; then
    echo "ESP-IDF not found, installing the ESP-IDF before building ESP32 firmware"
    bash scripts/esp-idf/esp-idf-setup.sh
else
    echo "ESP-IDF version ${ESP_IDF_VERSION} found, continuing"
fi

echo "Building ESP32 firmware..."
bash scripts/esp-idf/esp-build.sh

echo "Done. Try: ./scripts/run_realtime.sh --source esp32"