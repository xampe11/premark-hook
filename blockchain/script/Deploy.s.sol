// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {PredictionMarketHook} from "../src/PredictionMarketHook.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {OutcomeToken} from "../src/OutcomeToken.sol";

/**
 * @title DeployPredictionMarket
 * @notice Deploys the full prediction market infrastructure
 */
contract DeployPredictionMarket is Script {
    // Addresses (update for your network)
    address constant POOL_MANAGER = address(0); // UPDATE: v4 PoolManager address
    address constant COLLATERAL_TOKEN = address(0); // UPDATE: USDC or other stablecoin

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deployer:", deployer);
        console2.log("Deploying Prediction Market Hook...");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PredictionMarketHook at correct address
        address hookAddress = _getHookAddress();
        console2.log("Target hook address:", hookAddress);

        // Note: In production, you need to deploy to the exact address
        // This requires CREATE2 with proper salt calculation
        PredictionMarketHook hook = new PredictionMarketHook(IPoolManager(POOL_MANAGER));
        console2.log("Hook deployed at:", address(hook));

        // 2. Deploy TokenManager
        TokenManager tokenManager = new TokenManager(address(hook));
        console2.log("TokenManager deployed at:", address(tokenManager));

        vm.stopBroadcast();

        console2.log("\n=== Deployment Complete ===");
        console2.log("PredictionMarketHook:", address(hook));
        console2.log("TokenManager:", address(tokenManager));
        console2.log("\nNext steps:");
        console2.log("1. Verify contracts on block explorer");
        console2.log("2. Initialize first prediction market");
        console2.log("3. Add initial liquidity");
    }

    /**
     * @notice Calculate the required hook address based on permissions
     * @dev Hook address must have specific flags set in its bits
     */
    function _getHookAddress() internal pure returns (address) {
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);

        // In production, use CREATE2 to deploy to this exact address
        return address(flags);
    }
}

/**
 * @title CreateMarket
 * @notice Script to create a new prediction market
 */
contract CreateMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hookAddress = vm.envAddress("HOOK_ADDRESS");
        address poolManager = vm.envAddress("POOL_MANAGER");
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");

        // Market parameters
        bytes32 eventId = keccak256(abi.encodePacked("BTC-100K-", block.timestamp));
        uint256 eventTimestamp = block.timestamp + 30 days;
        uint8 numOutcomes = 2;

        console2.log("Creating prediction market...");
        console2.log("Event ID:", uint256(eventId));
        console2.log("Event Timestamp:", eventTimestamp);

        vm.startBroadcast(deployerPrivateKey);

        // Encode market parameters
        bytes memory hookData = abi.encode(eventId, eventTimestamp, oracleAddress, numOutcomes);

        // Create pool key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(collateralToken),
            currency1: Currency.wrap(address(0)), // Or another token
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: PredictionMarketHook(hookAddress)
        });

        // Initialize pool (this creates the market)
        IPoolManager(poolManager)
            .initialize(
                key,
                79228162514264337593543950336, // SQRT_PRICE_1_1
                hookData
            );

        vm.stopBroadcast();

        console2.log("Market created successfully!");
    }
}
