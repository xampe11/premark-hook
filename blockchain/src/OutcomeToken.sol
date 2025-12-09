// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OutcomeToken
 * @notice ERC20 token representing a single outcome in a prediction market
 * @dev Only the hook contract can mint/burn these tokens
 */
contract OutcomeToken is ERC20, Ownable {
    /// @notice Market identifier this token belongs to
    bytes32 public immutable marketId;

    /// @notice Outcome index (0 for NO, 1 for YES in binary markets)
    uint8 public immutable outcomeIndex;

    /// @notice Timestamp when the event occurs
    uint256 public immutable eventTimestamp;

    /**
     * @param name Token name (e.g., "BTC-100K-YES")
     * @param symbol Token symbol (e.g., "YES")
     * @param _marketId Unique market identifier
     * @param _outcomeIndex Index of this outcome
     * @param _eventTimestamp When event occurs
     * @param _hook Address of the prediction market hook (owner)
     */
    constructor(
        string memory name,
        string memory symbol,
        bytes32 _marketId,
        uint8 _outcomeIndex,
        uint256 _eventTimestamp,
        address _hook
    ) ERC20(name, symbol) Ownable(_hook) {
        marketId = _marketId;
        outcomeIndex = _outcomeIndex;
        eventTimestamp = _eventTimestamp;
    }

    /**
     * @notice Mint outcome tokens (only hook can call)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burn outcome tokens (only hook can call)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
