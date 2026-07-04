#!/usr/bin/env bash

# Add execute permissions to ESP-IDF installation scripts 
sudo chmod -R +x scripts/esp-idf/

# Create ESP-IDF installation directory 
sudo mkdir ${ESP_PATH}/${ESP_IDF_VERSION}

# Install Espressif Installation Manager (EIM)
echo "Installing EIM"
sudo bash ./scripts/esp-idf/install-eim.sh

#Install the ESP-IDF with EIM
echo "Install the ESP-IDF with EIM"

sudo eim install -i ${ESP_IDF_VERSION} -p ${ESP_PATH}

# Set ownership of ESP-IDF installation dir to current user
sudo chown -R ${iser} ${ESP_PATH}

# Add execute permissions to ESP-IDF installation dix 
sudo chmod -R +x scripts/esp-idf/
    
# Activate ESP-IDF venv
echo "Activating the ESP-IDF version ${ESP_IDF_VERSION} virtual environment"
source /opt/esp-idf/${ESP_IDF_VERSION}/esp-idf/