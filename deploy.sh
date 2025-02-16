#!/bin/bash

# Load environment variables from .env file
source .env

# Check if required environment variables are set
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set in .env"
    exit 1
fi

if [ -z "$ETH_RPC_URL" ]; then
    echo "Error: ETH_RPC_URL not set in .env"
    exit 1
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "Error: ETHERSCAN_API_KEY not set in .env"
    exit 1
fi

# Deploy the contract
echo "Deploying SwapExample contract..."

forge create --rpc-url $ETH_RPC_URL \
    --private-key $PRIVATE_KEY \
    --via-ir --broadcast \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verify \
    src/Swap.sol:Swap \
    --constructor-args "0xA51afAFe0263b40EdaEf0Df8781eA9aa03E381a3" \


echo "Deployment complete!" 