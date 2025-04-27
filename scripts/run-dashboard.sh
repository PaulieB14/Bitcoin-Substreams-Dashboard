#!/bin/bash

# Script to run the Bitcoin Dashboard locally
# This script will start a simple HTTP server and open the dashboard in the default browser

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Check if the dashboard HTML file exists
if [ ! -f "dashboard/index.html" ]; then
  echo "Error: Dashboard HTML file not found"
  exit 1
fi

# Check if the data directory exists
if [ ! -d "dashboard/data" ]; then
  echo "Warning: Dashboard data directory not found"
  echo "You may need to run the query-data.sh script first"
  mkdir -p "dashboard/data"
fi

# Check if Python is installed
if command -v python3 &> /dev/null; then
  PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
  PYTHON_CMD="python"
else
  echo "Error: Python is not installed"
  echo "Please install Python to run the HTTP server"
  exit 1
fi

# Start a simple HTTP server
echo "Starting HTTP server..."
PORT=8000

# Try different ports if needed
for PORT in 8000 8080 8888 9000 9090; do
  if ! lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    echo "Using port $PORT..."
    break
  else
    echo "Port $PORT is already in use. Trying another port..."
    # If we've tried all ports and reached the last one
    if [ $PORT -eq 9090 ]; then
      echo "All standard ports are in use. Using a random high port..."
      PORT=$((10000 + RANDOM % 10000))
      break
    fi
  fi
done

# Start the server in the background
if [[ "$PYTHON_CMD" == "python3" ]]; then
  $PYTHON_CMD -m http.server $PORT &
else
  $PYTHON_CMD -m SimpleHTTPServer $PORT &
fi

SERVER_PID=$!

# Function to kill the server on exit
cleanup() {
  echo "Stopping HTTP server..."
  kill $SERVER_PID
  exit 0
}

# Register the cleanup function to be called on exit
trap cleanup EXIT

# Wait for the server to start
sleep 1

# Open the dashboard in the default browser
echo "Opening dashboard in the default browser..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  open "http://localhost:$PORT/dashboard/index.html"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux
  xdg-open "http://localhost:$PORT/dashboard/index.html"
else
  # Other OS
  echo "Please open the dashboard manually at: http://localhost:$PORT/dashboard/index.html"
fi

echo "Dashboard is now running at http://localhost:$PORT/dashboard/index.html"
echo "Press Ctrl+C to stop the server"

# Keep the script running until the user presses Ctrl+C
wait $SERVER_PID
