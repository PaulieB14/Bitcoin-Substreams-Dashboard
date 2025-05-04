#!/bin/bash

# Script to build a custom Bitcoin Substreams module

# Navigate to the project directory
cd "$(dirname "$0")/..\" || { echo "Error: Cannot access project directory"; exit 1; }

# Check for required dependencies
if ! command -v cargo &> /dev/null; then
    echo "Error: Rust and Cargo are required to build a custom module."
    echo "Please install Rust from https://rustup.rs/"
    exit 1
fi

if ! command -v substreams &> /dev/null; then
    echo "Error: Substreams CLI is required to build a custom module."
    echo "Please install Substreams: brew install substreams"
    exit 1
fi

# Create the custom module directory
MODULE_DIR="bitcoin-custom-module"
mkdir -p "$MODULE_DIR"
cd "$MODULE_DIR" || exit 1

# Initialize a new Rust project if it doesn't exist
if [ ! -f "Cargo.toml" ]; then
    echo "Initializing a new Rust project for the custom module..."
    cargo init --lib
    
    # Update Cargo.toml
    cat > Cargo.toml << EOF
[package]
name = "bitcoin-custom-module"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
substreams = "0.5"
substreams-bitcoin = "0.1"
prost = "0.11"
prost-types = "0.11"
hex = "0.4.3"
serde_json = "1.0"
num-bigint = "0.4"
num-traits = "0.2"

[profile.release]
lto = true
opt-level = 's'
strip = "debuginfo"
EOF
fi

# Create the proto file
mkdir -p "proto"
cat > "proto/bitcoin.proto" << EOF
syntax = "proto3";

package bitcoin.custom.v1;

message BlockStats {
    uint64 height = 1;
    uint64 timestamp = 2;
    uint32 transaction_count = 3;
    uint64 total_fees = 4;
    uint64 largest_transaction_value = 5;
    string largest_transaction_hash = 6;
}

message WhaleTransaction {
    uint64 block_height = 1;
    uint64 block_timestamp = 2;
    string transaction_hash = 3;
    uint64 value = 4;
    repeated string input_addresses = 5;
    repeated string output_addresses = 6;
}
EOF

# Create lib.rs with the custom module
mkdir -p "src"
cat > "src/lib.rs" << EOF
use substreams::errors::Error;
use substreams::pb::substreams::Clock;
use substreams::{log, Hex};
use substreams_bitcoin::{pb as bitcoin, Block};

#[substreams::handlers::map]
fn map_block_stats(block: Block) -> Result<bitcoin::custom::v1::BlockStats, Error> {
    // Find the largest transaction in the block
    let mut largest_tx_value = 0u64;
    let mut largest_tx_hash = String::new();
    
    for tx in block.transactions() {
        let total_value: u64 = tx.outputs().iter().map(|o| o.value).sum();
        if total_value > largest_tx_value {
            largest_tx_value = total_value;
            largest_tx_hash = Hex::encode(tx.hash());
        }
    }
    
    // Calculate total fees for the block
    let total_fees = calculate_block_fees(&block);
    
    // Create the BlockStats message
    Ok(bitcoin::custom::v1::BlockStats {
        height: block.number,
        timestamp: block.timestamp.unwrap_or_default().seconds as u64,
        transaction_count: block.transaction_count() as u32,
        total_fees,
        largest_transaction_value: largest_tx_value,
        largest_transaction_hash: largest_tx_hash,
    })
}

#[substreams::handlers::map]
fn map_whale_transactions(block: Block) -> Result<Vec<bitcoin::custom::v1::WhaleTransaction>, Error> {
    const WHALE_THRESHOLD: u64 = 100_000_000; // 1 BTC in satoshis
    
    let mut whale_txs = Vec::new();
    
    for tx in block.transactions() {
        // Calculate total input value
        let total_value: u64 = tx.outputs().iter().map(|o| o.value).sum();
        
        // Only process transactions above the whale threshold
        if total_value >= WHALE_THRESHOLD {
            // Extract input addresses
            let input_addresses = tx
                .inputs()
                .iter()
                .filter_map(|input| input.address().map(|a| a.to_string()))
                .collect();
                
            // Extract output addresses
            let output_addresses = tx
                .outputs()
                .iter()
                .filter_map(|output| output.address().map(|a| a.to_string()))
                .collect();
                
            // Create the WhaleTransaction message
            whale_txs.push(bitcoin::custom::v1::WhaleTransaction {
                block_height: block.number,
                block_timestamp: block.timestamp.unwrap_or_default().seconds as u64,
                transaction_hash: Hex::encode(tx.hash()),
                value: total_value,
                input_addresses,
                output_addresses,
            });
        }
    }
    
    log::info!("Found {} whale transactions in block {}", whale_txs.len(), block.number);
    Ok(whale_txs)
}

