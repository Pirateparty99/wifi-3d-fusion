#!/usr/bin/env bash
set -euo pipefail
bash scripts/install_all.sh
echo "Installed dependencies. Copying web templates for dashboard."
bash scripts/copy-web-templates.sh

echo "Building ESP32 firmware..."
bash scripts/esp-build.sh

echo "Done. Try: ./scripts/run_realtime.sh --source esp32"