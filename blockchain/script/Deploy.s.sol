// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

import {PredictionMarketHook} from "../src/PredictionMarketHook.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {OutcomeToken} from "../src/OutcomeToken.sol";

/**
 * @title DeployPredictionMarket
 * @notice Deploys the full prediction market infrastructure
 */
contract DeployPredictionMarket is Script {
    // CREATE2 Deployer Proxy for deterministic deployment
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address poolManager = vm.envAddress("POOL_MANAGER");
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");

        console2.log("Deployer:", deployer);
        console2.log("Pool Manager:", poolManager);
        console2.log("Collateral Token:", collateralToken);
        console2.log("Deploying Prediction Market Hook...");

        // Calculate required flags for hook permissions
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );

        // Predict TokenManager address (deployed after Hook address is computed)
        address predictedTokenManager = vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 1);
        console2.log("Predicted TokenManager address:", predictedTokenManager);

        // Mine for salt to get correct hook address (with TokenManager in constructor)
        bytes memory creationCode = type(PredictionMarketHook).creationCode;
        bytes memory constructorArgs = abi.encode(IPoolManager(poolManager), predictedTokenManager);

        console2.log("Mining for hook address with correct flags...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            creationCode,
            constructorArgs
        );

        console2.log("Found valid hook address:", hookAddress);
        console2.log("Salt:", uint256(salt));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy TokenManager FIRST (with predicted Hook address)
        TokenManager tokenManager = new TokenManager(hookAddress);
        console2.log("TokenManager deployed at:", address(tokenManager));

        // Verify prediction was correct
        require(address(tokenManager) == predictedTokenManager, "TokenManager address prediction failed");

        // Deploy PredictionMarketHook using CREATE2 with the mined salt
        PredictionMarketHook hook = new PredictionMarketHook{salt: salt}(IPoolManager(poolManager));
        require(address(hook) == hookAddress, "Hook address mismatch");
        console2.log("Hook deployed at:", address(hook));

        // Initialize the hook
        hook.initialize(address(tokenManager), msg.sender);
        console2.log("Hook initialized with owner:", msg.sender);

        vm.stopBroadcast();

        console2.log("\n=== Deployment Complete ===");
        console2.log("PredictionMarketHook:", address(hook));
        console2.log("TokenManager:", address(tokenManager));
        console2.log("\nNext steps:");
        console2.log("1. Verify contracts on block explorer");
        console2.log("2. Initialize first prediction market");
        console2.log("3. Add initial liquidity");
    }

}