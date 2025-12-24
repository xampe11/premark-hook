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

        PredictionMarketHook hook = PredictionMarketHook(hookAddress);

        // Create pool key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(collateralToken),
            currency1: Currency.wrap(address(0)), // Or another token
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: hook
        });

        // Initialize market parameters
        hook.initializeMarket(key, eventId, eventTimestamp, oracleAddress, numOutcomes);

        // Initialize pool (this creates the market)
        IPoolManager(poolManager).initialize(key, 79228162514264337593543950336); // SQRT_PRICE_1_1

        vm.stopBroadcast();

        console2.log("Market created successfully!");
    }
}