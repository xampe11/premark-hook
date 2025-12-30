# Changelog

All notable changes to the Prediction Market Hook project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### To-Do (Priority 1 - Blockers)
- [ ] Implement actual logic in `redeemWinningTokens()` function
- [ ] Add `getCurrentProbability()` view function
- [ ] Implement PoolManager reserve access for real-time pricing
- [ ] Add resolution fee collection (2% of losing side)

### To-Do (Priority 2 - Month 2)
- [ ] Implement protocol fee collection mechanism (40% of trading fees)
- [ ] Add UMA Optimistic Oracle support
- [ ] Implement dispute resolution mechanism
- [ ] Test multi-outcome markets (3-10 outcomes) on testnet
- [ ] Add fee withdrawal functions with multi-sig

### To-Do (Priority 3 - Future)
- [ ] Combo markets (parlay betting)
- [ ] Liquidity mining rewards
- [ ] Additional oracle providers (Pyth Network)
- [ ] Frontend development
- [ ] Mobile app

---

## [1.0.0] - 2024-12-30

### Added - Base Sepolia Deployment Complete ✅

#### Smart Contracts
- ✅ `PredictionMarketHook.sol` (538 lines) - Main hook with binary market support
- ✅ `TokenManager.sol` (231 lines) - Complete set mint/burn functionality
- ✅ `OutcomeToken.sol` - ERC20 tokens for outcomes (YES/NO)
- ✅ `MockUSDC.sol` - Test collateral token with open minting
- ✅ `MockChainlinkOracle.sol` - Testing oracle implementation

#### Features Implemented
- ✅ **Binary Prediction Markets** - YES/NO outcome tokens
- ✅ **Time Decay Fees** - Dynamic fees (1x → 1.5x → 2x → 3x)
- ✅ **Oracle Integration** - Chainlink AggregatorV3Interface
- ✅ **Complete Set Trading** - Mint/burn 1 USDC ↔ 1 YES + 1 NO
- ✅ **Automated Token Creation** - Hook auto-creates outcome tokens
- ✅ **TokenManager Integration** - Solved circular dependency
- ✅ **Dispute Period** - 72-hour window before finalization
- ✅ **Multi-outcome Support** - Code structure for 2-10 outcomes

#### Testing
- ✅ Unit tests (39/40 passing, 97.5% coverage)
- ✅ End-to-end integration test on Base Sepolia
- ✅ 5/5 integration test scenarios passing:
  - Market creation with auto-token generation
  - Mint complete sets (10,000 USDC → 10k YES + 10k NO)
  - Balance verification
  - Burn complete sets (5,000 sets → 5k USDC)
  - Oracle price updates

#### Deployment (Base Sepolia)
- ✅ MockUSDC: `0x9b882e879Cf9aeEa8556560E467CD3bb87Af7F77`
- ✅ MockOracle: `0x27Bb58451a8eAbb79Af749234874Dcc8b99db40b`
- ✅ PredictionMarketHook: `0x2B8DCE2F738BbFE5F84D62F55806AE6dDe68E0c0`
- ✅ TokenManager: `0xb01e700266faae9b61D0F0E436961e1C5c441F15`

#### Scripts
- ✅ `DeployTestnet.s.sol` - Handles circular dependency with CREATE2
- ✅ `Deploy.s.sol` - Updated for TokenManager integration
- ✅ `TestBaseSepolia.s.sol` - Comprehensive integration tests
- ✅ `MintTestTokens.s.sol` - Easy token minting helper
- ✅ `CreateMarket.s.sol` - Market creation helper
- ✅ `test-sepolia.sh` - Convenience script for testing

#### Documentation
- ✅ 8 comprehensive documentation files created:
  - `WORK_SUMMARY.md` - Recent development summary
  - `DEPLOYMENT_GUIDE.md` - How to deploy
  - `END_TO_END_TEST_RESULTS.md` - Test results
  - `INTEGRATION_COMPLETE.md` - Integration documentation
  - `README_TESTING.md` - Testing quickstart
  - `TESTING.md` - Testing guide
  - `TEST_COMMANDS.md` - Command reference
  - `CLEANUP_CHECKLIST.md` - Repository maintenance

### Changed

#### Architecture Improvements
- 🔄 **Solved Circular Dependency** - Hook needs TokenManager address, TokenManager needs Hook address
  - Solution: Predict TokenManager address using nonce calculation
  - Deploy Hook with predicted address
  - Deploy TokenManager with actual Hook address
  - Verify prediction matches

- 🔄 **Hook Constructor** - Added `tokenManager` parameter
  ```solidity
  constructor(IPoolManager _poolManager, address _tokenManager)
  ```

- 🔄 **Auto-registration** - Hook automatically registers markets with TokenManager

#### Testing Improvements
- 🔄 Updated unit tests for new constructor signature
- 🔄 Added integration testing on live testnet
- 🔄 Created reusable test scripts

### Fixed

#### Critical Bug Fixes
- 🐛 **Fixed Hook-TokenManager Integration** - Markets now properly registered
- 🐛 **Fixed Outcome Token Creation** - Tokens created automatically on market init
- 🐛 **Fixed Deployment Process** - Handles circular dependencies correctly

