# Bitcoin Activity Dashboard

A lightweight Bitcoin dashboard focusing on whales, fees, congestion — backed by Hetzner cloud storage and locally queried with DuckDB.

## Overview

This project creates a Bitcoin activity dashboard showing:

- Blocks over time
- Big transactions (whale watchers)
- Fee tracking
- Network congestion
- Top sender/receiver wallets

The dashboard tracks approximately 3 months of data (~14,000 blocks) to keep the dataset manageable.

## Current Status

The project is currently in a **prototype stage** with the following components working:

- ✅ Dashboard UI with Chart.js visualizations
- ✅ Sample data generation for testing
- ✅ Local HTTP server for viewing the dashboard
- ✅ Scripts for checking Bitcoin block height
- ✅ Configuration for Hetzner deployment

The following components are **in progress**:

- ⏳ Substreams integration for Bitcoin data processing
- ⏳ Parquet file generation from Substreams output
- ⏳ DuckDB queries for data analysis

## Project Structure

```
bitcoin-dashboard/
├── data/                      # Directory for data files
│   ├── block_meta/            # Block metadata (Parquet files)
│   └── transactions/          # Transaction data (Parquet files)
├── scripts/                   # Scripts for data processing
│   ├── sink-config.yaml       # Configuration for substreams-sink-files
│   ├── run-substreams.sh      # Script to run Substreams and output Parquet files
│   ├── query-data.sh          # Script to query Parquet files with DuckDB
│   ├── run-dashboard.sh       # Script to open the dashboard in a browser
│   ├── check-block-height.sh  # Script to check the current Bitcoin block height
│   ├── monitor-progress.sh    # Script to monitor the progress of the Substreams
│   ├── cleanup.sh             # Script to clean up the data directory
│   ├── setup-hetzner.sh       # Script to set up the Hetzner VPS
│   ├── push-to-hetzner.sh     # Script to push the project to the Hetzner VPS
│   ├── run-all.sh             # Script to run all the steps in sequence
│   └── build-custom-module.sh # Script to build a custom Substreams module
├── dashboard/                 # Dashboard files
│   ├── index.html             # Dashboard HTML
│   └── data/                  # CSV files for the dashboard
├── .env                       # Environment variables (API keys)
├── .gitignore                 # Git ignore file
└── README.md                  # This file
```

## Prerequisites

- [Python](https://www.python.org/) (for the HTTP server)
- [Substreams CLI](https://substreams.streamingfast.io/)
- [substreams-sink-files](https://github.com/streamingfast/substreams-sink-files)
- [DuckDB](https://duckdb.org/)
- [Rust and Cargo](https://rustup.rs/) (only for custom module development)

## Setup

### Local Setup (Mac Mini)

1. Install the required tools:
   ```bash
   brew install python
   brew install substreams
   brew install substreams-sink-files
   brew install duckdb
   ```

2. Clone this repository:
   ```bash
   git clone <repository-url>
   cd bitcoin-dashboard
   ```

3. Create a `.env` file with your Substreams API key:
   ```bash
   echo "SUBSTREAMS_API_KEY=your_api_key_here" > .env
   ```

### Hetzner VPS Setup

1. Spin up a Hetzner VPS (2-4 vCPU, 8GB RAM)
2. Add a Storage Volume (~500GB)
3. Use the provided setup script:
   ```bash
   ./scripts/setup-hetzner.sh
   ```

## Usage

### Quick Start

To run the dashboard with sample data:

```bash
cd scripts
./run-substreams.sh  # Creates sample data
./run-dashboard.sh   # Starts HTTP server and opens dashboard
```

### Individual Steps

#### 1. Check the Current Bitcoin Block Height

```bash
cd scripts
./check-block-height.sh
```

#### 2. Generate Sample Data (Currently)

```bash
cd scripts
./run-substreams.sh
```

This script currently:
- Creates sample CSV files for testing the dashboard
- Provides information about the planned workflow with Substreams and Parquet files

#### 3. View the Dashboard

```bash
cd scripts
./run-dashboard.sh
```

This script:
- Starts a local HTTP server
- Opens the dashboard in your default browser
- Displays the sample data in various charts and tables

### Future Implementation

Once the Substreams integration is complete, the workflow will be:

1. Use Substreams to process Bitcoin blockchain data
2. Store the data in Parquet files
3. Query the Parquet files with DuckDB to generate CSV files
4. Display the data in the dashboard

### Custom Module Development

If you want to create a custom Substreams module that extracts only essential data:

```bash
cd scripts
./build-custom-module.sh
```

This script will:
1. Create a new Rust project for the custom module
2. Set up the necessary files (Cargo.toml, substreams.yaml, etc.)
3. Build the module using Cargo

## Substreams Modules Used

- `map_block_meta` - Provides basic information about a block
- `map_transactions` - Allows you to find transactions
- `map_custom` - Custom module that extracts only essential data (if built)

## Example Queries (Planned)

```sql
-- Average fees per block
SELECT AVG(fee) AS avg_fees
FROM read_parquet('data/transactions/*.parquet');

-- Top 10 largest BTC transactions
SELECT block_height, transaction_hash, total_input_value
FROM read_parquet('data/transactions/*.parquet')
ORDER BY total_input_value DESC
LIMIT 10;

-- Number of transactions per block
SELECT block_height, COUNT(transaction_hash) as tx_count
FROM read_parquet('data/transactions/*.parquet')
GROUP BY block_height
ORDER BY block_height;
```

## Deployment to Hetzner

To deploy the project to your Hetzner VPS:

```bash
cd scripts
./push-to-hetzner.sh
```

Then SSH into your Hetzner VPS and run:

```bash
cd /mnt/data/bitcoin-dashboard/scripts
./setup-hetzner.sh
./run-all.sh
```

## Possible Enhancements

- Track only transactions over 1 BTC to reduce noise
- Add tagging of known whale wallets or exchanges
- Aggregate by day instead of block for even smaller datasets
- Extend the custom Substreams module with additional features

## License

This project is licensed under the MIT License - see the LICENSE file for details.
