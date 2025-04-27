#!/bin/bash

# Script to monitor the progress of the Substreams process
# This script will:
# 1. Check if the Substreams process is running
# 2. Check if the output files exist
# 3. Display the progress

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Set variables
BLOCK_META_JSON="/tmp/block_meta.json"
TRANSACTIONS_JSON="/tmp/transactions.json"
BLOCK_META_PARQUET="data/block_meta/block_meta.parquet"
TRANSACTIONS_PARQUET="data/transactions/transactions.parquet"

# Function to check if the Substreams process is running
check_substreams_process() {
  if pgrep -f "substreams run" > /dev/null; then
    echo "Substreams process is running."
    ps aux | grep "substreams run" | grep -v grep
    return 0
  else
    echo "Substreams process is not running."
    return 1
  fi
}

# Function to check if the output files exist
check_output_files() {
  echo "Checking output files..."
  
  if [ -f "$BLOCK_META_JSON" ]; then
    echo "Block metadata JSON file exists: $BLOCK_META_JSON"
    echo "File size: $(du -h "$BLOCK_META_JSON" | cut -f1)"
  else
    echo "Block metadata JSON file does not exist: $BLOCK_META_JSON"
  fi
  
  if [ -f "$TRANSACTIONS_JSON" ]; then
    echo "Transactions JSON file exists: $TRANSACTIONS_JSON"
    echo "File size: $(du -h "$TRANSACTIONS_JSON" | cut -f1)"
  else
    echo "Transactions JSON file does not exist: $TRANSACTIONS_JSON"
  fi
  
  if [ -f "$BLOCK_META_PARQUET" ]; then
    echo "Block metadata Parquet file exists: $BLOCK_META_PARQUET"
    echo "File size: $(du -h "$BLOCK_META_PARQUET" | cut -f1)"
  else
    echo "Block metadata Parquet file does not exist: $BLOCK_META_PARQUET"
  fi
  
  if [ -f "$TRANSACTIONS_PARQUET" ]; then
    echo "Transactions Parquet file exists: $TRANSACTIONS_PARQUET"
    echo "File size: $(du -h "$TRANSACTIONS_PARQUET" | cut -f1)"
  else
    echo "Transactions Parquet file does not exist: $TRANSACTIONS_PARQUET"
  fi
}

# Function to display the progress
display_progress() {
  echo "Displaying progress..."
  
  # Check if the Substreams process is running
  check_substreams_process
  
  # Check if the output files exist
  check_output_files
  
  # Check if the dashboard data files exist
  if [ -d "dashboard/data" ]; then
    echo "Dashboard data files:"
    ls -la dashboard/data
  else
    echo "Dashboard data directory does not exist: dashboard/data"
  fi
}

# Main function
main() {
  echo "Monitoring Substreams progress..."
  echo "Press Ctrl+C to exit."
  
  while true; do
    clear
    echo "=== Substreams Progress Monitor ==="
    echo "Time: $(date)"
    echo ""
    
    display_progress
    
    echo ""
    echo "Refreshing in 5 seconds..."
    sleep 5
  done
}

# Run the main function
main