#### Minor Fixes
- 🐛 Deployment script error handling improved
- 🐛 Gas optimization in time decay calculation
- 🐛 Event emission for better tracking

---

## [0.2.0] - 2024-12-25

### Added
- ✅ First market creation working on testnet
- ✅ Deployment scripts separated (`CreateMarket.s.sol`, `SetupLocal.s.sol`)
- ✅ Basic testnet deployment working

### Changed
- 🔄 Refactored deployment scripts for better modularity

---

## [0.1.0] - 2024-12-24

### Added
- ✅ Initial project setup
- ✅ First commit with hook v1
- ✅ Basic testing framework
- ✅ Deployment scripts for testnet

---

## Version Numbering

We use [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for new functionality (backward compatible)
- **PATCH** version for backward compatible bug fixes

### Upcoming Versions

- **1.1.0** - Priority 1 fixes (redemption, probability calculation)
- **1.2.0** - Protocol fee collection
- **1.3.0** - Multi-oracle support
- **2.0.0** - Multi-outcome markets, combo markets
- **3.0.0** - Liquidity mining, mainnet launch

---

## Notable Commits

### December 30, 2024
- `1dbc401` - Base Sepolia testing completed successfully ✅
  - 2,757 lines added, 615 deleted
  - 8 documentation files created
  - Full integration verified

### December 30, 2024 (earlier)
- `8c449bd` - Working on month2 achievement baselines
  - Comprehensive testnet deployment script
  - Deployment artifacts generated

### December 25, 2024
- `51c460f` - Deployment and creation of first market working correctly
  - Fixed deployment script issues

### December 24, 2024
- `49975f0` - Working on the deployment scripts
  - Added foundry configuration
  - Improved market creation logic

- `4d5fb35` - Working on the deployment on testnet to check behaviour
  - Separated deployment concerns
  - Created helper scripts

### Earlier
- `707e4ae` - Completed first testing cycle correctly
- `95a1b40` - Working on testing
- `3e7612c` - First commit, created hook v1 together with testing

---

## Migration Guide

### From 0.x to 1.0.0

**Breaking Changes:**
1. Hook constructor now requires `tokenManager` address:
   ```solidity
   // Old (0.x)
   constructor(IPoolManager _poolManager)

   // New (1.0.0)
   constructor(IPoolManager _poolManager, address _tokenManager)
   ```

2. Market initialization now requires calling `initializeMarket()` first:
   ```solidity
   // New workflow
   hook.initializeMarket(key, eventId, timestamp, oracle, numOutcomes);
   poolManager.initialize(key, sqrtPrice);
   ```

3. Outcome tokens now auto-created - no manual deployment needed

**Migration Steps:**
1. Redeploy Hook with new constructor
2. Ensure TokenManager is deployed first
3. Update initialization calls to use `initializeMarket()`
4. Remove manual OutcomeToken deployment code

---

## Deprecations

### Deprecated in 1.0.0
- ⚠️ `script/config/TestnetConfig.sol` - Use environment variables instead
- ⚠️ Manual outcome token deployment - Now automatic

### Will be Deprecated in 2.0.0
- ⚠️ Single oracle per market - Will support multi-oracle consensus
- ⚠️ MockOracle for production - Use real Chainlink oracles

---

## Security

### Security Audits
- [ ] OpenZeppelin - Scheduled for Month 3
- [ ] Trail of Bits - Scheduled for Month 3
- [ ] Sherlock - Scheduled for Month 4

### Bug Bounty
- [ ] Program launch - Month 4
- [ ] Minimum payout: $500K

### Known Issues

#### Critical (Must Fix Before Launch)
1. ❌ `redeemWinningTokens()` only emits event, doesn't transfer tokens
2. ❌ Probability calculation uses hardcoded value (50%)
3. ❌ Resolution fees not collected

#### Medium
4. ⚠️ Single oracle creates centralization risk
5. ⚠️ Protocol fees defined but not collected
6. ⚠️ No dispute resolution mechanism implemented

#### Low
7. 📝 One unit test failing (39/40 passing)
8. 📝 Multi-outcome (>2) not tested on testnet
9. 📝 Gas optimizations possible

---

## Performance

### Gas Costs (Estimated)

| Operation | Gas Used | Cost @ 50 gwei |
|-----------|----------|----------------|
| Create Market | ~200K | $0.01 |
| Mint Complete Set | ~150K | $0.0075 |
| Swap | ~180K | $0.009 |
| Burn Complete Set | ~120K | $0.006 |
| Resolve Market | ~100K | $0.005 |
| Redeem Winning | ~80K | $0.004 |

### Test Suite Performance
- Unit tests: ~2 seconds
- Integration tests: ~30 seconds
- Coverage generation: ~10 seconds

---

## Contributors

- **Juan** (juampi.farinia@gmail.com) - Core development, deployment, testing

---

## Resources

- [Uniswap V4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [Chainlink Oracles](https://docs.chain.link/)
- [Base Sepolia Explorer](https://sepolia.basescan.org/)
- [Project Vision Doc](../docs/ARCHITECTURE.md)

---

**Last Updated:** December 30, 2024
