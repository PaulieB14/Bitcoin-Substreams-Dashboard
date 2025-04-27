#!/bin/bash

# Script to check the current Bitcoin block height
# This script will query a Bitcoin API to get the current block height

# Use the Blockchain.info API to get the current block height
echo "Checking current Bitcoin block height..."
CURRENT_HEIGHT=$(curl -s https://blockchain.info/q/getblockcount)

if [[ "$CURRENT_HEIGHT" =~ ^[0-9]+$ ]]; then
  echo "Current Bitcoin block height: $CURRENT_HEIGHT"
  
  # Calculate block height from 3 months ago (approximately 4320 blocks per month)
  THREE_MONTHS_AGO=$((CURRENT_HEIGHT - 13000))
  
  echo "Recommended block range for ~3 months of data:"
  echo "START_BLOCK=$THREE_MONTHS_AGO"
  echo "END_BLOCK=$CURRENT_HEIGHT"
  
  # Update the run-substreams.sh script with these values
  echo ""
  echo "To update your run-substreams.sh script with these values, run:"
  echo "sed -i '' 's/START_BLOCK=[0-9]*/START_BLOCK=$THREE_MONTHS_AGO/' run-substreams.sh"
  echo "sed -i '' 's/END_BLOCK=[0-9]*/END_BLOCK=$CURRENT_HEIGHT/' run-substreams.sh"
else
  echo "Error: Could not retrieve current block height"
  echo "Please check your internet connection and try again"
fi
