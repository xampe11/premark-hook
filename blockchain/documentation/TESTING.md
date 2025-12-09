# Testing Guide

## Month 1 Testing Checklist

### ✅ Unit Tests

#### PredictionMarketHook.sol

- [x] Market creation with valid parameters
- [x] Revert on event in past
- [x] Revert on invalid oracle
- [x] Revert on invalid outcome count (< 2 or > 10)
- [x] Time decay fee calculation (all time ranges)
- [x] Trading before event
- [x] Prevent trading after event
- [x] Market resolution via oracle
- [x] Revert resolution before event
- [x] Revert double resolution
- [x] Redeem winning tokens after dispute period
- [x] Revert redemption before resolution
- [x] Revert redemption during dispute period
- [x] View functions (getMarket, isTradeable, timeUntilEvent)
- [x] Fee multiplier calculation
- [x] Full market lifecycle integration test
- [x] Fuzz test: time decay with random timestamps

#### TokenManager.sol

- [x] Register market
- [x] Mint complete set
- [x] Mint set for multiple users
- [x] Revert mint with zero amount
- [x] Revert mint with insufficient collateral
- [x] Burn complete set
- [x] Burn entire set (round trip)
- [x] Revert burn with zero amount
- [x] Revert burn with insufficient tokens
- [x] Revert burn incomplete set
- [x] Redeem winning tokens after resolution
- [x] Revert redemption before resolution
- [x] View functions (outcome count, tokens, complete set balance)
- [x] Fuzz test: mint and burn amounts
- [x] Fuzz test: multiple users independence

#### OutcomeToken.sol

- [x] Token creation with metadata
- [x] Mint (only owner)
- [x] Burn (only owner)
- [x] Revert mint/burn from non-owner

#### MockChainlinkOracle.sol

- [x] Set latest answer
- [x] Get latest round data
- [x] Get specific round data

### 🧪 Integration Tests

- [x] Create market → Mint tokens → Trade → Resolve → Redeem
- [ ] Multi-user trading scenarios
- [ ] Large volume stress tests
- [ ] Time-based scenarios (approaching event)

### 📊 Coverage Goals

```bash
forge coverage --report summary
```

**Target: 100% coverage for Month 1 contracts**

| Contract             | Statements | Branches | Functions | Lines |
| -------------------- | ---------- | -------- | --------- | ----- |
| PredictionMarketHook | 100%       | 100%     | 100%      | 100%  |
| TokenManager         | 100%       | 100%     | 100%      | 100%  |
| OutcomeToken         | 100%       | 100%     | 100%      | 100%  |

### ⚡ Gas Profiling

```bash
forge test --gas-report
```

**Optimization Targets:**

- Market creation: < 250K gas
- Mint set: < 150K gas
- Swap: < 200K gas
- Burn set: < 130K gas

## Running Tests

### Run All Tests

```bash
forge test -vv
```

### Run Specific Test File

```bash
forge test --match-path test/PredictionMarketHook.t.sol -vv
```

### Run Specific Test Function

```bash
forge test --match-test test_MintSet -vvv
```

### Run with Gas Report

```bash
forge test --gas-report
```

### Run with Coverage

```bash
forge coverage
forge coverage --report lcov
```

### Run Fuzz Tests

```bash
forge test --match-test testFuzz -vvv
```

## Test Scenarios

### Scenario 1: Happy Path Binary Market

1. **Setup**

   - Deploy contracts
   - Create market: "Will BTC hit $100K?"
   - Event in 30 days

2. **User Actions**

   - Alice mints 100 YES + 100 NO tokens
   - Alice sells 50 NO tokens to Bob
   - Bob buys more YES tokens
   - Charlie mints and burns complete set

3. **Resolution**
   - Event occurs
   - Oracle reports: YES wins
   - 72-hour dispute passes
   - Alice redeems 100 YES → 100 USDC
   - Bob redeems his YES tokens
   - Charlie's NO tokens are worthless

