# Quick Test Commands

## Run Full Test Suite

```bash
# Using the convenience script
./test-sepolia.sh

# Or manually with forge
forge script script/TestBaseSepolia.s.sol:TestBaseSepolia \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

## Simulate Without Broadcasting (Dry Run)

```bash
forge script script/TestBaseSepolia.s.sol:TestBaseSepolia \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --legacy \
    -vvv
```

## Create a New Market Only

```bash
forge script script/CreateMarket.s.sol:CreateMarket \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

## Check Contract on Block Explorer

```bash
# Hook contract
open "https://sepolia.basescan.org/address/0x4641d2DEB741D2422D97E56a5559598501fc20c0"

# TokenManager contract
open "https://sepolia.basescan.org/address/0x4eeDf1b397DB6419a50B7f3B9F0688058f4F66c9"

# Oracle contract
open "https://sepolia.basescan.org/address/0xc33cDAd08F9EdE466104677c4a3257021b4cfA0E"
```

## Mint Test Tokens (MockUSDC)

```bash
# Mint default amount (10k USDC) to yourself
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# Mint custom amount
MINT_TO=0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb \
MINT_AMOUNT=50000000000 \
forge script script/MintTestTokens.s.sol:MintTestTokens \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast

# Or use cast directly
cast send $COLLATERAL_TOKEN \
    "mint(address,uint256)" \
    YOUR_ADDRESS \
    10000000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL
```

## Read Contract State

```bash
# Check your collateral balance
cast call $COLLATERAL_TOKEN \
    "balanceOf(address)(uint256)" \
    YOUR_ADDRESS \
    --rpc-url $BASE_SEPOLIA_RPC_URL

# Check outcome count for a market
cast call 0x4eeDf1b397DB6419a50B7f3B9F0688058f4F66c9 \
    "getOutcomeCount(bytes32)(uint256)" \
    MARKET_ID \
    --rpc-url $BASE_SEPOLIA_RPC_URL

# Get oracle price
cast call 0xc33cDAd08F9EdE466104677c4a3257021b4cfA0E \
    "latestRoundData()(uint80,int256,uint256,uint256,uint80)" \
    --rpc-url $BASE_SEPOLIA_RPC_URL
```

## Manual Transactions (If Needed)

### Approve Collateral

```bash
cast send $COLLATERAL_TOKEN \
    "approve(address,uint256)" \
    $TOKEN_MANAGER \
    1000000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --legacy
```

### Mint Complete Set

```bash
cast send $TOKEN_MANAGER \
    "mintSet(bytes32,uint256)" \
    MARKET_ID \
    100000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --legacy
```

### Burn Complete Set

```bash
cast send $TOKEN_MANAGER \
    "burnSet(bytes32,uint256)" \
    MARKET_ID \
    50000 \
    --private-key $PRIVATE_KEY \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --legacy
```

## Environment Setup

Make sure your `.env` file has:

```env
PRIVATE_KEY=0x...
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=...

# Contract addresses (loaded from deployments/base-sepolia.json)
POOL_MANAGER=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
COLLATERAL_TOKEN=0x036CbD53842c5426634e7929541eC2318f3dCF7e
HOOK_ADDRESS=0x4641d2DEB741D2422D97E56a5559598501fc20c0
TOKEN_MANAGER=0x4eeDf1b397DB6419a50B7f3B9F0688058f4F66c9
ORACLE_ADDRESS=0xc33cDAd08F9EdE466104677c4a3257021b4cfA0E
```

## Verify Contracts

```bash
# Verify Hook
forge verify-contract \
    0x4641d2DEB741D2422D97E56a5559598501fc20c0 \
    src/PredictionMarketHook.sol:PredictionMarketHook \
    --constructor-args $(cast abi-encode "constructor(address)" 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408) \
    --chain-id 84532 \
    --etherscan-api-key $BASESCAN_API_KEY

# Verify TokenManager
forge verify-contract \
    0x4eeDf1b397DB6419a50B7f3B9F0688058f4F66c9 \
    src/TokenManager.sol:TokenManager \
    --constructor-args $(cast abi-encode "constructor(address)" 0x4641d2DEB741D2422D97E56a5559598501fc20c0) \
    --chain-id 84532 \
    --etherscan-api-key $BASESCAN_API_KEY

# Verify Oracle
forge verify-contract \
    0xc33cDAd08F9EdE466104677c4a3257021b4cfA0E \
    src/mocks/MockChainlinkOracle.sol:MockChainlinkOracle \
    --chain-id 84532 \
    --etherscan-api-key $BASESCAN_API_KEY
```

## Troubleshooting

### Get transaction receipt
```bash
cast receipt TX_HASH --rpc-url $BASE_SEPOLIA_RPC_URL
```

### Check gas balance
```bash
cast balance YOUR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL
```

### Get latest block
```bash
cast block latest --rpc-url $BASE_SEPOLIA_RPC_URL
```
