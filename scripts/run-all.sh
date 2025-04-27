#!/bin/bash

# Script to run all the steps in sequence
# This script will:
# 1. Check the current Bitcoin block height
# 2. Fetch real Bitcoin data using Substreams
# 3. Start the HTTP server and open the dashboard

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Set variables
SCRIPTS_DIR="scripts"

# Check if all required scripts exist
for script in check-block-height.sh run-substreams.sh run-dashboard.sh; do
  if [ ! -f "$SCRIPTS_DIR/$script" ]; then
    echo "Error: Required script $script not found"
    exit 1
  fi
done

# Step 1: Check the current Bitcoin block height
echo "Step 1: Checking the current Bitcoin block height..."
"$SCRIPTS_DIR/check-block-height.sh"

# Ask the user if they want to update the block range
read -p "Do you want to update the block range in run-substreams.sh? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Get the current block height and calculate the block height from 3 months ago
  CURRENT_HEIGHT=$(curl -s https://blockchain.info/q/getblockcount)
  THREE_MONTHS_AGO=$((CURRENT_HEIGHT - 13000))
  
  # Update the run-substreams.sh script
  sed -i '' "s/START_BLOCK=[0-9]*/START_BLOCK=$THREE_MONTHS_AGO/" "$SCRIPTS_DIR/run-substreams.sh"
  sed -i '' "s/END_BLOCK=[0-9]*/END_BLOCK=$CURRENT_HEIGHT/" "$SCRIPTS_DIR/run-substreams.sh"
  
  echo "Block range updated in run-substreams.sh"
fi

# Step 2: Fetch real Bitcoin data using Substreams
echo "Step 2: Fetching real Bitcoin data using Substreams..."
"$SCRIPTS_DIR/run-substreams.sh"

# Step 3: Start the HTTP server and open the dashboard
echo "Step 3: Starting the HTTP server and opening the dashboard..."
"$SCRIPTS_DIR/run-dashboard.sh"

echo "All steps completed successfully."
echo ""
echo "Note: This is now running with real Bitcoin data from Substreams."
echo "The data is processed through Parquet files and displayed directly in the dashboard."
