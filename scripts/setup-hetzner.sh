#!/bin/bash

# Script to set up a Hetzner VPS for the Bitcoin Dashboard
# This script should be run on the Hetzner VPS

# Set variables
STORAGE_VOLUME_PATH="/mnt/data"
REPO_URL="<repository-url>"  # Replace with your repository URL

# Update system
echo "Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
sudo apt-get install -y curl unzip git

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Substreams CLI
echo "Installing Substreams CLI..."
curl -L https://github.com/streamingfast/substreams/releases/latest/download/substreams_linux_x86_64.tar.gz | tar zxf -
sudo mv substreams /usr/local/bin

# Install substreams-sink-files
echo "Installing substreams-sink-files..."
curl -L https://github.com/streamingfast/substreams-sink-files/releases/latest/download/substreams-sink-files_linux_x86_64.tar.gz | tar zxf -
sudo mv substreams-sink-files /usr/local/bin

# Install DuckDB
echo "Installing DuckDB..."
curl -L https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-amd64.zip -o duckdb.zip
unzip duckdb.zip
sudo mv duckdb /usr/local/bin

# Set up storage volume
echo "Setting up storage volume..."
# Check if the volume is already mounted
if ! mountpoint -q "$STORAGE_VOLUME_PATH"; then
    # Create mount point if it doesn't exist
    sudo mkdir -p "$STORAGE_VOLUME_PATH"
    
    # Find the volume device (assuming it's the largest unformatted device)
    VOLUME_DEVICE=$(lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v loop | grep disk | sort -k 2 -r | head -n 1 | awk '{print $1}')
    VOLUME_DEVICE="/dev/$VOLUME_DEVICE"
    
    # Format the volume if it's not already formatted
    if ! blkid "$VOLUME_DEVICE" > /dev/null; then
        echo "Formatting volume $VOLUME_DEVICE..."
        sudo mkfs.ext4 "$VOLUME_DEVICE"
    fi
    
    # Mount the volume
    echo "Mounting volume $VOLUME_DEVICE to $STORAGE_VOLUME_PATH..."
    sudo mount "$VOLUME_DEVICE" "$STORAGE_VOLUME_PATH"
    
    # Add to fstab for automatic mounting on reboot
    echo "$VOLUME_DEVICE $STORAGE_VOLUME_PATH ext4 defaults 0 2" | sudo tee -a /etc/fstab
fi

# Set permissions
sudo chown -R $USER:$USER "$STORAGE_VOLUME_PATH"

# Clone repository
echo "Cloning repository..."
cd "$STORAGE_VOLUME_PATH"
git clone "$REPO_URL"
cd bitcoin-dashboard

# Create data directories
mkdir -p data/block_meta
mkdir -p data/transactions
mkdir -p dashboard/data

# Make scripts executable
chmod +x scripts/*.sh

echo "Setup complete!"
echo "You can now run the Substreams and generate Parquet files:"
echo "cd $STORAGE_VOLUME_PATH/bitcoin-dashboard/scripts"
echo "./run-substreams.sh"
