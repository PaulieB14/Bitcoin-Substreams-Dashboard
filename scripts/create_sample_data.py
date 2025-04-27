import os

# Create output directory if it doesn't exist
output_dir = "../dashboard/data"
os.makedirs(output_dir, exist_ok=True)

# Create sample CSV files for the dashboard
print("Creating sample CSV files for the dashboard...")

# Average fees per block
print("Generating avg_fees.csv...")
with open(f"{output_dir}/avg_fees.csv", "w") as f:
    f.write("avg_fees\n")
    f.write("12500\n")

# Top 10 largest BTC transactions
print("Generating top_transactions.csv...")
with open(f"{output_dir}/top_transactions.csv", "w") as f:
    f.write("block_height,transaction_hash,total_input_value\n")
    for i in range(10):
        block = 881121 + i
        value = 10000000000 - i * 1000000
        f.write(f"{block},0x{i:064d},{value}\n")

# Number of transactions per block
print("Generating tx_count_per_block.csv...")
with open(f"{output_dir}/tx_count_per_block.csv", "w") as f:
    f.write("block_height,tx_count\n")
    for i in range(50):
        block = 881121 + i
        count = 1000 + i * 20
        f.write(f"{block},{count}\n")

# Top active sending addresses
print("Generating top_sending_addresses.csv...")
with open(f"{output_dir}/top_sending_addresses.csv", "w") as f:
    f.write("input_address,tx_sent\n")
    for i in range(10):
        count = 1000 - i * 50
        f.write(f"bc1{i:040d},{count}\n")

# Top active receiving addresses
print("Generating top_receiving_addresses.csv...")
with open(f"{output_dir}/top_receiving_addresses.csv", "w") as f:
    f.write("output_address,tx_received\n")
    for i in range(10):
        count = 800 - i * 40
        f.write(f"bc1{i:040d},{count}\n")

# Fee heatmap data (fees per block)
print("Generating fee_per_block.csv...")
with open(f"{output_dir}/fee_per_block.csv", "w") as f:
    f.write("block_height,total_fees\n")
    for i in range(50):
        block = 881121 + i
        fees = 10000 + i * 200
        f.write(f"{block},{fees}\n")

# Block times
print("Generating block_times.csv...")
with open(f"{output_dir}/block_times.csv", "w") as f:
    f.write("block_height,block_timestamp\n")
    for i in range(50):
        block = 881121 + i
        # Simple date calculation - just add hours
        date_str = f"2025-01-01 {i//2:02d}:{(i%2)*30:02d}:00"
        f.write(f"{block},{date_str}\n")

# Congestion tracker (transactions per block)
print("Generating congestion.csv...")
with open(f"{output_dir}/congestion.csv", "w") as f:
    f.write("block_height,transaction_count\n")
    for i in range(50):
        block = 881121 + i
        count = 1000 + i * 20 + (i % 5) * 100  # Add some variation
        f.write(f"{block},{count}\n")

print("Sample data created for testing.")
