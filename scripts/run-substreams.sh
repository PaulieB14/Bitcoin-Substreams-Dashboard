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
PACKAGE="streamingfast/bitcoin-explorer:v0.1.0"
ENDPOINT="bitcoin.substreams.pinax.network:443"
# Bitcoin block height from ~3 months ago (adjust as needed)
START_BLOCK=881121
# Current Bitcoin block height (adjust as needed)
END_BLOCK=894121
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
substreams run "bitcoin-explorer@v0.1.0" "$BLOCK_META_MODULE" \
  --start-block "$START_BLOCK" \
  --stop-block "$END_BLOCK" \
  -e "$ENDPOINT" \
  -H "Authorization: Bearer $SUBSTREAMS_API_TOKEN" \
  --limit-processed-blocks 15000 \
  --output json > /tmp/block_meta.json || {
  echo "Error: Failed to run Substreams for block metadata."
  exit 1
}

# Step 2: Run Substreams to get transactions
echo "Step 2: Running Substreams to get transactions..."
substreams run "bitcoin-explorer@v0.1.0" "$TRANSACTIONS_MODULE" \
  --start-block "$START_BLOCK" \
  --stop-block "$END_BLOCK" \
  -e "$ENDPOINT" \
  -H "Authorization: Bearer $SUBSTREAMS_API_TOKEN" \
  --limit-processed-blocks 15000 \
  --output json > /tmp/transactions.json || {
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
    # Load JSON data
    with open("/tmp/block_meta.json", "r") as f:
        data = json.load(f)

    # Convert to DataFrame
    df = pd.DataFrame(data)

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
    # Load JSON data
    with open("/tmp/transactions.json", "r") as f:
        data = json.load(f)

    # Convert to DataFrame
    df = pd.DataFrame(data)

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

# Step 4: Query Parquet files with DuckDB to generate CSV files
echo "Step 4: Querying Parquet files with DuckDB..."

# Average fees per block
echo "Generating avg_fees.csv..."
duckdb -c "
SELECT AVG(fee) AS avg_fees
FROM read_parquet('data/transactions/*.parquet');
" > dashboard/data/avg_fees.csv

# Top 10 largest BTC transactions
echo "Generating top_transactions.csv..."
duckdb -c "
SELECT block_height, transaction_hash, total_input_value
FROM read_parquet('data/transactions/*.parquet')
ORDER BY total_input_value DESC
LIMIT 10;
" > dashboard/data/top_transactions.csv

# Number of transactions per block
echo "Generating tx_count_per_block.csv..."
duckdb -c "
SELECT block_height, COUNT(transaction_hash) as tx_count
FROM read_parquet('data/transactions/*.parquet')
GROUP BY block_height
ORDER BY block_height;
" > dashboard/data/tx_count_per_block.csv

# Top active sending addresses
echo "Generating top_sending_addresses.csv..."
duckdb -c "
SELECT unnest(input_addresses) as input_address, COUNT(*) as tx_sent
FROM read_parquet('data/transactions/*.parquet')
GROUP BY input_address
ORDER BY tx_sent DESC
LIMIT 10;
" > dashboard/data/top_sending_addresses.csv

# Top active receiving addresses
echo "Generating top_receiving_addresses.csv..."
duckdb -c "
SELECT unnest(output_addresses) as output_address, COUNT(*) as tx_received
FROM read_parquet('data/transactions/*.parquet')
GROUP BY output_address
ORDER BY tx_received DESC
LIMIT 10;
" > dashboard/data/top_receiving_addresses.csv

# Fee heatmap data (fees per block)
echo "Generating fee_per_block.csv..."
duckdb -c "
SELECT block_height, SUM(fee) as total_fees
FROM read_parquet('data/transactions/*.parquet')
GROUP BY block_height
ORDER BY block_height;
" > dashboard/data/fee_per_block.csv

# Block times
echo "Generating block_times.csv..."
duckdb -c "
SELECT block_height, block_timestamp
FROM read_parquet('data/block_meta/*.parquet')
ORDER BY block_height;
" > dashboard/data/block_times.csv

# Congestion tracker (transactions per block)
echo "Generating congestion.csv..."
duckdb -c "
SELECT block_height, transaction_count
FROM read_parquet('data/block_meta/*.parquet')
ORDER BY block_height;
" > dashboard/data/congestion.csv

echo "Real data processing completed. CSV files are ready for the dashboard."
