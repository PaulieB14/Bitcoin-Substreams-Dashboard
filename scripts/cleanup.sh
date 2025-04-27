#!/bin/bash

# Script to clean up the data directory
# This script will remove all Parquet files and create empty data directories

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Set variables
DATA_DIR="data"
BLOCK_META_DIR="$DATA_DIR/block_meta"
TRANSACTIONS_DIR="$DATA_DIR/transactions"
DASHBOARD_DATA_DIR="dashboard/data"

# Confirm with the user
echo "This script will remove all Parquet files and CSV files from the data directories."
echo "This action cannot be undone."
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled."
  exit 0
fi

# Remove Parquet files
echo "Removing Parquet files..."
rm -rf "$BLOCK_META_DIR"/*.parquet 2>/dev/null
rm -rf "$TRANSACTIONS_DIR"/*.parquet 2>/dev/null

# Remove CSV files
echo "Removing CSV files..."
rm -rf "$DASHBOARD_DATA_DIR"/*.csv 2>/dev/null

# Create data directories if they don't exist
echo "Creating empty data directories..."
mkdir -p "$BLOCK_META_DIR"
mkdir -p "$TRANSACTIONS_DIR"
mkdir -p "$DASHBOARD_DATA_DIR"

echo "Cleanup completed successfully."
echo "You can now run the run-substreams.sh script to generate new Parquet files."
