// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "solmate/src/tokens/ERC20.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC token for testnet testing with open minting
 * @dev Anyone can mint tokens for testing purposes
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC", 6) {
        // Mint initial supply to deployer for testing
        _mint(msg.sender, 1_000_000 * 10 ** 6); // 1M USDC
    }

    /**
     * @notice Mint tokens to any address (open for testing)
     * @param to Address to mint tokens to
     * @param amount Amount to mint (in token decimals)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from caller
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Burn tokens from any address (for testing)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /**
     * @notice Helper to mint standard amounts for testing
     * @param to Address to mint to
     */
    function mintTestAmount(address to) external {
        _mint(to, 10_000 * 10 ** 6); // 10k USDC
    }
}
