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
sudo chown -R ${USER} ${ESP_PATH}/${ESP_IDF_VERSION}

# Add execute permissions to ESP-IDF installation dix 
sudo chmod -R +x scripts/esp-idf/

# Copy the espressif folder from root's home to the current user's home
echo "Copying espressif folder to ${USER}'s home"
sudo cp -r /root/.espressif/ ~/

# Activate ESP-IDF venv
echo "Activating the ESP-IDF version ${ESP_IDF_VERSION} virtual environment"
source ~/.espressif/tools/activate_idf_${ESP_IDF_VERSION}.sh