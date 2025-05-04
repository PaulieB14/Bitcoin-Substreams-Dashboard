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
  
  echo "date,total_transactions,total_volume,avg_fee" > "$OUTPUT_DIR/daily_activity.csv"
  echo "2023-01-01,0,0,0" >> "$OUTPUT_DIR/daily_activity.csv"
  
  echo "Sample data created for testing."
  echo "All queries completed. Results are in $OUTPUT_DIR directory."
  exit 0
fi

# Function to run a query and save the result to a CSV file
run_query() {
  local query_name="$1"
  local query="$2"
  
  echo "Running query: $query_name"
  duckdb -c "$query" --csv > "$OUTPUT_DIR/$query_name.csv"
  echo "Query result saved to $OUTPUT_DIR/$query_name.csv"
}

# Find actual Parquet files (excluding macOS metadata files)
TRANSACTION_PARQUET_FILES=$(find "$DATA_DIR/transactions" -name "*.parquet" -not -name "._*" | tr '\n' ',' | sed 's/,$//')
BLOCK_META_PARQUET_FILES=$(find "$DATA_DIR/block_meta" -name "*.parquet" -not -name "._*" | tr '\n' ',' | sed 's/,$//')

echo "Found transaction Parquet files: $TRANSACTION_PARQUET_FILES"
echo "Found block meta Parquet files: $BLOCK_META_PARQUET_FILES"

# If no valid Parquet files found, create sample data
if [ -z "$TRANSACTION_PARQUET_FILES" ] && [ -z "$BLOCK_META_PARQUET_FILES" ]; then
  echo "No valid Parquet files found. Creating sample data..."
  
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
  
  echo "date,total_transactions,total_volume,avg_fee" > "$OUTPUT_DIR/daily_activity.csv"
  echo "2023-01-01,0,0,0" >> "$OUTPUT_DIR/daily_activity.csv"
  
  echo "block_height,fee_quartile,avg_fee" > "$OUTPUT_DIR/fee_rate_analysis.csv"
  echo "0,1,0" >> "$OUTPUT_DIR/fee_rate_analysis.csv"
  
  echo "block_height,transaction_hash,total_input_value" > "$OUTPUT_DIR/whale_transactions.csv"
  echo "0,0x0000000000000000000000000000000000000000000000000000000000000000,0" >> "$OUTPUT_DIR/whale_transactions.csv"
  
  echo "Sample data created for testing."
  echo "All queries completed. Results are in $OUTPUT_DIR directory."
  exit 0
fi

# Use the actual Parquet files in the queries
if [ -n "$TRANSACTION_PARQUET_FILES" ]; then
  # Average fees per block
  run_query "avg_fees" "
  SELECT AVG(fee) AS avg_fees
  FROM read_parquet('$TRANSACTION_PARQUET_FILES');
  "

  # Top 10 largest BTC transactions
  run_query "top_transactions" "
  SELECT block_height, transaction_hash, total_input_value
  FROM read_parquet('$TRANSACTION_PARQUET_FILES')
  ORDER BY total_input_value DESC
  LIMIT 10;
  "

  # Number of transactions per block
  run_query "tx_count_per_block" "
  SELECT block_height, COUNT(transaction_hash) as tx_count
  FROM read_parquet('$TRANSACTION_PARQUET_FILES')
  GROUP BY block_height
  ORDER BY block_height;
  "

  # Top active sending addresses
  run_query "top_sending_addresses" "
  SELECT unnest(input_addresses) as input_address, COUNT(*) as tx_sent
  FROM read_parquet('$TRANSACTION_PARQUET_FILES')
  GROUP BY input_address
  ORDER BY tx_sent DESC
  LIMIT 10;
  "

  # Top active receiving addresses
  run_query "top_receiving_addresses" "
  SELECT unnest(output_addresses) as output_address, COUNT(*) as tx_received
  FROM read_parquet('$TRANSACTION_PARQUET_FILES')
  GROUP BY output_address
  ORDER BY tx_received DESC
  LIMIT 10;
  "

  # Fee heatmap data (fees per block)
  run_query "fee_per_block" "
  SELECT block_height, SUM(fee) as total_fees
  FROM read_parquet('$TRANSACTION_PARQUET_FILES')
  GROUP BY block_height
  ORDER BY block_height;
  "

  # NEW QUERY: Whale transactions only (over 1 BTC)
  run_query "whale_transactions" "
  SELECT block_height, transaction_hash, total_input_value
  FROM read_parquet('$TRANSACTION_PARQUET_FILES')
  WHERE total_input_value >= 100000000  -- 1 BTC in satoshis
  ORDER BY total_input_value DESC
  LIMIT 50;
  "

  # NEW QUERY: Daily activity metrics
  run_query "daily_activity" "
  WITH daily_txs AS (
    SELECT 
      DATE_TRUNC('day', block_timestamp) as date,
      COUNT(*) as total_transactions,
      SUM(total_input_value) as total_volume,
      AVG(fee) as avg_fee
    FROM read_parquet('$TRANSACTION_PARQUET_FILES')
    GROUP BY DATE_TRUNC('day', block_timestamp)
  )
  SELECT * FROM daily_txs
  ORDER BY date;
  "

  # NEW QUERY: Fee rate analysis
  run_query "fee_rate_analysis" "
  SELECT 
    block_height,
    NTILE(4) OVER (ORDER BY fee) as fee_quartile,
    AVG(fee) as avg_fee
  FROM read_parquet('$TRANSACTION_PARQUET_FILES')
  GROUP BY block_height
  ORDER BY block_height;
  "
fi

if [ -n "$BLOCK_META_PARQUET_FILES" ]; then
  # Block times
  run_query "block_times" "
  SELECT block_height, block_timestamp
  FROM read_parquet('$BLOCK_META_PARQUET_FILES')
  ORDER BY block_height;
  "

  # Congestion tracker (transactions per block)
  run_query "congestion" "
  SELECT block_height, transaction_count
  FROM read_parquet('$BLOCK_META_PARQUET_FILES')
  ORDER BY block_height;
  "
fi

echo "All queries completed. Results are in $OUTPUT_DIR directory."
