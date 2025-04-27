#!/bin/bash

# Script to monitor the progress of the Substreams
# This script will check the data directory for Parquet files and estimate the remaining time

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Set variables
DATA_DIR="data"
BLOCK_META_DIR="$DATA_DIR/block_meta"
TRANSACTIONS_DIR="$DATA_DIR/transactions"

# Check if the data directories exist
if [ ! -d "$BLOCK_META_DIR" ] || [ ! -d "$TRANSACTIONS_DIR" ]; then
  echo "Error: Data directories not found"
  echo "Please run the run-substreams.sh script first"
  exit 1
fi

# Get the start and end block from the run-substreams.sh script
START_BLOCK=$(grep -o "START_BLOCK=[0-9]*" scripts/run-substreams.sh | cut -d= -f2)
END_BLOCK=$(grep -o "END_BLOCK=[0-9]*" scripts/run-substreams.sh | cut -d= -f2)

if [ -z "$START_BLOCK" ] || [ -z "$END_BLOCK" ]; then
  echo "Error: Could not determine start and end blocks from run-substreams.sh"
  exit 1
fi

# Calculate total blocks to process
TOTAL_BLOCKS=$((END_BLOCK - START_BLOCK))

# Function to get the highest block processed
get_highest_block() {
  local dir="$1"
  local highest=0
  
  # Check if there are any Parquet files
  if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
    echo 0
    return
  fi
  
  # Extract the end block from the filename (format: *-{start_block}-{end_block}.parquet)
  for file in "$dir"/*.parquet; do
    if [ -f "$file" ]; then
      # Extract the end block from the filename
      local end_block=$(basename "$file" | grep -o '[0-9]*\.parquet' | grep -o '[0-9]*')
      if [ -n "$end_block" ] && [ "$end_block" -gt "$highest" ]; then
        highest=$end_block
      fi
    fi
  done
  
  echo $highest
}

# Get the highest block processed for each directory
BLOCK_META_HIGHEST=$(get_highest_block "$BLOCK_META_DIR")
TRANSACTIONS_HIGHEST=$(get_highest_block "$TRANSACTIONS_DIR")

# Use the lowest of the two as the current progress
CURRENT_BLOCK=$((BLOCK_META_HIGHEST < TRANSACTIONS_HIGHEST ? BLOCK_META_HIGHEST : TRANSACTIONS_HIGHEST))

# Calculate progress
if [ "$CURRENT_BLOCK" -eq 0 ]; then
  echo "No blocks processed yet"
  exit 0
fi

BLOCKS_PROCESSED=$((CURRENT_BLOCK - START_BLOCK))
BLOCKS_REMAINING=$((END_BLOCK - CURRENT_BLOCK))
PROGRESS_PERCENT=$(( (BLOCKS_PROCESSED * 100) / TOTAL_BLOCKS ))

echo "Progress: $PROGRESS_PERCENT% ($BLOCKS_PROCESSED/$TOTAL_BLOCKS blocks)"
echo "Current block: $CURRENT_BLOCK"
echo "Blocks remaining: $BLOCKS_REMAINING"

# Estimate remaining time if we have processed at least 100 blocks
if [ "$BLOCKS_PROCESSED" -gt 100 ]; then
  # Get the creation time of the oldest and newest files
  OLDEST_FILE=$(find "$BLOCK_META_DIR" -name "*.parquet" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2)
  NEWEST_FILE=$(find "$BLOCK_META_DIR" -name "*.parquet" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2)
  
  if [ -n "$OLDEST_FILE" ] && [ -n "$NEWEST_FILE" ]; then
    OLDEST_TIME=$(stat -c %Y "$OLDEST_FILE" 2>/dev/null || stat -f %m "$OLDEST_FILE" 2>/dev/null)
    NEWEST_TIME=$(stat -c %Y "$NEWEST_FILE" 2>/dev/null || stat -f %m "$NEWEST_FILE" 2>/dev/null)
    
    if [ -n "$OLDEST_TIME" ] && [ -n "$NEWEST_TIME" ]; then
      TIME_ELAPSED=$((NEWEST_TIME - OLDEST_TIME))
      
      if [ "$TIME_ELAPSED" -gt 0 ]; then
        BLOCKS_PER_SECOND=$(echo "scale=2; $BLOCKS_PROCESSED / $TIME_ELAPSED" | bc)
        ESTIMATED_SECONDS_REMAINING=$(echo "scale=0; $BLOCKS_REMAINING / $BLOCKS_PER_SECOND" | bc)
        
        # Convert seconds to a more readable format
        ESTIMATED_HOURS=$((ESTIMATED_SECONDS_REMAINING / 3600))
        ESTIMATED_MINUTES=$(( (ESTIMATED_SECONDS_REMAINING % 3600) / 60 ))
        
        echo "Estimated time remaining: ${ESTIMATED_HOURS}h ${ESTIMATED_MINUTES}m"
        echo "Processing speed: $BLOCKS_PER_SECOND blocks/second"
      fi
    fi
  fi
fi
