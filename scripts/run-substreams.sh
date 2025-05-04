#!/bin/bash

# Script to run Bitcoin Substreams and output Parquet files
# This script will stream ~3 months of Bitcoin data and output Parquet files

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Load environment variables
if [ -f ".env" ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
else
  echo "Error: .env file not found"
  echo "Please create a .env file with your Substreams API key"
  exit 1
fi

# Check if JWT token is set
if [ -z "$SUBSTREAMS_API_TOKEN" ]; then
  echo "Error: SUBSTREAMS_API_TOKEN is not set in .env file"
  exit 1
fi

# Set variables
PACKAGE="bitcoin-explorer@v0.1.0"
ENDPOINT="bitcoin.substreams.pinax.network:443"
# Bitcoin block height from ~3 months ago (adjust as needed)
START_BLOCK=881304
# Current Bitcoin block height (adjust as needed)
END_BLOCK=894304
# Modules to stream
BLOCK_META_MODULE="map_block_meta"
TRANSACTIONS_MODULE="map_transactions"
BLOCK_RANGE="${START_BLOCK}:${END_BLOCK}"

# Create data directories if they don't exist
mkdir -p data/block_meta
mkdir -p data/transactions

echo "Starting Bitcoin Substreams..."
echo "Streaming blocks from $START_BLOCK to $END_BLOCK"

# Create directories for data
mkdir -p data/block_meta
mkdir -p data/transactions
mkdir -p dashboard/data

echo "Fetching real Bitcoin data using Substreams..."

# Create a virtual environment for Python packages
VENV_DIR="/tmp/bitcoin-dashboard-venv"
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment for Python packages..."
  python3 -m venv "$VENV_DIR" || {
    echo "Error: Failed to create virtual environment."
    echo "Please install Python venv: brew install python"
    exit 1
  }
fi

# Activate the virtual environment
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate" || {
  echo "Error: Failed to activate virtual environment."
  exit 1
}

# Install required packages
echo "Installing required packages in virtual environment..."
pip install pandas pyarrow || {
  echo "Error: Failed to install required packages."
  exit 1
}

# Step 1: Run Substreams to get block metadata
echo "Step 1: Running Substreams to get block metadata..."
substreams run \
  -e "$ENDPOINT" \
  --start-block "$START_BLOCK" \
  --stop-block "$END_BLOCK" \
  -H "Authorization=Bearer $SUBSTREAMS_API_TOKEN" \
  --limit-processed-blocks 15000 \
  --output json \
  "$PACKAGE" \
  "$BLOCK_META_MODULE" > /tmp/block_meta.json || {
  echo "Error: Failed to run Substreams for block metadata."
  exit 1
}

# Step 2: Run Substreams to get transactions
echo "Step 2: Running Substreams to get transactions..."
substreams run \
  -e "$ENDPOINT" \
  --start-block "$START_BLOCK" \
  --stop-block "$END_BLOCK" \
  -H "Authorization=Bearer $SUBSTREAMS_API_TOKEN" \
  --limit-processed-blocks 15000 \
  --output json \
  "$PACKAGE" \
  "$TRANSACTIONS_MODULE" > /tmp/transactions.json || {
  echo "Error: Failed to run Substreams for transactions."
  exit 1
}

# Step 3: Convert JSON to Parquet
echo "Step 3: Converting JSON to Parquet..."

# Convert block_meta.json to Parquet
echo "Converting block_meta.json to Parquet..."
python -c '
import pandas as pd
import json
import os

try:
    # Load JSON data line by line
    block_meta_data = []
    with open("/tmp/block_meta.json", "r") as f:
        for line in f:
            try:
                obj = json.loads(line)
                if "@data" in obj:
                    # Extract the data from the @data field
                    data = obj["@data"]
                    # Add the block number
                    data["block_height"] = obj["@block"]
                    # Add timestamp if available
                    if "timestamp" in obj:
                        data["block_timestamp"] = obj["timestamp"]
                    # Add transaction count if available
                    if "transaction_count" in obj:
                        data["transaction_count"] = obj["transaction_count"]
                    block_meta_data.append(data)
            except json.JSONDecodeError:
                # Skip invalid lines
                continue

    # Convert to DataFrame
    df = pd.DataFrame(block_meta_data)
    
    # Print DataFrame info for debugging
    print("Block metadata DataFrame columns:", df.columns.tolist())
    print("Block metadata DataFrame shape:", df.shape)

    # Save as Parquet
    df.to_parquet("data/block_meta/block_meta.parquet")
    print("Successfully converted block_meta.json to Parquet")
except Exception as e:
    print(f"Error converting block_meta.json to Parquet: {e}")
    exit(1)
' || {
  echo "Error: Failed to convert block_meta.json to Parquet."
  exit 1
}

# Convert transactions.json to Parquet
echo "Converting transactions.json to Parquet..."
python -c '
import pandas as pd
import json
import os

try:
    # Load JSON data line by line
    transactions_data = []
    with open("/tmp/transactions.json", "r") as f:
        for line in f:
            try:
                obj = json.loads(line)
                if "@data" in obj:
                    # Extract the data from the @data field
                    data = obj["@data"]
                    # Add the block number
                    data["block_height"] = obj["@block"]
                    transactions_data.append(data)
            except json.JSONDecodeError:
                # Skip invalid lines
                continue

    # Convert to DataFrame
    df = pd.DataFrame(transactions_data)
    
    # Print DataFrame info for debugging
    print("Transactions DataFrame columns:", df.columns.tolist())
    print("Transactions DataFrame shape:", df.shape)

    # Save as Parquet
    df.to_parquet("data/transactions/transactions.parquet")
    print("Successfully converted transactions.json to Parquet")
except Exception as e:
    print(f"Error converting transactions.json to Parquet: {e}")
    exit(1)
' || {
  echo "Error: Failed to convert transactions.json to Parquet."
  exit 1
}

# Deactivate the virtual environment
deactivate

# Create dashboard data directory if it doesn't exist
mkdir -p dashboard/data

echo "Real data processing completed. Parquet files are ready for the dashboard."
echo "The dashboard will read the Parquet files directly."