### Scenario 2: Time Decay Edge Cases

1. **Create market 1 year out**

   - Verify 1x fee multiplier

2. **Warp to 6 days before**

   - Verify 1.5x fee multiplier

3. **Warp to 12 hours before**

   - Verify 2x fee multiplier

4. **Warp to 30 minutes before**

   - Verify 3x fee multiplier

5. **Warp past event**
   - Verify trading frozen

### Scenario 3: Multi-User Competition

1. **Alice and Bob both bullish**

   - Both buy YES tokens
   - Price moves to $0.70

2. **Charlie bearish**

   - Buys NO tokens
   - Price rebalances to $0.60

3. **Last-minute volatility**
   - Heavy trading as event approaches
   - Fees increase with time decay

### Scenario 4: Complete Set Arbitrage

1. **Market skewed**

   - YES at $0.55, NO at $0.50 (adds to $1.05)

2. **Arbitrage opportunity**

   - Mint set for $1.00
   - Sell YES for $0.55 + NO for $0.50
   - Profit: $0.05 per set

3. **Result**
   - Prices converge back to $1.00 total
   - Market efficiency restored

## Manual Testing Checklist

### On Testnet

- [ ] Deploy all contracts
- [ ] Create simple binary market
- [ ] Add liquidity
- [ ] Execute trades
- [ ] Verify time decay fees increase
- [ ] Resolve market via oracle
- [ ] Redeem winning tokens
- [ ] Check all events emitted
- [ ] Verify gas costs match estimates

### Frontend Integration

- [ ] Connect wallet
- [ ] Display market information
- [ ] Show current probabilities
- [ ] Execute mint/burn operations
- [ ] Execute swaps
- [ ] Show user balances
- [ ] Display time remaining
- [ ] Show fee multipliers
- [ ] Handle resolution flow

## Debugging Tips

### Common Issues

**Issue: "Hook address mismatch"**

```
Solution: Hook must be deployed at address with correct permission bits
Use CREATE2 with proper salt calculation
```

**Issue: "Revert: Trading frozen"**

```
Solution: Event timestamp has passed or market is resolved
Check market.eventTimestamp vs block.timestamp
```

**Issue: "Insufficient balance"**

```
Solution: User needs complete set to burn
Verify user has BOTH YES and NO tokens
```

### Useful Commands

```bash
# Verbose trace of failed test
forge test --match-test test_FailingTest -vvvv

# Debug specific function
forge test --match-test test_Debug --debug

# Check storage layout
forge inspect PredictionMarketHook storage-layout

# Estimate gas
forge test --gas-report --match-test test_ExpensiveOp
```

## Security Testing

### Access Control

- [ ] Only hook can mint outcome tokens
- [ ] Only hook can resolve markets
- [ ] Only authorized can call admin functions

### Input Validation

- [ ] Reject events in the past
- [ ] Reject invalid oracle addresses
- [ ] Reject invalid outcome counts
- [ ] Reject zero amounts

### Reentrancy

- [ ] No reentrancy in mint operations
- [ ] No reentrancy in burn operations
- [ ] No reentrancy in redemption

### Edge Cases

- [ ] Handle maximum uint256 values
- [ ] Handle zero values appropriately
- [ ] Handle identical timestamps
- [ ] Handle immediate resolution

## Next Steps After Tests Pass

1. **Code Review**
   - Internal team review
   - External security review
2. **Gas Optimization**

   - Profile hotspots
   - Optimize storage layout
   - Batch operations where possible

3. **Documentation**

   - NatSpec comments
   - Architecture diagrams
   - User guides

4. **Audit Preparation**
   - Create audit scope document
   - Document known issues
   - Prepare test vectors

## Success Criteria

Month 1 is complete when:

- ✅ All unit tests pass
- ✅ 100% code coverage
- ✅ Gas costs within targets
- ✅ No critical security issues
- ✅ Code reviewed by team
- ✅ Documentation complete
