# Quick Start Guide

Get your prediction market hook running in 5 minutes!

## Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version
```

## Setup

```bash
# 1. Clone repository
git clone <your-repo>
cd prediction-market-hook

# 2. Install dependencies

# OpenZeppelin contracts (for ERC20, Ownable, SafeERC20)
forge install OpenZeppelin/openzeppelin-contracts

# Chainlink contracts (for oracle interfaces)
forge install smartcontractkit/chainlink

# Solmate (for gas-optimized contracts)
forge install transmissions11/solmate

# Forge-std (for testing utilities)
forge install foundry-rs/forge-std

# Install Uniswap V4 Core
forge install Uniswap/v4-core

# Install Uniswap V4 Periphery
forge install Uniswap/v4-periphery

# 3. Copy environment template
cp .env.example .env
# Edit .env with your values

# 4. Build contracts
forge build
```

## Run Tests

```bash
# Quick test
forge test

# With details
forge test -vv

# With gas report
forge test --gas-report

# Specific test
forge test --match-test test_MarketCreation -vvv
```

## Create Your First Market

### 1. Deploy Contracts (Testnet)

```bash
# Set your private key in .env
forge script script/Deploy.s.sol:DeployPredictionMarket --rpc-url $BASE_RPC_URL --broadcast
```

### 2. Create a Binary Market

```solidity
// Example: "Will BTC hit $100K by end of year?"
bytes32 eventId = keccak256("BTC-100K-EOY-2024");
uint256 eventTimestamp = 1735689600; // Jan 1, 2025
address oracle = 0x...; // Your Chainlink oracle
uint8 numOutcomes = 2; // Binary (YES/NO)

bytes memory hookData = abi.encode(
    eventId,
    eventTimestamp,
    oracle,
    numOutcomes
);

// Initialize pool (creates market)
poolManager.initialize(poolKey, sqrtPriceX96, hookData);
```

### 3. Interact with Market

```solidity
// Mint complete set (get YES + NO tokens)
tokenManager.mintSet(marketId, 100e6); // 100 USDC worth

// Trade on Uniswap V4
// (Use swap router to trade YES <-> USDC)

// Burn complete set (redeem USDC)
tokenManager.burnSet(marketId, 50e6);
```

### 4. Resolve Market

```solidity
// After event occurs...
hook.resolveMarket(poolId);

// Wait 72 hours for disputes...

// Redeem winning tokens
hook.redeemWinningTokens(poolId, amount);
```

## Example Markets

### Market 1: Crypto Price

```solidity
Event: "Will ETH reach $5,000 by March 31, 2025?"
Oracle: Chainlink ETH/USD
Outcomes: YES / NO
Timeline: 3 months
```

### Market 2: Sports

```solidity
Event: "Will the Chiefs win Super Bowl LIX?"
Oracle: Chainlink Sports Data
Outcomes: YES / NO
Timeline: 2 months
```

### Market 3: Governance

```solidity
Event: "Will DAO Proposal #42 pass?"
Oracle: Custom on-chain oracle
Outcomes: YES / NO
Timeline: 7 days
```

## Common Workflows

### As a Market Creator

```solidity
// 1. Choose an event
bytes32 eventId = keccak256("YOUR-EVENT");
uint256 eventTime = block.timestamp + 30 days;

// 2. Set up oracle
address oracle = deployOracle(); // Or use existing

// 3. Create market
createMarket(eventId, eventTime, oracle, 2);

// 4. Add initial liquidity
addLiquidity(poolKey, amount);

// 5. Promote your market!
```

### As a Trader

```solidity
// 1. Research the event
// What's the real probability?

// 2. Mint tokens if needed
if (needMoreCapital) {
    tokenManager.mintSet(marketId, amount);
}

// 3. Trade to your target position
swap(yesToken, usdc, amount);

// 4. Hold until resolution
// Or trade out early if probability changes

// 5. Redeem winners
hook.redeemWinningTokens(poolId, balance);
```

### As a Liquidity Provider

```solidity
// 1. Assess market parameters
// - Event timestamp
// - Expected volume
// - Fee tier

// 2. Provide liquidity
addLiquidity(poolKey, liquidityAmount, tickLower, tickUpper);

// 3. Earn fees
// - Base trading fees
// - Time decay multipliers
// - Resolution fees

// 4. Remove liquidity after resolution
removeLiquidity(poolKey, liquidityAmount);
```

## Understanding Probabilities

### Reading the Market

```
YES Token Price: $0.65
NO Token Price: $0.35
Sum: $1.00 ✓

Interpretation:
- Market thinks YES has 65% chance
- Market thinks NO has 35% chance
```

### Identifying Value

```
Your Analysis: 75% chance of YES
Market Price: $0.65 (65% implied)
→ Value bet! Buy YES tokens

Your Analysis: 50% chance of YES
Market Price: $0.65 (65% implied)
→ Overpriced! Sell YES or buy NO
```

### Arbitrage Opportunities

```
Scenario: YES at $0.55, NO at $0.48 (sum = $1.03)

