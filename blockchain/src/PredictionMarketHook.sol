// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PredictionMarketHook
 * @notice Uniswap V4 Hook that transforms a liquidity pool into a prediction market
 * @dev Implements binary outcome markets with automated pricing, time decay, and oracle settlement
 */
contract PredictionMarketHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error EventInPast();
    error InvalidOracle();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error EventNotOccurred();
    error InvalidOutcomeCount();
    error TradingFrozen();
    error InvalidMarketParams();
    error UnauthorizedResolver();
    error DisputePeriodActive();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MarketCreated(
        PoolId indexed poolId, bytes32 indexed eventId, uint256 eventTimestamp, address oracleAddress, uint8 numOutcomes
    );

    event ProbabilityUpdated(PoolId indexed poolId, uint256 probability);

    event MarketResolved(PoolId indexed poolId, uint8 winningOutcome, uint256 timestamp);

    event TokensRedeemed(address indexed user, PoolId indexed poolId, uint256 amount);

    event DisputeInitiated(PoolId indexed poolId, address indexed disputer, uint8 challengedOutcome);

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Market {
        bytes32 eventId; // Unique identifier for the event
        uint256 eventTimestamp; // When the event occurs
        address oracleAddress; // Chainlink oracle address
        uint8 numOutcomes; // Number of possible outcomes (2 for binary)
        bool isResolved; // Whether oracle has resolved the market
        uint8 winningOutcome; // Which outcome won (0-indexed)
        uint256 resolutionTime; // When market was resolved
        uint256 totalVolume; // Cumulative trading volume
        address creator; // Market creator address
    }

    struct OutcomeToken {
        address tokenAddress; // ERC20 token for this outcome
        uint256 totalSupply; // Current supply
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps pool ID to market data
    mapping(PoolId => Market) public markets;

    /// @notice Maps pool ID to outcome tokens
    mapping(PoolId => OutcomeToken[]) public outcomeTokens;

    /// @notice Dispute period duration (72 hours)
    uint256 public constant DISPUTE_PERIOD = 72 hours;

    /// @notice Protocol fee (40% of trading fees)
    uint256 public constant PROTOCOL_FEE_PERCENT = 40;

    /// @notice Resolution fee (2% of losing side)
    uint256 public constant RESOLUTION_FEE_PERCENT = 2;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    /*//////////////////////////////////////////////////////////////
                            HOOK PERMISSIONS
    //////////////////////////////////////////////////////////////*/

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Hook called before pool initialization - sets up prediction market
     * @param sender The sender of the initialize call
     * @param key The pool key
     * @param sqrtPriceX96 Initial sqrt price
     * @dev Market parameters must be set via initializeMarket() before pool initialization
     */
    function _beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96)
        internal
        override
        returns (bytes4)
    {
        PoolId poolId = key.toId();
        Market storage market = markets[poolId];

        // Validation - market must be initialized via initializeMarket first
        if (market.eventTimestamp == 0) revert InvalidMarketParams();
        if (market.eventTimestamp <= block.timestamp) revert EventInPast();
        if (market.oracleAddress == address(0)) revert InvalidOracle();

        emit MarketCreated(poolId, market.eventId, market.eventTimestamp, market.oracleAddress, market.numOutcomes);

        return BaseHook.beforeInitialize.selector;
    }

    /**
     * @notice Initialize market parameters before pool creation
     * @param key The pool key
     * @param eventId Unique identifier for the event
     * @param eventTimestamp When the event occurs
     * @param oracleAddress Chainlink oracle address
     * @param numOutcomes Number of possible outcomes
     */
    function initializeMarket(
        PoolKey calldata key,
        bytes32 eventId,
        uint256 eventTimestamp,
        address oracleAddress,
        uint8 numOutcomes
    ) external {
        // Validation
        if (eventTimestamp <= block.timestamp) revert EventInPast();
        if (oracleAddress == address(0)) revert InvalidOracle();
        if (numOutcomes < 2 || numOutcomes > 10) revert InvalidOutcomeCount();

        PoolId poolId = key.toId();

        // Store market data
        markets[poolId] = Market({
            eventId: eventId,
            eventTimestamp: eventTimestamp,
            oracleAddress: oracleAddress,
            numOutcomes: numOutcomes,
            isResolved: false,
            winningOutcome: 0,
            resolutionTime: 0,
            totalVolume: 0,
            creator: msg.sender
        });
    }

    /**
     * @notice Hook called before swap - applies time decay and checks market state
     * @param sender The sender of the swap
     * @param key The pool key
     * @param params Swap parameters
     * @param hookData Hook data
     */
    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        Market storage market = markets[poolId];

        // Check if market is resolved - no trading after resolution
        if (market.isResolved) revert TradingFrozen();

        // Check if event has occurred - attempt resolution
        if (block.timestamp >= market.eventTimestamp) {
            _tryResolveMarket(poolId);
            revert TradingFrozen();
        }

        // Calculate time-adjusted fee
        uint256 timeToEvent = market.eventTimestamp - block.timestamp;
        uint24 adjustedFee = _calculateTimeDecayFee(timeToEvent, key.fee);

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, adjustedFee);
    }

    /**
     * @notice Hook called after swap - updates probability and volume tracking
     * @param sender The sender of the swap
     * @param key The pool key
     * @param params Swap parameters
     * @param delta Balance changes from the swap
     * @param hookData Hook data
     */
    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        Market storage market = markets[poolId];

        // Update total volume
        uint256 swapAmount =
            params.amountSpecified > 0 ? uint256(params.amountSpecified) : uint256(-params.amountSpecified);
        market.totalVolume += swapAmount;

        // Calculate and emit new probability
        // Note: In production, you'd get reserves from pool manager
        // For now, this is a simplified version
        emit ProbabilityUpdated(poolId, 5e17); // Placeholder 50%

        return (BaseHook.afterSwap.selector, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            MARKET RESOLUTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Resolve market using Chainlink oracle
     * @param poolId The pool ID to resolve
     */
    function resolveMarket(PoolId poolId) external {
        Market storage market = markets[poolId];

        if (block.timestamp < market.eventTimestamp) revert EventNotOccurred();
        if (market.isResolved) revert MarketAlreadyResolved();

        // Query Chainlink oracle
        AggregatorV3Interface oracle = AggregatorV3Interface(market.oracleAddress);
        (, int256 answer,, uint256 updatedAt,) = oracle.latestRoundData();

        // Validate oracle response
        require(updatedAt >= market.eventTimestamp, "Stale oracle data");
        require(answer >= 0 && answer < int256(uint256(market.numOutcomes)), "Invalid outcome");

        // Resolve market
        market.isResolved = true;
        market.winningOutcome = uint8(uint256(answer));
        market.resolutionTime = block.timestamp;

        emit MarketResolved(poolId, market.winningOutcome, block.timestamp);
    }

    /**
     * @notice Internal function to attempt market resolution
     * @param poolId The pool ID
     */
    function _tryResolveMarket(PoolId poolId) internal {
        Market storage market = markets[poolId];

        if (market.isResolved) return;

        // Attempt to resolve via oracle
        try this.resolveMarket(poolId) {
        // Resolution successful
        }
            catch {
            // Oracle not ready yet, fail silently
        }
    }

    /*//////////////////////////////////////////////////////////////
                            SETTLEMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Redeem winning outcome tokens for collateral
     * @param poolId The pool ID
     * @param amount Amount of winning tokens to redeem
     */
    function redeemWinningTokens(PoolId poolId, uint256 amount) external {
        Market storage market = markets[poolId];

        if (!market.isResolved) revert MarketNotResolved();
        if (block.timestamp < market.resolutionTime + DISPUTE_PERIOD) {
            revert DisputePeriodActive();
        }

        // In production, you would:
        // 1. Burn winning outcome tokens from msg.sender
        // 2. Transfer collateral 1:1 to msg.sender
        // 3. Collect resolution fee

        emit TokensRedeemed(msg.sender, poolId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            TIME DECAY FEE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate time-adjusted trading fee
     * @param timeToEvent Seconds until event occurs
     * @param baseFee Base fee in basis points
     * @return Adjusted fee with time decay multiplier
     */
    function _calculateTimeDecayFee(uint256 timeToEvent, uint24 baseFee) internal pure returns (uint24) {
        // Triple fees in last hour (3x volatility premium)
        if (timeToEvent < 1 hours) {
            return baseFee * 3;
        }
        // Double fees in last day
        else if (timeToEvent < 1 days) {
            return baseFee * 2;
        }
        // 1.5x fees in last week
        else if (timeToEvent < 7 days) {
            return (baseFee * 3) / 2;
        }

        return baseFee;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get market information
     * @param poolId The pool ID
     * @return Market struct
     */
    function getMarket(PoolId poolId) external view returns (Market memory) {
        return markets[poolId];
    }

    /**
     * @notice Check if market is tradeable
     * @param poolId The pool ID
     * @return true if market can be traded
     */
    function isTradeable(PoolId poolId) external view returns (bool) {
        Market storage market = markets[poolId];
        return !market.isResolved && block.timestamp < market.eventTimestamp;
    }

    /**
     * @notice Get time until event
     * @param poolId The pool ID
     * @return seconds until event (0 if passed)
     */
    function timeUntilEvent(PoolId poolId) external view returns (uint256) {
        Market storage market = markets[poolId];
        if (block.timestamp >= market.eventTimestamp) return 0;
        return market.eventTimestamp - block.timestamp;
    }

    /**
     * @notice Calculate current fee multiplier
     * @param poolId The pool ID
     * @return multiplier in basis points (100 = 1x, 200 = 2x, etc)
     */
    function getCurrentFeeMultiplier(PoolId poolId) external view returns (uint256) {
        Market storage market = markets[poolId];

        // Return 0 if market doesn't exist, is resolved, or event has passed
        if (market.eventTimestamp == 0 || market.isResolved || block.timestamp >= market.eventTimestamp) {
            return 0; // No trading
        }

        uint256 timeToEvent = market.eventTimestamp - block.timestamp;

        if (timeToEvent < 1 hours) return 300; // 3x
        if (timeToEvent < 1 days) return 200; // 2x
        if (timeToEvent < 7 days) return 150; // 1.5x
        return 100; // 1x
    }
}
