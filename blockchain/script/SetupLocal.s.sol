// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {TestERC20} from "v4-core/test/TestERC20.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";

/**
 * @title SetupLocal
 * @notice Deploys all infrastructure needed for local Anvil testing
 */
contract SetupLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deployer:", deployer);
        console2.log("\n=== Deploying Local Test Infrastructure ===\n");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PoolManager
        console2.log("Deploying PoolManager...");
        PoolManager poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed at:", address(poolManager));

        // 2. Deploy TestERC20 as collateral token (USDC mock)
        console2.log("\nDeploying TestERC20 (Mock Collateral)...");
        TestERC20 collateralToken = new TestERC20(1_000_000 * 10**18);
        console2.log("CollateralToken deployed at:", address(collateralToken));
        console2.log("Minted 1M tokens to deployer");

        // 3. Deploy MockChainlinkOracle
        console2.log("\nDeploying MockChainlinkOracle...");
        MockChainlinkOracle oracle = new MockChainlinkOracle();
        console2.log("Oracle deployed at:", address(oracle));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Complete ===\n");
        console2.log("Update your .env file with:");
        console2.log("POOL_MANAGER=%s", address(poolManager));
        console2.log("COLLATERAL_TOKEN=%s", address(collateralToken));
        console2.log("ORACLE_ADDRESS=%s", address(oracle));
    }
}
