# Testing Your Deployed Contracts - Quick Start

## Current Situation

You have contracts deployed to Base Sepolia but are using an external collateral token you don't control. This makes testing difficult.

## Solution

I've created a complete testing setup with two deployment options:

### ✅ **Option 1: Deploy with MockUSDC (RECOMMENDED)**

You get complete control over the collateral token - mint unlimited tokens for testing!

**Quick Deploy:**
```bash
# Set environment variable (or add to .env)
DEPLOY_COLLATERAL=true

# Deploy everything including MockUSDC
forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

**Mint test tokens:**
```bash
# Mint 10k USDC to yourself
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

### Option 2: Use Existing Token

Keep using the external token (harder for testing).

```bash
DEPLOY_COLLATERAL=false
COLLATERAL_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
```

## What I Created for You

### 1. **MockUSDC Contract** (`src/mocks/MockUSDC.sol`)
- Open minting - anyone can mint tokens
- 6 decimals (like real USDC)
- Deployer gets 1M initial supply
- Perfect for testing

### 2. **Updated Deployment Script** (`script/DeployTestnet.s.sol`)
- Now supports both deployment modes
- Automatically deploys MockUSDC if `DEPLOY_COLLATERAL=true`
- Updated console output and verification instructions

### 3. **Token Minting Script** (`script/MintTestTokens.s.sol`)
- Easy way to mint test tokens
- Mint to yourself or any address
- Supports custom amounts

### 4. **Testing Script** (`script/TestBaseSepolia.s.sol`)
- Comprehensive integration tests
- Tests full flow: create market, mint, burn, redeem
- Automatically loads your deployed addresses

### 5. **Documentation**
- **DEPLOYMENT_GUIDE.md** - Complete deployment instructions
- **TESTING.md** - Testing guide (updated)
- **TEST_COMMANDS.md** - Quick command reference

## Recommended Next Steps

### 1. Re-deploy with MockUSDC

```bash
# Add to .env
DEPLOY_COLLATERAL=true

# Deploy
forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv

# Update .env with new addresses from output
```

### 2. Mint Test Tokens

```bash
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

### 3. Run Integration Tests

```bash
./test-sepolia.sh
```

## Benefits of MockUSDC vs External Token

| Feature | MockUSDC | External Token |
|---------|----------|----------------|
| Control over supply | ✅ Full control | ❌ None |
| Mint unlimited tokens | ✅ Yes | ❌ Need faucet |
| Easy test setup | ✅ Very easy | ❌ Difficult |
| Reset balances | ✅ Easy | ❌ Hard |
| Realistic testing | ⚠️ Less realistic | ✅ More realistic |
| Dependencies | ✅ None | ❌ External contract |
| Best for | **Testnet development** | Production-like testing |

**For testnet testing, MockUSDC is clearly the better choice!**

## Quick Commands

```bash
# Deploy with MockUSDC
DEPLOY_COLLATERAL=true forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --legacy -vvv

# Mint tokens
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast

# Run tests
./test-sepolia.sh

# Check balance
cast call $COLLATERAL_TOKEN "balanceOf(address)(uint256)" YOUR_ADDRESS \
    --rpc-url $BASE_SEPOLIA_RPC_URL
```

## Questions?

Check these files for more details:
- `DEPLOYMENT_GUIDE.md` - Full deployment instructions
- `TESTING.md` - Comprehensive testing guide
- `TEST_COMMANDS.md` - Command reference
