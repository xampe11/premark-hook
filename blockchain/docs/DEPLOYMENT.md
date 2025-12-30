# Deployment Guide

Complete guide for deploying the Prediction Market Hook to testnets and mainnet.

## Table of Contents

- [Quick Start](#quick-start)
- [Deployment Options](#deployment-options)
- [Step-by-Step Deployment](#step-by-step-deployment)
- [Network Information](#network-information)
- [Post-Deployment](#post-deployment)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Deploy to Base Sepolia (Recommended for Testing)

```bash
# 1. Set up environment
cp .env.example .env
# Edit .env with your PRIVATE_KEY and RPC URLs

# 2. Deploy with MockUSDC (recommended)
DEPLOY_COLLATERAL=true forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv

# 3. Update .env with deployed addresses from output

# 4. Mint test tokens
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# 5. Run integration tests
./test-sepolia.sh
```

---

## Deployment Options

### Option 1: Deploy with MockUSDC (Recommended for Testing)

Deploy your own test USDC token that you can mint/burn as needed.

**Advantages:**
- ✅ Full control over token supply
- ✅ Mint unlimited tokens for testing
- ✅ No dependency on external faucets
- ✅ Easy to reset test scenarios
- ✅ Perfect for rapid iteration

**Use Case:** Testnet development, integration testing, demos

**Configuration:**
```env
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408  # Base Sepolia
DEPLOY_COLLATERAL=true
```

**Deploy Command:**
```bash
forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

**Deploys:**
1. MockUSDC (1M initial supply to deployer)
2. MockChainlinkOracle
3. PredictionMarketHook
4. TokenManager

### Option 2: Use Existing Token

Use an already deployed testnet USDC or other ERC20.

**Advantages:**
- ✅ More realistic integration testing
- ✅ Tests production-like scenarios
- ✅ Validates with external dependencies

**Use Case:** Pre-production testing, partner integrations

**Configuration:**
```env
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
COLLATERAL_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e  # Existing token
DEPLOY_COLLATERAL=false
```

**Deploy Command:**
```bash
forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

---

## Step-by-Step Deployment

### Prerequisites

1. **Install Foundry**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone Repository**
   ```bash
   git clone <repo>
   cd blockchain
   forge install
   ```

3. **Get Testnet ETH**
   - Base Sepolia: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
   - Arbitrum Sepolia: https://faucet.triangleplatform.com/arbitrum/sepolia

4. **Setup Environment**
   ```bash
   cp .env.example .env
   ```

   Edit `.env`:
   ```env
   PRIVATE_KEY=0x...
   BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
   BASESCAN_API_KEY=...  # Optional, for verification

   POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
   DEPLOY_COLLATERAL=true
   ```

### Step 1: Deploy Contracts

```bash
# Deploy to Base Sepolia
forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

**Expected Output:**
```
== Deployment Summary ==
Network: Base Sepolia (84532)
PoolManager: 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408

Deployed Addresses:
- MockUSDC:              0x9b882e879Cf9aeEa8556560E467CD3bb87Af7F77
- MockOracle:            0x27Bb58451a8eAbb79Af749234874Dcc8b99db40b
- PredictionMarketHook:  0x2B8DCE2F738BbFE5F84D62F55806AE6dDe68E0c0
- TokenManager:          0xb01e700266faae9b61D0F0E436961e1C5c441F15

✅ Deployment successful!
```

### Step 2: Update Configuration

Update `.env` with deployed addresses:

```env
COLLATERAL_TOKEN=0x9b882e879Cf9aeEa8556560E467CD3bb87Af7F77
ORACLE_ADDRESS=0x27Bb58451a8eAbb79Af749234874Dcc8b99db40b
HOOK_ADDRESS=0x2B8DCE2F738BbFE5F84D62F55806AE6dDe68E0c0
TOKEN_MANAGER=0xb01e700266faae9b61D0F0E436961e1C5c441F15
```

Addresses are also saved to `deployments/base-sepolia.json`.

### Step 3: Mint Test Tokens (If Using MockUSDC)

```bash
# Mint 10k USDC to yourself
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# Or mint custom amount to specific address
MINT_TO=0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb \
MINT_AMOUNT=50000000000 \
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

**Direct minting with cast:**
```bash
cast send $COLLATERAL_TOKEN \
    "mint(address,uint256)" \
    YOUR_ADDRESS \
    10000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --legacy
```

### Step 4: Verify Contracts (Optional)

```bash
# Verify Hook
forge verify-contract $HOOK_ADDRESS \
    src/PredictionMarketHook.sol:PredictionMarketHook \
    --constructor-args $(cast abi-encode "constructor(address,address)" $POOL_MANAGER $TOKEN_MANAGER) \
    --chain-id 84532 \
    --etherscan-api-key $BASESCAN_API_KEY \
    --watch

# Verify TokenManager
forge verify-contract $TOKEN_MANAGER \
    src/TokenManager.sol:TokenManager \
    --constructor-args $(cast abi-encode "constructor(address)" $HOOK_ADDRESS) \
    --chain-id 84532 \
    --etherscan-api-key $BASESCAN_API_KEY \
    --watch

# Verify MockUSDC
forge verify-contract $COLLATERAL_TOKEN \
    src/mocks/MockUSDC.sol:MockUSDC \
    --chain-id 84532 \
    --etherscan-api-key $BASESCAN_API_KEY \
    --watch

# Verify Oracle
forge verify-contract $ORACLE_ADDRESS \
    src/mocks/MockChainlinkOracle.sol:MockChainlinkOracle \
    --chain-id 84532 \
    --etherscan-api-key $BASESCAN_API_KEY \
    --watch
```

### Step 5: Run Integration Tests

```bash
# Run full test suite
./test-sepolia.sh

# Or manually
forge script script/TestBaseSepolia.s.sol:TestBaseSepolia \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

---

## Network Information

### Base Sepolia (Recommended)

| Property | Value |
|----------|-------|
| **Chain ID** | 84532 |
| **PoolManager** | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| **RPC URL** | `https://sepolia.base.org` |
| **Explorer** | https://sepolia.basescan.org |
| **Faucet** | https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet |
| **Status** | ✅ Tested & Working |

### Arbitrum Sepolia

| Property | Value |
|----------|-------|
| **Chain ID** | 421614 |
| **PoolManager** | TBD |
| **RPC URL** | `https://sepolia-rollup.arbitrum.io/rpc` |
| **Explorer** | https://sepolia.arbiscan.io |
| **Faucet** | https://faucet.triangleplatform.com/arbitrum/sepolia |
| **Status** | ⏳ Not yet tested |

### Ethereum Sepolia

| Property | Value |
|----------|-------|
| **Chain ID** | 11155111 |
| **PoolManager** | TBD |
| **RPC URL** | `https://sepolia.infura.io/v3/YOUR_KEY` |
| **Explorer** | https://sepolia.etherscan.io |
| **Faucet** | https://sepoliafaucet.com/ |
| **Status** | ⏳ Not yet tested |

---

## Post-Deployment

### Create Your First Market

```bash
forge script script/CreateMarket.s.sol:CreateMarket \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

### View Contracts on Block Explorer

```bash
# Hook
open "https://sepolia.basescan.org/address/$HOOK_ADDRESS"

# TokenManager
open "https://sepolia.basescan.org/address/$TOKEN_MANAGER"

# Collateral Token
open "https://sepolia.basescan.org/address/$COLLATERAL_TOKEN"
```

### Monitor Events

```bash
# Watch for MarketCreated events
cast logs --address $HOOK_ADDRESS \
    --rpc-url $BASE_SEPOLIA_RPC_URL

# Watch for SetMinted events
cast logs --address $TOKEN_MANAGER \
    --rpc-url $BASE_SEPOLIA_RPC_URL
```

---

## Troubleshooting

### "Insufficient balance for gas"

**Problem:** Not enough ETH for transaction fees

**Solution:**
- Get testnet ETH from faucet (links above)
- Check balance: `cast balance YOUR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL`

### "Hook address doesn't match"

**Problem:** Deployed hook address doesn't have correct permission flags

**Solution:**
- This is normal! The deployment script mines for the correct address
- The script uses CREATE2 with salt mining to find valid hook address
- Just wait for the mining to complete (usually <30 seconds)

### "Market already initialized"

**Problem:** Trying to create duplicate market

**Solution:**
- Each market needs a unique ID
- Test scripts auto-generate unique IDs based on timestamp
- If deploying manually, use: `bytes32 marketId = keccak256(abi.encode("unique", block.timestamp));`

### "Transaction reverted without reason"

**Problem:** Generic revert, need more info

**Solution:**
```bash
# Re-run with maximum verbosity
forge script ... -vvvv

# Or simulate first (no broadcast)
forge script ... --legacy -vvv  # Remove --broadcast flag
```

### "Nonce too low"

**Problem:** Stale nonce from previous failed transaction

**Solution:**
```bash
# Check current nonce
cast nonce YOUR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL

# Wait a few seconds and retry
# Or use --slow flag with forge
```

### Contract Verification Failing

**Problem:** Etherscan verification rejected

**Common Issues:**
1. Wrong constructor args
2. Compiler version mismatch
3. Optimizer settings mismatch
4. Flattening needed

**Solution:**
```bash
# Flatten contract
forge flatten src/PredictionMarketHook.sol > PredictionMarketHook_flat.sol

# Verify with exact compiler settings from foundry.toml
forge verify-contract $ADDRESS ... --compiler-version 0.8.26

# Check verification status
cast etherscan-source $ADDRESS --chain 84532
```

---

## Environment Variables Reference

### Required

```env
PRIVATE_KEY=0x...                          # Your deployer private key
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
```

### Optional (Deployment Config)

```env
DEPLOY_COLLATERAL=true                     # Deploy MockUSDC (default: true)
COLLATERAL_TOKEN=0x...                     # Use existing token (if DEPLOY_COLLATERAL=false)
```

### Auto-Populated (After Deployment)

```env
HOOK_ADDRESS=0x...
TOKEN_MANAGER=0x...
ORACLE_ADDRESS=0x...
COLLATERAL_TOKEN=0x...                     # If deployed
```

### Optional (Verification)

```env
BASESCAN_API_KEY=...                       # For Base Sepolia verification
ARBISCAN_API_KEY=...                       # For Arbitrum Sepolia
ETHERSCAN_API_KEY=...                      # For Ethereum Sepolia
```

---

## Deployment Checklist

Before deploying:
- [ ] Foundry installed and updated (`foundryup`)
- [ ] Repository cloned and dependencies installed (`forge install`)
- [ ] Testnet ETH acquired from faucet
- [ ] `.env` configured with private key and RPC URLs
- [ ] `POOL_MANAGER` address set for target network

After deployment:
- [ ] Deployment addresses saved to `.env`
- [ ] Deployment JSON saved to `deployments/` directory
- [ ] Test tokens minted (if using MockUSDC)
- [ ] Contracts verified on block explorer (optional)
- [ ] Integration tests passed
- [ ] First market created and tested

---

## Next Steps

1. ✅ **Test the system** - Run `./test-sepolia.sh`
2. ✅ **Create markets** - Use `CreateMarket.s.sol` script
3. ✅ **Build frontend** - Connect UI to deployed contracts
4. ✅ **Add liquidity** - Provide initial liquidity to pools
5. ✅ **Prepare for audit** - Document all contracts and flows
6. ✅ **Plan mainnet** - When ready for production

---

## Production Deployment (Mainnet)

### ⚠️ Before Mainnet

**Requirements:**
- [ ] 3+ security audits completed (OpenZeppelin, Trail of Bits, Sherlock)
- [ ] $500K+ bug bounty program live
- [ ] Extensive testnet testing (>$1M test volume)
- [ ] Multi-sig setup for admin functions
- [ ] Emergency pause mechanism tested
- [ ] Real Chainlink oracles configured
- [ ] Legal review completed
- [ ] Insurance coverage in place

**Deployment Differences:**
1. Use real USDC/USDT as collateral
2. Use production Chainlink oracles
3. Deploy behind proxy for upgradeability
4. Use Gnosis Safe multi-sig for admin
5. Set up monitoring and alerts
6. Configure circuit breakers
7. Gradual rollout with volume caps

---

**Last Updated**: December 30, 2024
