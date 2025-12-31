// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {PredictionMarketHook} from "../../src/PredictionMarketHook.sol";
import {TokenManager} from "../../src/TokenManager.sol";
import {MockChainlinkOracle} from "../../src/mocks/MockChainlinkOracle.sol";

/**
 * @title DisputeMechanismTest
 * @notice Comprehensive tests for the dispute mechanism
 */
contract DisputeMechanismTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    PredictionMarketHook hook;
    TokenManager tokenManager;
    MockChainlinkOracle oracle;
    MockERC20 collateralToken;

    PoolKey poolKey;
    PoolId poolId;

    bytes32 constant EVENT_ID = keccak256("DISPUTE-TEST");
    uint8 constant NUM_OUTCOMES = 2;
    uint256 eventTimestamp;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address protocolOwner;

    function setUp() public {
        // Deploy v4 core contracts
        deployFreshManagerAndRouters();

        protocolOwner = address(this);

        // Deploy collateral token
        collateralToken = new MockERC20("USDC", "USDC", 6);

        // Deploy oracle
        oracle = new MockChainlinkOracle();

        // Set event timestamp to 30 days from now
        eventTimestamp = block.timestamp + 30 days;

        // Deploy hook at correct address
        address hookAddress =
            address(uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG));

        // Deploy token manager first
        tokenManager = new TokenManager(hookAddress);

        // Deploy hook
        deployCodeTo("PredictionMarketHook.sol", abi.encode(manager), hookAddress);
        hook = PredictionMarketHook(hookAddress);

        // Initialize hook
        hook.initialize(address(tokenManager), protocolOwner);

        // Create pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(collateralToken)),
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: hook
        });

        poolId = poolKey.toId();

        // Initialize market
        hook.initializeMarket(poolKey, EVENT_ID, eventTimestamp, address(oracle), NUM_OUTCOMES);

        // Initialize the pool
        manager.initialize(poolKey, SQRT_PRICE_1_1);

        // Mint tokens to test users
        collateralToken.mint(alice, 1000e6);
        collateralToken.mint(bob, 1000e6);
    }

    /*//////////////////////////////////////////////////////////////
                        DISPUTE SUBMISSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SubmitDispute_Success() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1); // Oracle says outcome 0 won
        hook.resolveMarket(poolId);

        // Alice disputes, claiming outcome 1 actually won
        uint256 stakeAmount = 100e6; // Minimum stake
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        // Check dispute was recorded
        (
            address disputer,
            uint8 challengedOutcome,
            uint8 proposedOutcome,
            uint256 stake,
            ,
            bool resolved,
            bool accepted
        ) = hook.disputes(poolId, 0);

        assertEq(disputer, alice);
        assertEq(challengedOutcome, 0);
        assertEq(proposedOutcome, 1);
        assertEq(stake, stakeAmount);
        assertFalse(resolved);
        assertFalse(accepted);
    }

    function test_RevertIf_DisputeBeforeResolution() public {
        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        vm.expectRevert(PredictionMarketHook.MarketNotResolved.selector);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();
    }

    function test_RevertIf_DisputeAfterPeriodExpires() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Wait past dispute period
        vm.warp(eventTimestamp + 1 + 72 hours + 1);

        // Try to dispute
        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        vm.expectRevert(PredictionMarketHook.DisputePeriodExpired.selector);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();
    }

    function test_RevertIf_InsufficientStake() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Try to dispute with insufficient stake
        uint256 stakeAmount = 50e6; // Below minimum of 100e6
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        vm.expectRevert(PredictionMarketHook.InsufficientDisputeStake.selector);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();
    }

    function test_RevertIf_DisputeToSameOutcome() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Try to dispute claiming the same outcome won
        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        vm.expectRevert(PredictionMarketHook.InvalidDisputeOutcome.selector);
        hook.submitDispute(poolId, 0, stakeAmount); // Same as oracle result
        vm.stopPrank();
    }

    function test_MultipleDisputes() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Alice disputes
        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        // Bob also disputes
        vm.startPrank(bob);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        // Check both disputes exist
        (address disputer1,,,,,,) = hook.disputes(poolId, 0);
        (address disputer2,,,,,,) = hook.disputes(poolId, 1);

        assertEq(disputer1, alice);
        assertEq(disputer2, bob);
    }

    /*//////////////////////////////////////////////////////////////
                        DISPUTE RESOLUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ResolveDispute_Accepted() public {
        // Resolve market with outcome 0
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // First, create protocol fees by rejecting Bob's dispute
        uint256 bobStake = 100e6;
        vm.startPrank(bob);
        collateralToken.approve(address(hook), bobStake);
        hook.submitDispute(poolId, 1, bobStake);
        vm.stopPrank();

        // Reject Bob's dispute to build protocol fees
        hook.resolveDispute(poolId, 0, false);

        // Alice disputes claiming outcome 1
        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        uint256 aliceBalanceBefore = collateralToken.balanceOf(alice);

        // Owner accepts Alice's dispute (using fees from Bob's rejected dispute)
        hook.resolveDispute(poolId, 1, true);

        // Check market outcome was changed
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        assertEq(market.winningOutcome, 1);

        // Check Alice received stake + 20% reward
        uint256 reward = (stakeAmount * 20) / 100;
        uint256 expectedPayout = stakeAmount + reward;
        assertEq(collateralToken.balanceOf(alice), aliceBalanceBefore + expectedPayout);
    }

    function test_ResolveDispute_Rejected() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Alice disputes
        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        uint256 aliceBalanceBefore = collateralToken.balanceOf(alice);
        uint256 protocolFeesBefore = hook.protocolFees(address(collateralToken));

        // Owner rejects the dispute
        hook.resolveDispute(poolId, 0, false);

        // Check market outcome unchanged
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        assertEq(market.winningOutcome, 0);

        // Check Alice didn't get refund
        assertEq(collateralToken.balanceOf(alice), aliceBalanceBefore);

        // Check stake went to protocol fees
        assertEq(hook.protocolFees(address(collateralToken)), protocolFeesBefore + stakeAmount);
    }

    function test_RevertIf_ResolveDispute_NotOwner() public {
        // Resolve and submit dispute
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);

        // Alice tries to resolve her own dispute
        vm.expectRevert();
        hook.resolveDispute(poolId, 0, true);
        vm.stopPrank();
    }

    function test_RevertIf_ResolveAlreadyResolved() public {
        // Resolve and submit dispute
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // First, create protocol fees by rejecting Bob's dispute
        uint256 bobStake = 100e6;
        vm.startPrank(bob);
        collateralToken.approve(address(hook), bobStake);
        hook.submitDispute(poolId, 1, bobStake);
        vm.stopPrank();
        hook.resolveDispute(poolId, 0, false);

        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        // Resolve dispute
        hook.resolveDispute(poolId, 1, true);

        // Try to resolve again
        vm.expectRevert(PredictionMarketHook.DisputeAlreadyResolved.selector);
        hook.resolveDispute(poolId, 1, true);
    }

    /*//////////////////////////////////////////////////////////////
                        MARKET FINALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FinalizeMarket_NoDisputes() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Wait for dispute period
        vm.warp(eventTimestamp + 1 + 72 hours);

        // Finalize market
        hook.finalizeMarket(poolId);

        // Check market is finalized
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        assertTrue(market.finalized);
    }

    function test_FinalizeMarket_WithResolvedDisputes() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Submit dispute
        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        // Resolve dispute
        hook.resolveDispute(poolId, 0, false);

        // Wait for dispute period
        vm.warp(eventTimestamp + 1 + 72 hours);

        // Finalize market
        hook.finalizeMarket(poolId);

        // Check market is finalized
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        assertTrue(market.finalized);
    }

    function test_RevertIf_FinalizeBeforeDisputePeriod() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Try to finalize immediately
        vm.expectRevert(PredictionMarketHook.DisputePeriodActive.selector);
        hook.finalizeMarket(poolId);
    }

    function test_RevertIf_FinalizeWithUnresolvedDisputes() public {
        // Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // Submit dispute but don't resolve it
        uint256 stakeAmount = 100e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        // Wait for dispute period
        vm.warp(eventTimestamp + 1 + 72 hours);

        // Try to finalize with unresolved dispute
        vm.expectRevert("Unresolved disputes exist");
        hook.finalizeMarket(poolId);
    }

    function test_RevertIf_FinalizeAlreadyFinalized() public {
        // Resolve and finalize
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);
        vm.warp(eventTimestamp + 1 + 72 hours);
        hook.finalizeMarket(poolId);

        // Try to finalize again
        vm.expectRevert(PredictionMarketHook.MarketAlreadyResolved.selector);
        hook.finalizeMarket(poolId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FullDisputeFlow_Accepted() public {
        // 1. Resolve market with outcome 0
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // 1.5. Build protocol fees by rejecting Bob's dispute
        uint256 bobStake = 100e6;
        vm.startPrank(bob);
        collateralToken.approve(address(hook), bobStake);
        hook.submitDispute(poolId, 1, bobStake);
        vm.stopPrank();
        hook.resolveDispute(poolId, 0, false);

        // 2. Alice submits dispute
        uint256 stakeAmount = 200e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        // 3. Owner accepts dispute
        hook.resolveDispute(poolId, 1, true);

        // 4. Wait and finalize
        vm.warp(eventTimestamp + 1 + 72 hours);
        hook.finalizeMarket(poolId);

        // 5. Verify final outcome is the disputed one
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        assertEq(market.winningOutcome, 1);
        assertTrue(market.finalized);
    }

    function test_FullDisputeFlow_Rejected() public {
        // 1. Resolve market
        vm.warp(eventTimestamp + 1);
        oracle.setLatestAnswerWithTimestamp(0, eventTimestamp + 1);
        hook.resolveMarket(poolId);

        // 2. Alice submits invalid dispute
        uint256 stakeAmount = 200e6;
        vm.startPrank(alice);
        collateralToken.approve(address(hook), stakeAmount);
        hook.submitDispute(poolId, 1, stakeAmount);
        vm.stopPrank();

        // 3. Owner rejects dispute
        hook.resolveDispute(poolId, 0, false);

        // 4. Wait and finalize
        vm.warp(eventTimestamp + 1 + 72 hours);
        hook.finalizeMarket(poolId);

        // 5. Verify original outcome stands
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        assertEq(market.winningOutcome, 0);
        assertTrue(market.finalized);
    }
}
