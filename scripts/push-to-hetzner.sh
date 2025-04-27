#!/bin/bash

# Script to push the Bitcoin Dashboard project to the Hetzner VPS
# This script should be run on the local machine (Mac Mini)

# Set variables
HETZNER_USER="git"  # Replace with your Hetzner username
HETZNER_IP="5.161.70.165"  # Replace with your Hetzner IP
HETZNER_PATH="/mnt/data/bitcoin-dashboard"  # Path on the Hetzner VPS

# Check if we can connect to the server
if ! ssh -q $HETZNER_USER@$HETZNER_IP exit; then
  echo "Error: Cannot connect to $HETZNER_USER@$HETZNER_IP"
  echo "Please check your SSH configuration and server status."
  exit 1
fi

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Check if the project is a Git repository
if [ ! -d ".git" ]; then
  echo "Initializing Git repository..."
  git init
  git add .
  git commit -m "Initial commit"
fi

# Check if the Hetzner remote exists
if ! git remote | grep -q "hetzner"; then
  echo "Adding 'hetzner' remote..."
  git remote add hetzner "$HETZNER_USER@$HETZNER_IP:$HETZNER_PATH"
else
  echo "Remote 'hetzner' already exists"
fi

# Push to Hetzner
echo "Pushing to Hetzner..."
if git push -u hetzner master; then
  echo "Success: Project pushed to Hetzner"
else
  echo "Error: Failed to push project"
  exit 1
fi

echo "Project successfully pushed to Hetzner VPS."
echo "You can now run the setup script on the Hetzner VPS:"
echo "ssh $HETZNER_USER@$HETZNER_IP"
echo "cd $HETZNER_PATH/scripts"
echo "./setup-hetzner.sh"
