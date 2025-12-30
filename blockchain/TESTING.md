# Testing on Base Sepolia

This guide explains how to test your deployed contracts on Base Sepolia.

## Prerequisites

1. Contracts deployed on Base Sepolia (deployment addresses in `deployments/base-sepolia.json`)
2. Private key with some ETH for gas fees
3. Some collateral tokens to test minting

## Quick Start

### Option 1: Using the bash script (Recommended)

```bash
cd blockchain
./test-sepolia.sh
```

### Option 2: Using forge script directly

```bash
cd blockchain
forge script script/TestBaseSepolia.s.sol:TestBaseSepolia \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --legacy \
    -vvv
```

## What the Test Script Does

The `TestBaseSepolia.s.sol` script runs a comprehensive test suite:

1. **Test 1: Create Market** - Creates a new prediction market with unique parameters
2. **Test 2: Mint Set** - Mints a complete set of outcome tokens (YES/NO)
3. **Test 3: Check Balances** - Verifies token balances for all outcomes
4. **Test 4: Burn Set** - Burns half of the complete set to get collateral back
5. **Test 5: Update Oracle** - Updates the mock oracle price

## Environment Variables

Make sure your `.env` file contains:

```env
PRIVATE_KEY=your_private_key_here
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# These will be loaded from deployments/base-sepolia.json automatically
POOL_MANAGER=
COLLATERAL_TOKEN=
HOOK_ADDRESS=
TOKEN_MANAGER=
ORACLE_ADDRESS=
```

## Current Deployment (Base Sepolia)

The script automatically loads these addresses from `deployments/base-sepolia.json`:

- **PoolManager**: `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408`
- **CollateralToken**: `0x036CbD53842c5426634e7929541eC2318f3dCF7e`
- **Hook**: `0x4641d2DEB741D2422D97E56a5559598501fc20c0`
- **TokenManager**: `0x4eeDf1b397DB6419a50B7f3B9F0688058f4F66c9`
- **Oracle**: `0xc33cDAd08F9EdE466104677c4a3257021b4cfA0E`

## Testing Individual Functions

You can also test specific markets by modifying the script or creating new test functions.

### Example: Test an existing market

```bash
forge script script/TestBaseSepolia.s.sol:TestBaseSepolia \
    --sig "testExistingMarket(bytes32)" <MARKET_ID> \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast
```

## Acquiring Test Collateral

### If Using MockUSDC (Recommended)

If you deployed with `DEPLOY_COLLATERAL=true`, you have a MockUSDC token you control:

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
    --rpc-url $BASE_SEPOLIA_RPC_URL
```

### If Using Existing Token

You'll need to acquire tokens from a faucet or other source.

## Troubleshooting

### "You have no collateral tokens"
- Check that you have the collateral token at the address above
- If it's a mock token, deploy a script to mint some to your address

### "Failed to initialize market"
- Market might already exist - each market needs a unique ID
- The script automatically generates unique market IDs based on timestamp

### "Transaction reverted"
- Check you have enough gas (ETH) on Base Sepolia
- Verify all contracts are deployed correctly
- Check contract permissions

## Next Steps

After running the tests successfully:

1. Check the transactions on [Base Sepolia Explorer](https://sepolia.basescan.org/)
2. Verify your token balances
3. Test swapping on the Uniswap v4 interface (if available)
4. Test market resolution after the event timestamp

## Advanced Testing

For more complex scenarios, you can modify `TestBaseSepolia.s.sol`:

- Test multiple users by using different private keys
- Test market resolution and redemption
- Test edge cases like trying to burn incomplete sets
- Test oracle price updates and their effects on the market
