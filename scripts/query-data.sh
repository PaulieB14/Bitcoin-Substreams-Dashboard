#!/bin/bash

# Script to query Bitcoin data using DuckDB
# This script will run various queries on the Parquet files and output the results to CSV files

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Set variables
DATA_DIR="data"
QUERIES_DIR="queries"
OUTPUT_DIR="dashboard/data"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Running DuckDB queries..."

# Check if there are any Parquet files
if [ ! "$(find "$DATA_DIR" -name "*.parquet" | wc -l)" -gt 0 ]; then
  echo "Warning: No Parquet files found in $DATA_DIR"
  echo "Creating sample data for testing..."
  
  # Create sample data directory
  mkdir -p "$DATA_DIR/sample"
  
  # Create sample CSV files
  echo "block_height,avg_fees" > "$OUTPUT_DIR/avg_fees.csv"
  echo "0,0" >> "$OUTPUT_DIR/avg_fees.csv"
  
  echo "block_height,transaction_hash,total_input_value" > "$OUTPUT_DIR/top_transactions.csv"
  echo "0,0x0000000000000000000000000000000000000000000000000000000000000000,0" >> "$OUTPUT_DIR/top_transactions.csv"
  
  echo "block_height,tx_count" > "$OUTPUT_DIR/tx_count_per_block.csv"
  echo "0,0" >> "$OUTPUT_DIR/tx_count_per_block.csv"
  
  echo "input_address,tx_sent" > "$OUTPUT_DIR/top_sending_addresses.csv"
  echo "0x0000000000000000000000000000000000000000,0" >> "$OUTPUT_DIR/top_sending_addresses.csv"
  
  echo "output_address,tx_received" > "$OUTPUT_DIR/top_receiving_addresses.csv"
  echo "0x0000000000000000000000000000000000000000,0" >> "$OUTPUT_DIR/top_receiving_addresses.csv"
  
  echo "block_height,total_fees" > "$OUTPUT_DIR/fee_per_block.csv"
  echo "0,0" >> "$OUTPUT_DIR/fee_per_block.csv"
  
  echo "block_height,block_timestamp" > "$OUTPUT_DIR/block_times.csv"
  echo "0,2023-01-01 00:00:00" >> "$OUTPUT_DIR/block_times.csv"
  
  echo "block_height,transaction_count" > "$OUTPUT_DIR/congestion.csv"
  echo "0,0" >> "$OUTPUT_DIR/congestion.csv"
  
  echo "Sample data created for testing."
  echo "All queries completed. Results are in $OUTPUT_DIR directory."
  exit 0
fi

# Function to run a query and save the result to a CSV file
run_query() {
  local query_name="$1"
  local query="$2"
  
  echo "Running query: $query_name"
  duckdb -c "$query" > "$OUTPUT_DIR/$query_name.csv"
  echo "Query result saved to $OUTPUT_DIR/$query_name.csv"
}

# Average fees per block
run_query "avg_fees" "
SELECT AVG(fee) AS avg_fees
FROM read_parquet('$DATA_DIR/transactions/*.parquet');
"

# Top 10 largest BTC transactions
run_query "top_transactions" "
SELECT block_height, transaction_hash, total_input_value
FROM read_parquet('$DATA_DIR/transactions/*.parquet')
ORDER BY total_input_value DESC
LIMIT 10;
"

# Number of transactions per block
run_query "tx_count_per_block" "
SELECT block_height, COUNT(transaction_hash) as tx_count
FROM read_parquet('$DATA_DIR/transactions/*.parquet')
GROUP BY block_height
ORDER BY block_height;
"

# Top active sending addresses
run_query "top_sending_addresses" "
SELECT unnest(input_addresses) as input_address, COUNT(*) as tx_sent
FROM read_parquet('$DATA_DIR/transactions/*.parquet')
GROUP BY input_address
ORDER BY tx_sent DESC
LIMIT 10;
"

# Top active receiving addresses
run_query "top_receiving_addresses" "
SELECT unnest(output_addresses) as output_address, COUNT(*) as tx_received
FROM read_parquet('$DATA_DIR/transactions/*.parquet')
GROUP BY output_address
ORDER BY tx_received DESC
LIMIT 10;
"

# Fee heatmap data (fees per block)
run_query "fee_per_block" "
SELECT block_height, SUM(fee) as total_fees
FROM read_parquet('$DATA_DIR/transactions/*.parquet')
GROUP BY block_height
ORDER BY block_height;
"

# Block times
run_query "block_times" "
SELECT block_height, block_timestamp
FROM read_parquet('$DATA_DIR/block_meta/*.parquet')
ORDER BY block_height;
"

# Congestion tracker (transactions per block)
run_query "congestion" "
SELECT block_height, transaction_count
FROM read_parquet('$DATA_DIR/block_meta/*.parquet')
ORDER BY block_height;
"

echo "All queries completed. Results are in $OUTPUT_DIR directory."
