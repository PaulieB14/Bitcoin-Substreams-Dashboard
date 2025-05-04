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

The project is currently in a **functional stage** with the following components working:

- ✅ Dashboard UI with Chart.js visualizations
- ✅ Substreams integration for Bitcoin data processing
- ✅ Local HTTP server for viewing the dashboard
- ✅ Scripts for checking Bitcoin block height
- ✅ Configuration for Hetzner deployment
- ✅ GitHub repository setup
- ✅ Progress monitoring for Substreams processing

The following components are **in progress**:

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
│   └── data/                  # Directory for dashboard data (empty, used for backward compatibility)
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

To run the dashboard with real Bitcoin data:

```bash
cd scripts
./run-all.sh  # Runs all steps in sequence
```

### Individual Steps

#### 1. Check the Current Bitcoin Block Height

```bash
cd scripts
./check-block-height.sh
```

#### 2. Fetch Real Bitcoin Data Using Substreams

```bash
cd scripts
./run-substreams.sh
```

This script:
- Fetches real Bitcoin data using Substreams
- Processes ~3 months of Bitcoin blocks
- Converts JSON output to Parquet files

#### 3. Monitor the Progress of the Substreams Process

```bash
cd scripts
./monitor-progress.sh
```

This script:
- Checks if the Substreams process is running
- Displays the size of the output files
- Shows the status of the dashboard data files

#### 3. View the Dashboard

```bash
cd scripts
./run-dashboard.sh
```

This script:
- Starts a local HTTP server
- Opens the dashboard in your default browser
- Displays the sample data in various charts and tables

### Current Implementation

The current workflow is:

1. Use Substreams to process Bitcoin blockchain data (in progress)
2. Store the data in Parquet files (in progress)
3. Display the data directly from Parquet files in the dashboard (complete)

The Substreams process is currently running and processing ~3 months of Bitcoin blocks. Once it completes, the data will be converted to Parquet files and displayed directly in the dashboard without the need for intermediate CSV files.

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

## Tips for Building Bitcoin Substreams

- **No need for Substreams stores** (`store_set`, `store_add`, etc.)
    
    ➔ *We're just mapping events and blocks, not aggregating in the Substreams itself.*
    
- **No need to convert to String or Hex manually**
    
    ➔ *Keep data as `bytes` — easier, lighter, and faster.*
    
- **No need to hard-code any contracts**
    
    ➔ *Bitcoin doesn't use smart contracts the way Ethereum does — just process all transactions/events as valid.*
    
- **No on-chain storage needed**
    
    ➔ *Substreams module just emits flat data; storage and aggregation will happen downstream.*
    
- **Focus purely on emitting clean event or transaction data**
    
    ➔ *Substreams streams → store raw outputs into Parquet (or Clickhouse if scaling later).*
    
- **Use DuckDB (or Clickhouse) to handle all aggregation later**
    
    ➔ *You can build SQL views, aggregates, and dashboards without touching the Substreams after it emits.*

## License

This project is licensed under the MIT License - see the LICENSE file for details.
