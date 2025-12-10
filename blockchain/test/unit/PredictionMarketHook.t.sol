// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {PredictionMarketHook} from "../../src/PredictionMarketHook.sol";
import {OutcomeToken} from "../../src/OutcomeToken.sol";
import {TokenManager} from "../../src/TokenManager.sol";
import {MockChainlinkOracle} from "../../src/mocks/MockChainlinkOracle.sol";

contract PredictionMarketHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    PredictionMarketHook hook;
    TokenManager tokenManager;
    MockChainlinkOracle oracle;
    MockERC20 collateralToken;

    PoolKey poolKey;
    PoolId poolId;

    bytes32 constant EVENT_ID = keccak256("BTC-100K-EOY");
    uint256 eventTimestamp;
    uint8 constant NUM_OUTCOMES = 2;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // Deploy v4 core contracts
        deployFreshManagerAndRouters();

        // Deploy collateral token
        collateralToken = new MockERC20("USDC", "USDC", 6);

        // Deploy oracle
        oracle = new MockChainlinkOracle();

        // Set event timestamp to 30 days from now
        eventTimestamp = block.timestamp + 30 days;

        // Deploy hook at correct address
        address hookAddress =
            address(uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG));

        deployCodeTo("PredictionMarketHook.sol", abi.encode(manager), hookAddress);
        hook = PredictionMarketHook(hookAddress);

        // Deploy token manager
        tokenManager = new TokenManager(address(hook));

        // Create pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // Native token or another ERC20
            currency1: Currency.wrap(address(collateralToken)),
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: hook
        });

        poolId = poolKey.toId();

        // Initialize market parameters
        hook.initializeMarket(poolKey, EVENT_ID, eventTimestamp, address(oracle), NUM_OUTCOMES);

        // Initialize the pool
        manager.initialize(poolKey, SQRT_PRICE_1_1);

        // Mint tokens to test users
        collateralToken.mint(alice, 1000e6);
        collateralToken.mint(bob, 1000e6);
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MarketCreation() public view {
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);

        assertEq(market.eventId, EVENT_ID);
        assertEq(market.eventTimestamp, eventTimestamp);
        assertEq(market.oracleAddress, address(oracle));
        assertEq(market.numOutcomes, NUM_OUTCOMES);
        assertFalse(market.isResolved);
    }

    function test_RevertIf_EventInPast() public {
        uint256 pastTimestamp = block.timestamp - 1 days;

        PoolKey memory invalidKey = poolKey;
        invalidKey.currency1 = Currency.wrap(address(1)); // Different pool

        vm.expectRevert(PredictionMarketHook.EventInPast.selector);
        hook.initializeMarket(invalidKey, keccak256("PAST-EVENT"), pastTimestamp, address(oracle), NUM_OUTCOMES);
    }

    function test_RevertIf_InvalidOracle() public {
        PoolKey memory invalidKey = poolKey;
        invalidKey.currency1 = Currency.wrap(address(2));

        vm.expectRevert(PredictionMarketHook.InvalidOracle.selector);
        hook.initializeMarket(invalidKey, EVENT_ID, eventTimestamp, address(0), NUM_OUTCOMES);
    }

    function test_RevertIf_InvalidOutcomeCount() public {
        PoolKey memory invalidKey = poolKey;
        invalidKey.currency1 = Currency.wrap(address(3));

        vm.expectRevert(PredictionMarketHook.InvalidOutcomeCount.selector);
        hook.initializeMarket(invalidKey, EVENT_ID, eventTimestamp, address(oracle), uint8(1));
    }

    /*//////////////////////////////////////////////////////////////
                        TIME DECAY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TimeDecayFee_BaseCase() public view {
        uint256 multiplier = hook.getCurrentFeeMultiplier(poolId);
        assertEq(multiplier, 100); // 1x (30 days away)
    }

    function test_TimeDecayFee_LastWeek() public {
        // Warp to 5 days before event
        vm.warp(eventTimestamp - 5 days);

        uint256 multiplier = hook.getCurrentFeeMultiplier(poolId);
        assertEq(multiplier, 150); // 1.5x
    }

    function test_TimeDecayFee_LastDay() public {
        // Warp to 12 hours before event
        vm.warp(eventTimestamp - 12 hours);

        uint256 multiplier = hook.getCurrentFeeMultiplier(poolId);
        assertEq(multiplier, 200); // 2x
    }

    function test_TimeDecayFee_LastHour() public {
        // Warp to 30 minutes before event
        vm.warp(eventTimestamp - 30 minutes);

        uint256 multiplier = hook.getCurrentFeeMultiplier(poolId);
        assertEq(multiplier, 300); // 3x
    }

    /*//////////////////////////////////////////////////////////////
                        TRADING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Trading_BeforeEvent() public {
        assertTrue(hook.isTradeable(poolId));

        uint256 timeRemaining = hook.timeUntilEvent(poolId);
        assertGt(timeRemaining, 0);
    }

    function test_RevertIf_TradingAfterEvent() public {
        // Warp past event time
        vm.warp(eventTimestamp + 1);

        assertFalse(hook.isTradeable(poolId));

        // Attempt to swap should revert
        // Note: Full swap testing requires proper pool setup with liquidity
    }

    /*//////////////////////////////////////////////////////////////
                        RESOLUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ResolveMarket_Success() public {
        // Set oracle result: YES wins (outcome 1)
        oracle.setLatestAnswer(1);

        // Warp past event time
        vm.warp(eventTimestamp + 1);

        // Resolve market
        hook.resolveMarket(poolId);

        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        assertTrue(market.isResolved);
        assertEq(market.winningOutcome, 1);
        assertEq(market.resolutionTime, block.timestamp);
    }

    function test_RevertIf_ResolveBeforeEvent() public {
        vm.expectRevert(PredictionMarketHook.EventNotOccurred.selector);
        hook.resolveMarket(poolId);
    }

    function test_RevertIf_ResolveTwice() public {
        oracle.setLatestAnswer(1);
        vm.warp(eventTimestamp + 1);

        hook.resolveMarket(poolId);

        vm.expectRevert(PredictionMarketHook.MarketAlreadyResolved.selector);
        hook.resolveMarket(poolId);
    }

    /*//////////////////////////////////////////////////////////////
                        SETTLEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RedeemWinningTokens() public {
        // Resolve market
        oracle.setLatestAnswer(1);
        vm.warp(eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Wait for dispute period
        vm.warp(eventTimestamp + 1 + 72 hours);

        // Redeem tokens (Note: requires full token manager integration)
        uint256 amount = 100e6;
        vm.prank(alice);
        hook.redeemWinningTokens(poolId, amount);
    }

    function test_RevertIf_RedeemBeforeResolution() public {
        uint256 amount = 100e6;

        vm.prank(alice);
        vm.expectRevert(PredictionMarketHook.MarketNotResolved.selector);
        hook.redeemWinningTokens(poolId, amount);
    }

    function test_RevertIf_RedeemDuringDispute() public {
        oracle.setLatestAnswer(1);
        vm.warp(eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Try to redeem during dispute period
        uint256 amount = 100e6;
        vm.prank(alice);
        vm.expectRevert(PredictionMarketHook.DisputePeriodActive.selector);
        hook.redeemWinningTokens(poolId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetMarket() public view {
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        assertEq(market.eventTimestamp, eventTimestamp);
    }

    function test_IsTradeable() public {
        assertTrue(hook.isTradeable(poolId));

        vm.warp(eventTimestamp + 1);
        assertFalse(hook.isTradeable(poolId));
    }

    function test_TimeUntilEvent() public {
        uint256 expected = eventTimestamp - block.timestamp;
        assertEq(hook.timeUntilEvent(poolId), expected);

        vm.warp(eventTimestamp + 1);
        assertEq(hook.timeUntilEvent(poolId), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FullMarketLifecycle() public {
        // 1. Market is created (done in setUp)
        assertTrue(hook.isTradeable(poolId));

        // 2. Trading occurs
        // (Would add liquidity and execute swaps here with full setup)

        // 3. Event occurs
        vm.warp(eventTimestamp + 1);
        assertFalse(hook.isTradeable(poolId));

        // 4. Oracle reports result
        oracle.setLatestAnswer(1); // YES wins

        // 5. Market resolves
        hook.resolveMarket(poolId);
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        assertTrue(market.isResolved);
        assertEq(market.winningOutcome, 1);

        // 6. Dispute period passes
        vm.warp(eventTimestamp + 1 + 72 hours);

        // 7. Winners redeem
        // (Would test redemption with proper token setup)
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_TimeDecayFee(uint256 timeToEvent) public {
        // Bound time to reasonable range
        timeToEvent = bound(timeToEvent, 0, 365 days);

        // Calculate expected multiplier
        uint256 expected;
        if (timeToEvent < 1 hours) expected = 300;
        else if (timeToEvent < 1 days) expected = 200;
        else if (timeToEvent < 7 days) expected = 150;
        else expected = 100;

        // Create market with this timestamp
        uint256 futureTime = block.timestamp + timeToEvent;
        bytes32 fuzzEventId = keccak256(abi.encodePacked("FUZZ-", timeToEvent));

        PoolKey memory fuzzKey = poolKey;
        fuzzKey.currency1 = Currency.wrap(address(uint160(timeToEvent + 1000)));

        // Initialize market parameters
        hook.initializeMarket(fuzzKey, fuzzEventId, futureTime, address(oracle), NUM_OUTCOMES);

        // Initialize pool
        manager.initialize(fuzzKey, SQRT_PRICE_1_1);
        PoolId fuzzPoolId = fuzzKey.toId();

        uint256 actual = hook.getCurrentFeeMultiplier(fuzzPoolId);
        assertEq(actual, expected);
    }
}
