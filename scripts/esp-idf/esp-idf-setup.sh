#!/usr/bin/env bash

# Add execute permissions to ESP-IDF installation scripts 
sudo chmod -R +x scripts/esp-idf/

# Install Espressif Installation Manager (EIM)
echo "Installing EIM"
sudo bash ./scripts/esp-idf/install-eim.sh

#Install the ESP-IDF with EIM
echo "Install the ESP-IDF with EIM"

# Export vars to set ESP-IDF verison and installation path
export ESP_PATH="/opt/esp-idf"
export ESP_IDF_VERSION="v6.0.2"

eim install


# Activate ESP-IDF venv
echo "Activating the ESP-IDF virtual environment
source ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh