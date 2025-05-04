#!/bin/bash

# Script to run Bitcoin Substreams and output Parquet files
# This script will stream ~3 months of Bitcoin data and output Parquet files

# Navigate to the project directory
cd "$(dirname "$0")/..\" || { echo "Error: Cannot access project directory"; exit 1; }

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
# Current Bitcoin block height (fetch dynamically)
CURRENT_BLOCK=$(curl -s https://blockchain.info/q/getblockcount)
# If fetch fails, use a default end block
if [ -z "$CURRENT_BLOCK" ]; then
  END_BLOCK=894304
  echo "Warning: Could not fetch current block height. Using default end block: $END_BLOCK"
else
  END_BLOCK=$CURRENT_BLOCK
  echo "Current Bitcoin block height: $END_BLOCK"
fi

# Modules to stream
BLOCK_META_MODULE="map_block_meta"
TRANSACTIONS_MODULE="map_transactions"
BLOCK_RANGE="${START_BLOCK}:${END_BLOCK}"

# Create data directories if they don't exist
mkdir -p data/block_meta
mkdir -p data/transactions
mkdir -p dashboard/data

echo "Starting Bitcoin Substreams..."
echo "Streaming blocks from $START_BLOCK to $END_BLOCK"

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
pip install pandas pyarrow requests tqdm || {
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

# Step 3: Convert JSON to Parquet with enhanced fields
echo "Step 3: Converting JSON to Parquet with enhanced fields..."

# Convert block_meta.json to Parquet
echo "Converting block_meta.json to Parquet..."
python -c '
import pandas as pd
import json
import os
from tqdm import tqdm

try:
    # Load JSON data line by line
    block_meta_data = []
    with open("/tmp/block_meta.json", "r") as f:
        for line in tqdm(f, desc="Processing block metadata"):
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

    # Add derived fields
    if "block_timestamp" in df.columns:
        df["date"] = pd.to_datetime(df["block_timestamp"]).dt.date
    if "transaction_count" in df.columns:
        df["is_congested"] = df["transaction_count"] > df["transaction_count"].quantile(0.75)

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

# Convert transactions.json to Parquet with whale detection
echo "Converting transactions.json to Parquet with whale detection..."
python -c '
import pandas as pd
import json
import os
from tqdm import tqdm

# Define threshold for whale transactions (1 BTC in satoshis)
WHALE_THRESHOLD = 100000000

try:
    # Load JSON data line by line
    transactions_data = []
    with open("/tmp/transactions.json", "r") as f:
        for line in tqdm(f, desc="Processing transactions"):
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
                    
                    # Calculate fee
                    if "total_input_value" in data and "total_output_value" in data:
                        data["fee"] = data["total_input_value"] - data["total_output_value"]
                    
                    # Add whale transaction flag
                    if "total_input_value" in data:
                        data["is_whale_transaction"] = data["total_input_value"] >= WHALE_THRESHOLD
                    
                    transactions_data.append(data)
            except json.JSONDecodeError:
                # Skip invalid lines
                continue

    # Convert to DataFrame
    df = pd.DataFrame(transactions_data)
    
    # Print DataFrame info for debugging
    print("Transactions DataFrame columns:", df.columns.tolist())
    print("Transactions DataFrame shape:", df.shape)
    
    # Calculate additional metrics if possible
    if "fee" in df.columns and "block_height" in df.columns:
        # Calculate average fee per block
        fee_per_block = df.groupby("block_height")["fee"].mean().reset_index()
        fee_per_block.rename(columns={"fee": "avg_fee_per_block"}, inplace=True)
        # Merge back to main dataframe
        df = df.merge(fee_per_block, on="block_height", how="left")

    # Save as Parquet
    df.to_parquet("data/transactions/transactions.parquet")
    
    # Create a subset for whale transactions only
    if "is_whale_transaction" in df.columns:
        whale_df = df[df["is_whale_transaction"] == True]
        whale_df.to_parquet("data/transactions/whale_transactions.parquet")
        print(f"Saved {len(whale_df)} whale transactions to separate Parquet file")
    
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

echo "Real data processing completed. Parquet files are ready for the dashboard."
echo "The dashboard will read the Parquet files directly."