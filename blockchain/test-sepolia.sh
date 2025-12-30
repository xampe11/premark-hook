#!/bin/bash

# Test script for Base Sepolia deployment
# Usage: ./test-sepolia.sh

set -e

echo "======================================"
echo "Base Sepolia Testing Script"
echo "======================================"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    echo "Please create a .env file with your PRIVATE_KEY and RPC URLs"
    exit 1
fi

# Load environment variables
source .env

# Check if BASE_SEPOLIA_RPC_URL is set
if [ -z "$BASE_SEPOLIA_RPC_URL" ]; then
    echo "Warning: BASE_SEPOLIA_RPC_URL not set in .env"
    echo "Using default Base Sepolia RPC..."
    BASE_SEPOLIA_RPC_URL="https://sepolia.base.org"
fi

# Run the test script
echo "Running integration tests on Base Sepolia..."
echo ""

forge script script/TestBaseSepolia.s.sol:TestBaseSepolia \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv

echo ""
echo "======================================"
echo "Tests completed!"
echo "======================================"
