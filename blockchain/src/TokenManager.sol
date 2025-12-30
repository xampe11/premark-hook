// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OutcomeToken} from "./OutcomeToken.sol";

/**
 * @title TokenManager
 * @notice Manages minting and burning of complete sets of outcome tokens
 * @dev Users can mint complete sets (1 YES + 1 NO) for 1 collateral, or burn sets to redeem collateral
 */
contract TokenManager {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAmount();
    error MarketResolved();
    error InsufficientBalance();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SetMinted(address indexed user, bytes32 indexed marketId, uint256 amount, uint256 collateralAmount);

    event SetBurned(address indexed user, bytes32 indexed marketId, uint256 amount, uint256 collateralAmount);

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct MarketTokens {
        OutcomeToken[] outcomes;
        IERC20 collateral;
        bool isResolved;
        uint8 winningOutcome;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps market ID to its outcome tokens and collateral
    mapping(bytes32 => MarketTokens) public markets;

    /// @notice Hook contract address (authorized to create markets)
    address public immutable hook;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _hook) {
        hook = _hook;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyHook() {
        require(msg.sender == hook, "Only hook");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            MARKET CREATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new market with its outcome tokens
     * @param marketId Unique market identifier
     * @param outcomeTokens Array of outcome token addresses
     * @param collateral Collateral token address
     */
    function registerMarket(bytes32 marketId, address[] calldata outcomeTokens, address collateral) external onlyHook {
        MarketTokens storage market = markets[marketId];

        for (uint256 i = 0; i < outcomeTokens.length; i++) {
            market.outcomes.push(OutcomeToken(outcomeTokens[i]));
        }

        market.collateral = IERC20(collateral);
        market.isResolved = false;
    }

    /*//////////////////////////////////////////////////////////////
                            MINTING & BURNING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint a complete set of outcome tokens
     * @dev User deposits collateral and receives 1 of each outcome token
     * @param marketId Market identifier
     * @param amount Amount of sets to mint
     */
    function mintSet(bytes32 marketId, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        MarketTokens storage market = markets[marketId];
        if (market.isResolved) revert MarketResolved();

        // Transfer collateral from user
        market.collateral.safeTransferFrom(msg.sender, address(this), amount);

        // Mint outcome tokens to user
        for (uint256 i = 0; i < market.outcomes.length; i++) {
            market.outcomes[i].mint(msg.sender, amount);
        }

        emit SetMinted(msg.sender, marketId, amount, amount);
    }

    /**
     * @notice Burn a complete set of outcome tokens to redeem collateral
     * @dev User burns 1 of each outcome token and receives 1 collateral
     * @param marketId Market identifier
     * @param amount Amount of sets to burn
     */
    function burnSet(bytes32 marketId, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        MarketTokens storage market = markets[marketId];

        // Check user has enough of each outcome token
        for (uint256 i = 0; i < market.outcomes.length; i++) {
            if (market.outcomes[i].balanceOf(msg.sender) < amount) {
                revert InsufficientBalance();
            }
        }

        // Burn outcome tokens from user
        for (uint256 i = 0; i < market.outcomes.length; i++) {
            market.outcomes[i].burn(msg.sender, amount);
        }

        // Transfer collateral back to user
        market.collateral.safeTransfer(msg.sender, amount);

        emit SetBurned(msg.sender, marketId, amount, amount);
    }

    /**
     * @notice Redeem winning outcome tokens after market resolution
     * @param marketId Market identifier
     * @param user Address of user redeeming tokens
     * @param amount Amount of winning tokens to redeem
     * @param feeRecipient Address to receive resolution fee (address(0) for no fee)
     * @param feePercent Fee percentage in basis points (e.g., 200 = 2%)
     * @return payout Amount of collateral transferred to user (after fee)
     */
    function redeemWinning(bytes32 marketId, address user, uint256 amount, address feeRecipient, uint256 feePercent)
        external
        returns (uint256 payout)
    {
        if (amount == 0) revert InvalidAmount();

        MarketTokens storage market = markets[marketId];
        if (!market.isResolved) revert MarketResolved();

        OutcomeToken winningToken = market.outcomes[market.winningOutcome];

        if (winningToken.balanceOf(user) < amount) {
            revert InsufficientBalance();
        }

        // Burn winning tokens from user
        winningToken.burn(user, amount);

        // Calculate fee and payout
        uint256 fee = 0;
        if (feeRecipient != address(0) && feePercent > 0) {
            fee = (amount * feePercent) / 10000; // feePercent in basis points
            payout = amount - fee;

            // Transfer fee to recipient
            if (fee > 0) {
                market.collateral.safeTransfer(feeRecipient, fee);
            }
        } else {
            payout = amount;
        }

        // Transfer remaining collateral to user
        market.collateral.safeTransfer(user, payout);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Resolve a market (only hook can call)
     * @param marketId Market identifier
     * @param winningOutcome Index of winning outcome
     */
    function resolveMarket(bytes32 marketId, uint8 winningOutcome) external onlyHook {
        MarketTokens storage market = markets[marketId];
        market.isResolved = true;
        market.winningOutcome = winningOutcome;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get number of outcomes for a market
     * @param marketId Market identifier
     * @return Number of outcome tokens
     */
    function getOutcomeCount(bytes32 marketId) external view returns (uint256) {
        return markets[marketId].outcomes.length;
    }

    /**
     * @notice Get outcome token address
     * @param marketId Market identifier
     * @param index Outcome index
     * @return Token address
     */
    function getOutcomeToken(bytes32 marketId, uint256 index) external view returns (address) {
        return address(markets[marketId].outcomes[index]);
    }

    /**
     * @notice Check if user has complete set
     * @param marketId Market identifier
     * @param user User address
     * @return amount Minimum complete sets user owns
     */
    function getCompleteSetBalance(bytes32 marketId, address user) external view returns (uint256 amount) {
        MarketTokens storage market = markets[marketId];

        amount = type(uint256).max;
        for (uint256 i = 0; i < market.outcomes.length; i++) {
            uint256 balance = market.outcomes[i].balanceOf(user);
            if (balance < amount) {
                amount = balance;
            }
        }

        if (amount == type(uint256).max) {
            amount = 0;
        }
    }

    /**
     * @notice Get collateral token address for a market
     * @param marketId Market identifier
     * @return Collateral token address
     */
    function getCollateralToken(bytes32 marketId) external view returns (address) {
        return address(markets[marketId].collateral);
    }
}
