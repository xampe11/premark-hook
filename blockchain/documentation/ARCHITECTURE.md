# Technical Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Prediction Market System                     │
└─────────────────────────────────────────────────────────────────┘

         Users                                    External
          │                                         │
          ├─── Mint/Burn Sets ──────┐              │
          ├─── Swap Tokens ─────┐   │              │
          └─── Redeem Winners ──│───│──────────────│────────┐
                                │   │              │        │
                                ▼   ▼              ▼        ▼
                         ┌─────────────┐    ┌──────────┐  ┌───────┐
                         │  Uniswap V4 │◄───│  Oracle  │  │ UI/UX │
                         │ Pool Manager│    │Chainlink │  │  dApp │
                         └──────┬──────┘    └──────────┘  └───────┘
                                │
                                │ Hooks
                                ▼
                    ┌────────────────────────┐
                    │ PredictionMarketHook   │
                    │                        │
                    │ • beforeInitialize     │
                    │ • beforeSwap (time ⏰) │
                    │ • afterSwap (prob 📊)  │
                    │ • resolveMarket        │
                    │ • redeemWinning        │
                    └────────┬───────────────┘
                             │
                    ┌────────┴───────────┐
                    │                    │
                    ▼                    ▼
            ┌─────────────┐      ┌──────────────┐
            │TokenManager │      │OutcomeToken  │
            │             │      │              │
            │• mintSet    │◄────►│• YES token   │
            │• burnSet    │      │• NO token    │
            │• redeem     │      │• (ERC20)     │
            └─────────────┘      └──────────────┘
                    │
                    ▼
            ┌──────────────┐
            │  Collateral  │
            │    (USDC)    │
            └──────────────┘
```

## Contract Interactions

### 1. Market Creation Flow

```
User/Creator
    │
    │ 1. Call initialize() with hookData
    ▼
PoolManager
    │
    │ 2. Trigger beforeInitialize hook
    ▼
PredictionMarketHook
    │
    │ 3. Decode market parameters
    │ 4. Validate (timestamp, oracle, outcomes)
    │ 5. Store market data
    │ 6. Emit MarketCreated event
    ▼
Market Ready ✓
```

### 2. Complete Set Minting Flow

```
User
    │
    │ 1. Approve collateral
    │ 2. Call mintSet(amount)
    ▼
TokenManager
    │
    │ 3. Transfer collateral from user
    │ 4. Mint YES tokens to user
    │ 5. Mint NO tokens to user
    │ 6. Emit SetMinted event
    ▼
User receives: amount YES + amount NO
Locked: amount USDC
```

### 3. Trading Flow

```
User
    │
    │ 1. Initiate swap (YES for USDC)
    ▼
PoolManager
    │
    │ 2. beforeSwap hook
    ▼
PredictionMarketHook
    │
    │ 3. Check market not resolved
    │ 4. Check event not occurred
    │ 5. Calculate time decay fee
    │ 6. Return adjusted fee
    ▼
PoolManager
    │
    │ 7. Execute swap with adjusted fee
    │ 8. afterSwap hook
    ▼
PredictionMarketHook
    │
    │ 9. Update volume tracking
    │ 10. Calculate probability
    │ 11. Emit ProbabilityUpdated
    ▼
Swap complete
```

### 4. Resolution Flow

```
Event Occurs in Real World
    │
    ▼
Oracle Reports Result
    │
    ▼
Anyone can call resolveMarket()
    │
    ▼
PredictionMarketHook
    │
    │ 1. Check event timestamp passed
    │ 2. Check not already resolved
    │ 3. Query oracle
    │ 4. Validate oracle data
    │ 5. Set winning outcome
    │ 6. Freeze trading
    │ 7. Start dispute period
    │ 8. Emit MarketResolved
    ▼
Market Resolved
    │
    │ Wait 72 hours (dispute period)
    ▼
Winners can redeem tokens 1:1 for collateral
```

## Data Structures

### Market Struct

```solidity
struct Market {
    bytes32 eventId;           // "BTC-100K-2024"
    uint256 eventTimestamp;    // 1735689600 (Unix)
    address oracleAddress;     // Chainlink feed
    uint8 numOutcomes;         // 2 (binary)
    bool isResolved;           // false → true
    uint8 winningOutcome;      // 0 or 1
    uint256 resolutionTime;    // When resolved
    uint256 totalVolume;       // $1M traded
    address creator;           // 0x123...
}
```

### State Transitions

```
Market Lifecycle:
┌──────────┐  initialize  ┌─────────┐  event   ┌──────────┐  oracle  ┌──────────┐
│ Created  │─────────────►│ Trading │─────────►│ Pending  │─────────►│ Resolved │
└──────────┘              └─────────┘          └──────────┘          └──────────┘
                               │                                           │
                               │ beforeSwap ✓                              │
                               │ afterSwap ✓                               │
                               │                                           │
                               ▼                                           ▼
                          Time Decay Fees                            Redemption
```

## Key Algorithms

### Time Decay Fee Calculation

```
Input: timeToEvent (seconds)
Output: feeMultiplier (100 = 1x, 200 = 2x, etc)

if timeToEvent < 1 hour:
    return 300  // 3x fee
else if timeToEvent < 1 day:
    return 200  // 2x fee
else if timeToEvent < 7 days:
    return 150  // 1.5x fee
else:
    return 100  // 1x fee (base)

Rationale:
- Compensates LPs for increased volatility
- Discourages last-minute manipulation
- Models option theta decay
```

### Probability Calculation (Simplified)

```
Binary Market (YES/NO):

