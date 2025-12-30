# Testing Guide

Complete guide for testing the Prediction Market Hook on both local networks and Base Sepolia testnet.

## Table of Contents

- [Quick Start](#quick-start)
- [Local Testing](#local-testing)
- [Testnet Testing](#testnet-testing)
- [Test Commands Reference](#test-commands-reference)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Run Unit Tests Locally

```bash
# Run all tests
forge test

# Run with detailed output
forge test -vv

# Run with gas reports
forge test --gas-report

# Run specific test
forge test --match-test test_MarketCreation

# Run with coverage
forge coverage
```

### Run Integration Tests on Base Sepolia

```bash
# Option 1: Use the convenience script
./test-sepolia.sh

# Option 2: Run forge script directly
forge script script/TestBaseSepolia.s.sol:TestBaseSepolia \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

---

## Local Testing

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Solidity ^0.8.26

### Setup

```bash
# Clone and install dependencies
git clone <repo>
cd blockchain
forge install
forge build
```

### Running Tests

#### Unit Tests

```bash
# All tests
forge test

# Specific contract
forge test --match-contract PredictionMarketHookTest

# Specific test function
forge test --match-test test_TimeDecayFees

# With detailed logs
forge test -vvv

# With trace
forge test -vvvv
```

#### Gas Reporting

```bash
forge test --gas-report
```

Expected gas costs:
| Operation | Estimated Gas |
|-----------|---------------|
| Create Market | ~200K |
| Mint Complete Set | ~150K |
| Swap | ~180K |
| Burn Complete Set | ~120K |
| Resolve Market | ~100K |
| Redeem Winning | ~80K |

#### Coverage

```bash
# Generate coverage report
forge coverage

# Target: 100% coverage
```

### Test Structure

```
test/
├── unit/
│   ├── PredictionMarketHook.t.sol    # Hook unit tests
│   └── TokenManager.t.sol             # TokenManager unit tests
└── integration/
    └── FullFlow.t.sol                 # End-to-end scenarios
```

---

## Testnet Testing

### Prerequisites

1. Contracts deployed on Base Sepolia (see `DEPLOYMENT.md`)
2. Private key with ETH for gas fees
3. Test collateral tokens (MockUSDC recommended)

### Environment Setup

Create or update `.env`:

```env
PRIVATE_KEY=0x...
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=...

# Contract addresses (auto-loaded from deployments/base-sepolia.json)
POOL_MANAGER=0x...
COLLATERAL_TOKEN=0x...
HOOK_ADDRESS=0x...
TOKEN_MANAGER=0x...
ORACLE_ADDRESS=0x...
```

### Quick Deploy + Test

```bash
# 1. Deploy with MockUSDC (recommended for testing)
DEPLOY_COLLATERAL=true forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv

# 2. Mint test tokens
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# 3. Run integration tests
./test-sepolia.sh
```

### What the Test Script Does

The `TestBaseSepolia.s.sol` script runs a comprehensive end-to-end test:

1. **Test 1: Create Market** ✅
   - Creates prediction market with unique parameters
   - Auto-creates YES/NO outcome tokens
   - Registers market with TokenManager

2. **Test 2: Mint Complete Set** ✅
   - Approves collateral spending
   - Mints 10,000 USDC worth of sets
   - Receives 10,000 YES + 10,000 NO tokens

3. **Test 3: Check Balances** ✅
   - Verifies token balances
   - Confirms complete set ownership

4. **Test 4: Burn Complete Set** ✅
   - Burns 5,000 complete sets
   - Receives 5,000 USDC back

5. **Test 5: Update Oracle** ✅
   - Updates mock oracle price
   - Verifies oracle response

### Using MockUSDC vs External Token

| Feature | MockUSDC | External Token |
|---------|----------|----------------|
| Control over supply | ✅ Full | ❌ None |
| Mint unlimited | ✅ Yes | ❌ Need faucet |
| Easy setup | ✅ Very easy | ❌ Difficult |
| Reset balances | ✅ Easy | ❌ Hard |
| Realistic | ⚠️ Less | ✅ More |
| **Best for** | **Testnet dev** | Production-like |

**Recommendation**: Use MockUSDC for testnet development.

### Acquiring Test Collateral

#### Option 1: MockUSDC (Recommended)

```bash
# Mint 10k USDC to yourself
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# Or use cast directly
cast send $COLLATERAL_TOKEN \
    "mint(address,uint256)" \
    YOUR_ADDRESS \
    10000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --legacy
```

#### Option 2: External Token

Acquire from faucet or other source (harder).

---

## Test Commands Reference

### Deployment

```bash
# Deploy with MockUSDC
DEPLOY_COLLATERAL=true forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --legacy -vvv

# Deploy with existing token
DEPLOY_COLLATERAL=false COLLATERAL_TOKEN=0x... \
forge script script/DeployTestnet.s.sol:DeployTestnet \
    --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --legacy -vvv
```

### Testing

```bash
# Full integration test suite
./test-sepolia.sh

# Dry run (simulate without broadcasting)
forge script script/TestBaseSepolia.s.sol:TestBaseSepolia \
    --rpc-url $BASE_SEPOLIA_RPC_URL --legacy -vvv

# Create market only
forge script script/CreateMarket.s.sol:CreateMarket \
    --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --legacy
```

### Token Operations

```bash
# Check collateral balance
cast call $COLLATERAL_TOKEN "balanceOf(address)(uint256)" \
    YOUR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL

# Approve TokenManager
cast send $COLLATERAL_TOKEN "approve(address,uint256)" \
    $TOKEN_MANAGER 1000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL --legacy

# Mint complete set
cast send $TOKEN_MANAGER "mintSet(bytes32,uint256)" \
    MARKET_ID 100000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL --legacy

# Burn complete set
cast send $TOKEN_MANAGER "burnSet(bytes32,uint256)" \
    MARKET_ID 50000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL --legacy
```

### Contract State Queries

```bash
# Get outcome count for market
cast call $TOKEN_MANAGER "getOutcomeCount(bytes32)(uint256)" \
    MARKET_ID --rpc-url $BASE_SEPOLIA_RPC_URL

# Get complete set balance
cast call $TOKEN_MANAGER "getCompleteSetBalance(bytes32,address)(uint256)" \
    MARKET_ID YOUR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL

# Get oracle price
cast call $ORACLE_ADDRESS \
    "latestRoundData()(uint80,int256,uint256,uint256,uint80)" \
    --rpc-url $BASE_SEPOLIA_RPC_URL

# Check if market is tradeable
cast call $HOOK_ADDRESS "isTradeable(bytes32)(bool)" \
    POOL_ID --rpc-url $BASE_SEPOLIA_RPC_URL
```

### Verification

```bash
# Verify Hook
forge verify-contract $HOOK_ADDRESS \
    src/PredictionMarketHook.sol:PredictionMarketHook \
    --constructor-args $(cast abi-encode "constructor(address,address)" $POOL_MANAGER $TOKEN_MANAGER) \
    --chain-id 84532 \
    --etherscan-api-key $BASESCAN_API_KEY

# Verify TokenManager
forge verify-contract $TOKEN_MANAGER \
    src/TokenManager.sol:TokenManager \
    --constructor-args $(cast abi-encode "constructor(address)" $HOOK_ADDRESS) \
    --chain-id 84532 \
    --etherscan-api-key $BASESCAN_API_KEY
```

### Block Explorer

```bash
# View on BaseScan
open "https://sepolia.basescan.org/address/$HOOK_ADDRESS"
open "https://sepolia.basescan.org/address/$TOKEN_MANAGER"
open "https://sepolia.basescan.org/tx/$TX_HASH"
```

---

## Troubleshooting

### "You have no collateral tokens"

**Problem**: Script can't find collateral balance

**Solutions**:
1. Verify you deployed with `DEPLOY_COLLATERAL=true`
2. Mint tokens: `forge script script/MintTestTokens.s.sol --broadcast`
3. Check balance: `cast call $COLLATERAL_TOKEN "balanceOf(address)(uint256)" YOUR_ADDRESS`

### "Failed to initialize market"

**Problem**: Market already exists or invalid parameters

**Solutions**:
1. Market IDs must be unique - script auto-generates unique IDs
2. Event timestamp must be in future
3. Oracle address must be valid

### "Transaction reverted"

**Problem**: Transaction failed on-chain

**Solutions**:
1. Check gas balance: `cast balance YOUR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL`
2. Verify contracts deployed correctly
3. Check contract permissions (only Hook can call TokenManager)
4. Review error message with `-vvvv` flag

### "Insufficient allowance"

**Problem**: TokenManager not approved to spend collateral

**Solution**:
```bash
cast send $COLLATERAL_TOKEN "approve(address,uint256)" \
    $TOKEN_MANAGER 999999999999 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL --legacy
```

### "Insufficient balance"

**Problem**: Not enough tokens to burn complete set

**Solution**:
- Check balances for ALL outcome tokens
- You need equal amounts of each outcome to burn a set
- Query: `cast call $TOKEN_MANAGER "getCompleteSetBalance(bytes32,address)" MARKET_ID YOUR_ADDRESS`

### Test Failure: "Hook address doesn't match"

**Problem**: Deployed hook address doesn't have correct permissions

**Solution**:
- Hook address must match specific prefix/suffix requirements
- Re-run deployment script (it will mine for correct address)

### Debugging

```bash
# Get transaction receipt
cast receipt TX_HASH --rpc-url $BASE_SEPOLIA_RPC_URL

# Check latest block
cast block latest --rpc-url $BASE_SEPOLIA_RPC_URL

# Decode calldata
cast calldata-decode "mintSet(bytes32,uint256)" CALLDATA

# Send debug transaction
cast send --legacy --gas-limit 500000 ...
```

---

## Advanced Testing

### Testing Market Resolution

```bash
# 1. Create market with near-future timestamp
# 2. Wait for timestamp to pass
# 3. Update oracle with result
cast send $ORACLE_ADDRESS "setLatestAnswer(int256)" 1 \
    --private-key $PRIVATE_KEY --rpc-url $BASE_SEPOLIA_RPC_URL

# 4. Resolve market
cast send $HOOK_ADDRESS "resolveMarket(bytes32)" POOL_ID \
    --private-key $PRIVATE_KEY --rpc-url $BASE_SEPOLIA_RPC_URL

# 5. Wait for dispute period (72 hours)
# 6. Redeem winning tokens
cast send $HOOK_ADDRESS "redeemWinningTokens(bytes32,uint256)" \
    POOL_ID AMOUNT \
    --private-key $PRIVATE_KEY --rpc-url $BASE_SEPOLIA_RPC_URL
```

### Multi-User Testing

Use different private keys to simulate multiple traders:

```bash
# User 1 mints sets
cast send $TOKEN_MANAGER "mintSet(bytes32,uint256)" MARKET_ID 100000 \
    --private-key $USER1_KEY --rpc-url $BASE_SEPOLIA_RPC_URL

# User 2 mints sets
cast send $TOKEN_MANAGER "mintSet(bytes32,uint256)" MARKET_ID 100000 \
    --private-key $USER2_KEY --rpc-url $BASE_SEPOLIA_RPC_URL

# Users trade outcome tokens on Uniswap V4 (when available)
```

### Edge Case Testing

```bash
# Try to burn incomplete set (should fail)
# Burn only YES tokens first, then try to burn set

# Try to trade resolved market (should fail)

# Try to resolve before event timestamp (should fail)

# Try to redeem during dispute period (should fail)
```

---

## Next Steps

After successful testing:

1. ✅ **Verify on BaseScan** - Check all transactions succeeded
2. ✅ **Test swapping** - Use Uniswap V4 interface (if available)
3. ✅ **Test resolution** - Wait for event and test oracle resolution
4. ✅ **Multi-outcome** - Test markets with 3-10 outcomes
5. ✅ **Audit preparation** - Document all test cases for auditors

---

## Resources

- [Base Sepolia Explorer](https://sepolia.basescan.org/)
- [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)
- [Foundry Book](https://book.getfoundry.sh/)
- [Uniswap V4 Docs](https://docs.uniswap.org/contracts/v4/overview)

---

**Last Updated**: December 30, 2024