// Helper function to calculate total fees in a block
fn calculate_block_fees(block: &Block) -> u64 {
    let mut total_fees = 0u64;
    
    for tx in block.transactions() {
        let input_sum: u64 = tx.inputs().iter()
            .filter_map(|input| input.previous_output.as_ref())
            .map(|prev| prev.value)
            .sum();
            
        let output_sum: u64 = tx.outputs().iter().map(|o| o.value).sum();
        
        // If input_sum > output_sum, the difference is the fee
        if input_sum > output_sum {
            total_fees += input_sum - output_sum;
        }
    }
    
    total_fees
}

#[substreams::pb::mod_custom_bitcoin_v1]
pub mod pb {
    #[derive(Clone, PartialEq, ::prost::Message)]
    pub struct BlockStats {
        #[prost(uint64, tag="1")]
        pub height: u64,
        #[prost(uint64, tag="2")]
        pub timestamp: u64,
        #[prost(uint32, tag="3")]
        pub transaction_count: u32,
        #[prost(uint64, tag="4")]
        pub total_fees: u64,
        #[prost(uint64, tag="5")]
        pub largest_transaction_value: u64,
        #[prost(string, tag="6")]
        pub largest_transaction_hash: ::prost::alloc::string::String,
    }
    
    #[derive(Clone, PartialEq, ::prost::Message)]
    pub struct WhaleTransaction {
        #[prost(uint64, tag="1")]
        pub block_height: u64,
        #[prost(uint64, tag="2")]
        pub block_timestamp: u64,
        #[prost(string, tag="3")]
        pub transaction_hash: ::prost::alloc::string::String,
        #[prost(uint64, tag="4")]
        pub value: u64,
        #[prost(string, repeated, tag="5")]
        pub input_addresses: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
        #[prost(string, repeated, tag="6")]
        pub output_addresses: ::prost::alloc::vec::Vec<::prost::alloc::string::String>,
    }
}
EOF

# Create the substreams.yaml config file
cat > "substreams.yaml" << EOF
specVersion: v0.1.0
package:
  name: bitcoin_custom_module
  version: v0.1.0

imports:
  bitcoin: https://github.com/streamingfast/firehose-bitcoin/releases/download/v0.1.0/bitcoin-v0.1.0.spkg

protobuf:
  files:
    - proto/bitcoin.proto
  importPaths:
    - ./proto

binaries:
  default:
    type: wasm/rust-v1
    file: target/wasm32-unknown-unknown/release/bitcoin_custom_module.wasm

modules:
  - name: map_block_stats
    kind: map
    initialBlock: 0
    inputs:
      - source: sf.bitcoin.type.v1.Block
    output:
      type: proto:bitcoin.custom.v1.BlockStats

  - name: map_whale_transactions
    kind: map
    initialBlock: 0
    inputs:
      - source: sf.bitcoin.type.v1.Block
    output:
      type: proto:bitcoin.custom.v1.WhaleTransaction
EOF

# Build the module
echo "Building the custom Bitcoin Substreams module..."
cargo build --target wasm32-unknown-unknown --release

# Pack the module
echo "Packing the module..."
substreams pack

echo "Custom Bitcoin Substreams module built successfully!"
echo "Module package: $(pwd)/target/bitcoin_custom_module-v0.1.0.spkg"
echo ""
echo "To use this module with the Bitcoin Substreams endpoint, run:"
echo "substreams run -e bitcoin.substreams.pinax.network:443 $(pwd)/target/bitcoin_custom_module-v0.1.0.spkg map_block_stats --start-block 881304 -H \"Authorization=Bearer \$SUBSTREAMS_API_TOKEN\""
echo ""
echo "or for whale transactions:"
echo "substreams run -e bitcoin.substreams.pinax.network:443 $(pwd)/target/bitcoin_custom_module-v0.1.0.spkg map_whale_transactions --start-block 881304 -H \"Authorization=Bearer \$SUBSTREAMS_API_TOKEN\""