Reserve_YES = 60 tokens
Reserve_NO = 40 tokens
Total = 100 tokens

P(YES) = Reserve_YES / Total = 60 / 100 = 60%
P(NO) = Reserve_NO / Total = 40 / 100 = 40%

Price_YES ≈ P(YES) = $0.60
Price_NO ≈ P(NO) = $0.40

Invariant: Price_YES + Price_NO ≈ $1.00
```

### Complete Set Arbitrage

```
Market State:
YES trading at $0.55
NO trading at $0.48
Sum = $1.03 (should be $1.00)

Arbitrage:
1. Mint set for $1.00 → Get 1 YES + 1 NO
2. Sell YES for $0.55
3. Sell NO for $0.48
4. Profit: $0.03 per set

Result:
- Selling pressure brings prices down
- Eventually: YES $0.52 + NO $0.48 = $1.00
- Market efficiency restored
```

## Security Model

### Trust Boundaries

```
Trusted:
├── PoolManager (Uniswap V4 core)
├── Oracle (Chainlink - external trust)
└── Hook deployer (initial setup)

Untrusted:
├── Users (traders, LPs)
├── Market creators
└── Resolvers (anyone can call)

Trust Minimization:
├── On-chain settlement (no custodian)
├── Oracle redundancy (multiple sources)
├── Dispute period (72h for challenges)
└── Open resolution (permissionless)
```

### Attack Vectors & Mitigations

| Attack                   | Mitigation                             |
| ------------------------ | -------------------------------------- |
| Oracle manipulation      | Multiple oracles, stale data checks    |
| Front-running resolution | Public mempool, no MEV advantage       |
| Reentrancy               | SafeERC20, checks-effects-interactions |
| Flash loan manipulation  | Time-weighted mechanics, fees          |
| Sybil attacks on voting  | Not applicable (oracle-based)          |
| Last-block manipulation  | 3x fees in final hour                  |

## Gas Optimization Strategies

### Storage Packing

```solidity
// ❌ Inefficient (3 slots)
struct Market {
    uint256 eventTimestamp;  // slot 0
    uint8 numOutcomes;       // slot 1
    bool isResolved;         // slot 2
}

// ✅ Efficient (1 slot)
struct Market {
    uint8 numOutcomes;       // [0-7]
    bool isResolved;         // [8]
    uint40 eventTimestamp;   // [9-48] (enough until year 36812)
    // ... 176 bits remaining
}
```

### Batch Operations

```solidity
// Consider for future:
function mintSetBatch(bytes32[] calldata marketIds, uint256[] calldata amounts)
function burnSetBatch(bytes32[] calldata marketIds, uint256[] calldata amounts)
```

### Calldata vs Memory

```solidity
// ✅ Use calldata for read-only
function beforeSwap(
    address sender,
    PoolKey calldata key,  // calldata (cheaper)
    ...
)

// Memory only when modifying
function _processData(PoolKey memory key) internal {
    key.fee = newFee;  // Need memory to modify
}
```

## Extension Points

### Future Enhancements (Month 2+)

1. **Multi-Outcome Markets**

   ```solidity
   struct MultiOutcomeMarket {
       OutcomeToken[] outcomes;  // 3-10 tokens
       // Use LMSR pricing instead of xy=k
   }
   ```

2. **Combo Markets (Parlays)**

   ```solidity
   struct ComboMarket {
       PoolId[] dependencies;    // Multiple markets
       uint8[] requiredOutcomes; // AND conditions
   }
   ```

3. **Liquidity Mining**

   ```solidity
   function afterAddLiquidity(...) {
       uint256 reward = calculateLPReward(params);
       governanceToken.mint(sender, reward);
   }
   ```

4. **Dynamic Oracle Selection**
   ```solidity
   struct OracleConfig {
       address[] oracles;
       uint8 requiredConsensus;  // 2 of 3
   }
   ```

## Performance Characteristics

### Complexity Analysis

| Operation     | Time | Space |
| ------------- | ---- | ----- |
| Create market | O(1) | O(1)  |
| Mint/burn set | O(n) | O(1)  |
| Swap          | O(1) | O(1)  |
| Resolve       | O(1) | O(1)  |
| Redeem        | O(1) | O(1)  |

Where n = number of outcomes (max 10)

### Scalability

- **Markets per hook**: Unlimited (separate pool IDs)
- **Concurrent trades**: Limited by Ethereum throughput
- **Storage growth**: O(markets) - linear, manageable
- **L2 deployment**: Fully compatible (Base, Arbitrum, etc.)

## Deployment Checklist

- [ ] Audit contracts (3+ firms)
- [ ] Deploy to testnet
- [ ] Test with real oracles
- [ ] Frontend integration
- [ ] Bug bounty program
- [ ] Mainnet deployment
- [ ] Monitor and respond

## Monitoring & Observability

### Key Metrics

```solidity
// Emit events for tracking
event MarketCreated(...);
event ProbabilityUpdated(...);
event MarketResolved(...);
event TokensRedeemed(...);

// Off-chain indexing
// - Total markets created
// - Total volume traded
// - Average market size
// - Resolution accuracy
// - Average time to resolution
```

### Alerts

- Market unresolved 24h after event
- Oracle data stale (> 1h)
- Unusual trading volume (potential manipulation)
- Gas price spikes affecting operations

---

**Document Version**: 1.0 (Month 1 Complete)
**Last Updated**: December 2024
**Next Review**: Month 2 Kickoff
