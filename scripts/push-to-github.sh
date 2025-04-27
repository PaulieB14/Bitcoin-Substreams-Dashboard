#!/bin/bash

# Script to initialize a Git repository and push it to GitHub
# This script will:
# 1. Initialize a Git repository
# 2. Add all files
# 3. Commit the changes
# 4. Add the remote repository
# 5. Push to GitHub

# Navigate to the project directory
cd "$(dirname "$0")/.." || { echo "Error: Cannot access project directory"; exit 1; }

# Set variables
GITHUB_REPO="git@github.com:PaulieB14/Bitcoin-Substreams-Dashboard.git"

# Check if Git is installed
if ! command -v git &> /dev/null; then
  echo "Error: Git is not installed"
  echo "Please install Git to push to GitHub"
  exit 1
fi

# Check if the directory is already a Git repository
if [ -d ".git" ]; then
  echo "Git repository already initialized"
else
  echo "Initializing Git repository..."
  git init
fi

# Add all files
echo "Adding files to Git..."
git add .

# Commit the changes
echo "Committing changes..."
git commit -m "Initial commit: Bitcoin Substreams Dashboard"

# Check if the remote repository is already added
if git remote | grep -q "origin"; then
  echo "Remote repository already added"
else
  echo "Adding remote repository..."
  git remote add origin "$GITHUB_REPO"
fi

# Push to GitHub
echo "Pushing to GitHub..."
git push -u origin main || {
  echo "Failed to push to main branch, trying master branch..."
  git push -u origin master
}

echo "Repository pushed to GitHub successfully."
echo "GitHub repository: $GITHUB_REPO"
