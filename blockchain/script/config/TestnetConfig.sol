// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// NOTE: This file is deprecated. Use environment variables instead.
// See DeployTestnet.s.sol for the updated deployment pattern.
contract TestnetConfig {
    // Base Sepolia - UPDATE THESE WITH REAL ADDRESSES
    address constant BASE_POOL_MANAGER = address(0);
    address constant BASE_USDC = address(0);
    address constant BASE_CHAINLINK_ETH_USD = address(0);

    // Arbitrum Sepolia - UPDATE THESE WITH REAL ADDRESSES
    address constant ARB_POOL_MANAGER = address(0);
    address constant ARB_USDC = address(0);
    address constant ARB_CHAINLINK_ETH_USD = address(0);
}