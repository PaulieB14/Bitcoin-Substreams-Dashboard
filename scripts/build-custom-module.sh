#!/bin/bash

# Script to build a custom Substreams module
# This script will create and build a custom Substreams module for Bitcoin

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Check if Rust and Cargo are installed
if ! command -v cargo &> /dev/null; then
  echo "Error: Cargo is not installed"
  echo "Please install Rust and Cargo from https://rustup.rs/"
  exit 1
fi

# Set variables
MODULE_DIR="custom-module"

# Check if the module directory already exists
if [ -d "$MODULE_DIR" ]; then
  echo "The custom module directory already exists."
  read -p "Do you want to rebuild the existing module? (y/n) " -n 1 -r
  echo ""
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
else
  # Create the module directory
  echo "Creating custom module directory..."
  mkdir -p "$MODULE_DIR"
  
  # Initialize a new Rust project
  echo "Initializing a new Rust project..."
  cargo init --lib "$MODULE_DIR"
  
  # Create the Substreams manifest file
  echo "Creating Substreams manifest file..."
  cat > "$MODULE_DIR/substreams.yaml" << EOL
specVersion: v0.1.0
package:
  name: bitcoin_custom_module
  version: v0.1.0

imports:
  bitcoin: streamingfast/bitcoin-explorer:v0.1.0

protobuf:
  files:
    - custom.proto
  importPaths:
    - ./proto

binaries:
  default:
    type: wasm/rust-v1
    file: target/wasm32-unknown-unknown/release/custom_module.wasm

modules:
  - name: map_custom
    kind: map
    inputs:
      - source: sf.bitcoin.type.v1.Block
    output:
      type: proto:bitcoin_custom.v1.CustomOutput
EOL
  
  # Create the proto directory and custom.proto file
  echo "Creating proto directory and custom.proto file..."
  mkdir -p "$MODULE_DIR/proto"
  cat > "$MODULE_DIR/proto/custom.proto" << EOL
syntax = "proto3";

package bitcoin_custom.v1;

message CustomOutput {
  uint64 block_height = 1;
  string block_hash = 2;
  string timestamp = 3;
  uint64 transaction_count = 4;
  uint64 total_fees = 5;
  uint64 largest_transaction_value = 6;
}
EOL
  
  # Create the src directory and lib.rs file
  echo "Creating src/lib.rs file..."
  cat > "$MODULE_DIR/src/lib.rs" << EOL
mod pb;

use pb::bitcoin_custom::v1::CustomOutput;
use substreams::pb::sf::bitcoin::type_v1::Block;
use substreams_bitcoin::pb::sf::bitcoin::type_v1 as bitcoin;
use substreams::errors::Error;
use substreams::log;
use substreams::{Hex, store};
use substreams_bitcoin::utils;
use substreams::prelude::*;
use substreams_entity_change::pb::entity::EntityChanges;

#[substreams::handlers::map]
fn map_custom(block: Block) -> Result<CustomOutput, Error> {
    let block_height = block.height;
    let block_hash = Hex::encode(&block.hash);
    let timestamp = block.header.as_ref().map(|h| h.timestamp.clone()).unwrap_or_default();
    let transaction_count = block.transaction_count;
    
    let mut total_fees = 0;
    let mut largest_transaction_value = 0;
    
    for tx in block.transactions {
        // Calculate transaction fee (input - output)
        let mut total_input_value = 0;
        for input in &tx.inputs {
            total_input_value += input.value;
        }
        
        let mut total_output_value = 0;
        for output in &tx.outputs {
            total_output_value += output.value;
        }
        
        let fee = if total_input_value > total_output_value {
            total_input_value - total_output_value
        } else {
            0 // Coinbase transaction or error
        };
        
        total_fees += fee;
        
        // Track largest transaction value
        if total_input_value > largest_transaction_value {
            largest_transaction_value = total_input_value;
        }
    }
    
    Ok(CustomOutput {
        block_height,
        block_hash,
        timestamp,
        transaction_count,
        total_fees,
        largest_transaction_value,
    })
}
EOL
  
  # Create the Cargo.toml file
  echo "Creating Cargo.toml file..."
  cat > "$MODULE_DIR/Cargo.toml" << EOL
[package]
name = "custom_module"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
substreams = "0.5.0"
substreams-bitcoin = "0.1.0"
substreams-entity-change = "1.3.0"
prost = "0.11.0"
prost-types = "0.11.0"

[profile.release]
lto = true
opt-level = 's'
strip = "debuginfo"
EOL
  
  # Create the build.rs file
  echo "Creating build.rs file..."
  cat > "$MODULE_DIR/build.rs" << EOL
use std::io::Result;
use std::path::PathBuf;
use std::process::Command;

fn main() -> Result<()> {
    let proto_dir = PathBuf::from("./proto");
    let proto_file = proto_dir.join("custom.proto");

    let out_dir = PathBuf::from(std::env::var("OUT_DIR").unwrap());
    let out_file = out_dir.join("pb.rs");

    // Generate Rust code from the proto file
    Command::new("protoc")
        .arg("--rust_out")
        .arg(out_dir.to_str().unwrap())
        .arg("--proto_path")
        .arg(proto_dir.to_str().unwrap())
        .arg(proto_file.to_str().unwrap())
        .output()
        .expect("Failed to execute protoc");

    // Create the pb.rs module
    std::fs::write(
        "src/pb.rs",
        r#"
pub mod bitcoin_custom {
    pub mod v1 {
        include!(concat!(env!("OUT_DIR"), "/bitcoin_custom.v1.rs"));
    }
}
"#,
    )?;

    Ok(())
}
EOL
fi

# Install the wasm32-unknown-unknown target
echo "Installing wasm32-unknown-unknown target..."
rustup target add wasm32-unknown-unknown

# Build the custom module
echo "Building custom module..."
cd "$MODULE_DIR" || { echo "Error: Cannot access module directory"; exit 1; }
cargo build --target wasm32-unknown-unknown --release

# Check if the build was successful
if [ -f "target/wasm32-unknown-unknown/release/custom_module.wasm" ]; then
  echo "Custom module built successfully!"
  echo "You can now use this custom module with Substreams."
  echo "To use it, update the run-substreams.sh script to use this module instead of the default ones."
else
  echo "Error: Failed to build custom module"
  exit 1
fi
