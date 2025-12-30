# Deployment Guide

## Overview

This guide covers deploying the prediction market system to testnets (Base Sepolia or Arbitrum Sepolia).

## Two Deployment Options

### Option 1: Deploy with Own Test Token (Recommended)

Deploy your own MockUSDC token that you can mint/burn as needed.

**Pros:**
- Full control over token supply
- Can mint unlimited tokens for testing
- No dependency on external faucets
- Easy to reset test scenarios

**Setup:**
```bash
# In your .env file
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408  # Base Sepolia
DEPLOY_COLLATERAL=true  # This is the default
```

**Deploy:**
```bash
forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

This will deploy:
1. MockUSDC (1M initial supply to deployer)
2. MockChainlinkOracle
3. PredictionMarketHook
4. TokenManager

### Option 2: Use Existing Testnet Token

Use an already deployed testnet USDC or other ERC20.

**Pros:**
- More realistic integration testing
- Tests you don't control the collateral

**Setup:**
```bash
# In your .env file
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
COLLATERAL_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
DEPLOY_COLLATERAL=false
```

**Deploy:**
```bash
forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

## After Deployment

### 1. Update .env file

The script will output the deployed addresses. Update your `.env`:

```env
COLLATERAL_TOKEN=<deployed_address>
HOOK_ADDRESS=<deployed_address>
TOKEN_MANAGER=<deployed_address>
ORACLE_ADDRESS=<deployed_address>
```

### 2. Mint Test Tokens (if using MockUSDC)

Mint tokens to your address or other test addresses:

```bash
# Mint default amount (10k USDC) to yourself
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# Mint custom amount to specific address
MINT_TO=0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb \
MINT_AMOUNT=50000000000 \
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

Or use cast directly:

```bash
# Mint 10k USDC to an address
cast send $COLLATERAL_TOKEN \
    "mint(address,uint256)" \
    YOUR_ADDRESS \
    10000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL
```

### 3. Verify Contracts

See verification commands in the deployment output or check `TEST_COMMANDS.md`.

## Network-Specific Information

### Base Sepolia

- **Chain ID:** 84532
- **PoolManager:** `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`
- **RPC:** `https://sepolia.base.org`
- **Explorer:** `https://sepolia.basescan.org`
- **Faucet:** `https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet`

### Arbitrum Sepolia

- **Chain ID:** 421614
- **PoolManager:** TBD
- **RPC:** `https://sepolia-rollup.arbitrum.io/rpc`
- **Explorer:** `https://sepolia.arbiscan.io`
- **Faucet:** `https://faucet.triangleplatform.com/arbitrum/sepolia`

## Environment Variables Reference

```env
# Required
PRIVATE_KEY=0x...
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408

# Optional (for deploying own token)
DEPLOY_COLLATERAL=true

# Optional (for using existing token)
COLLATERAL_TOKEN=0x...

# Deployed addresses (updated after deployment)
HOOK_ADDRESS=0x...
TOKEN_MANAGER=0x...
ORACLE_ADDRESS=0x...

# For verification
BASESCAN_API_KEY=...
ARBISCAN_API_KEY=...
```

## Common Issues

### "Insufficient balance for gas"
- Get testnet ETH from the faucet for your network

### "Hook address mismatch"
- The CREATE2 salt mining ensures the hook has the right permissions
- This is normal and expected behavior

### "Market already initialized"
- Each market needs a unique ID
- The test scripts auto-generate unique IDs based on timestamp

## Next Steps

After deployment:
1. ✅ Update `.env` with deployed addresses
2. ✅ Mint test tokens (if using MockUSDC)
3. ✅ Run the test suite (`./test-sepolia.sh`)
4. ✅ Create your first market
5. ✅ Test minting and burning outcome tokens