Action:
1. Mint set for $1.00
2. Sell YES for $0.55
3. Sell NO for $0.48
4. Profit: $0.03 per set

Market Impact:
- Prices converge to $1.00 total
- Efficiency restored
```

## Time Decay Strategy

### Early (30+ days out)

- Base fees (1x)
- Plenty of time for research
- Lower volatility

### Mid (7-30 days)

- Standard trading
- Watch for news/events
- 1.5x fees in final week

### Late (< 7 days)

- Higher fees (1.5x - 3x)
- Increased volatility
- Last-minute information

### Final Hour

- 3x fees!
- Only trade with strong conviction
- Or provide liquidity for high returns

## Debugging Tips

### Issue: Tests failing

```bash
# Get detailed output
forge test --match-test test_FailingTest -vvvv

# Check specific contract
forge test --match-contract PredictionMarketHookTest -vv
```

### Issue: Hook address mismatch

```bash
# Hook must be at address with correct permission bits
# Use CREATE2 deployment with proper salt

# Check required address
cast compute-address --help
```

### Issue: Transaction reverts

```bash
# Check error message
cast call $CONTRACT_ADDRESS $FUNCTION_SIGNATURE --rpc-url $RPC_URL

# Estimate gas
cast estimate $CONTRACT_ADDRESS $FUNCTION_SIGNATURE --rpc-url $RPC_URL
```

## Best Practices

### For Market Creators

✅ **DO:**

- Choose objectively verifiable events
- Use reliable oracles
- Set reasonable time horizons
- Provide initial liquidity
- Monitor your market

❌ **DON'T:**

- Create subjective events
- Use untested oracles
- Make events too far in future
- Abandon your market

### For Traders

✅ **DO:**

- Research thoroughly
- Understand time decay
- Use complete sets when appropriate
- Monitor oracle reliability
- Diversify across markets

❌ **DON'T:**

- Trade on emotion
- Ignore time decay costs
- Overleverage your position
- Trust unreliable oracles
- Put all capital in one market

### For LPs

✅ **DO:**

- Provide liquidity to both outcomes
- Monitor impermanent loss
- Collect fees regularly
- Adjust ranges as needed
- Withdraw before resolution risk

❌ **DON'T:**

- Provide one-sided liquidity
- Ignore time decay multipliers
- Leave liquidity through resolution
- Forget about winning side exposure

## Getting Help

### Resources

- 📚 **Documentation**: See README.md and ARCHITECTURE.md
- 🧪 **Tests**: Check test/ directory for examples
- 💬 **Discord**: [Your Discord Server]
- 🐦 **Twitter**: [@YourHandle]

### Common Questions

**Q: How do I calculate the exact probability?**
A: `probability = reserve_outcome / total_reserves`

**Q: Can I create markets with > 2 outcomes?**
A: Yes! Set `numOutcomes` to 3-10. (Month 2+ feature)

**Q: What if the oracle fails?**
A: Market enters dispute period. Backup resolution mechanisms available.

**Q: How do I profit as an LP?**
A: Trading fees (0.3%) + time decay multipliers + resolution fees

**Q: Can I cancel a market?**
A: No. Markets are immutable once created. Choose carefully!

## Next Steps

1. ✅ Complete Month 1 (you are here!)
2. 🔄 Start Month 2: Multi-outcome support
3. 📱 Build frontend interface
4. 🚀 Deploy to mainnet
5. 📊 Launch first markets
6. 🌍 Grow user base

## Example Code Snippets

### Create Market in Hardhat

```javascript
const eventId = ethers.utils.keccak256(
  ethers.utils.toUtf8Bytes("BTC-100K-EOY")
);
const eventTimestamp = Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60;
const oracle = "0x..."; // Your oracle
const numOutcomes = 2;

const hookData = ethers.utils.defaultAbiCoder.encode(
  ["bytes32", "uint256", "address", "uint8"],
  [eventId, eventTimestamp, oracle, numOutcomes]
);

await poolManager.initialize(poolKey, sqrtPriceX96, hookData);
```

### Monitor Market in Python

```python
from web3 import Web3

w3 = Web3(Web3.HTTPProvider('https://mainnet.base.org'))
hook = w3.eth.contract(address=hook_address, abi=hook_abi)

# Get market info
market = hook.functions.getMarket(pool_id).call()
print(f"Event: {market[0].hex()}")
print(f"Timestamp: {market[1]}")
print(f"Resolved: {market[4]}")

# Monitor events
event_filter = hook.events.ProbabilityUpdated.createFilter(fromBlock='latest')
for event in event_filter.get_all_entries():
    print(f"New probability: {event.args.probability / 1e18}")
```

---

**Ready to build?** Start with `forge test` and go from there!

**Questions?** Open an issue or reach out on Discord.

**Found a bug?** Submit a PR or report it immediately.

Happy building! 🚀
