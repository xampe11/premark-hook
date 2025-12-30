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
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";

/**
 * @title DeployTestnet
 * @notice Comprehensive testnet deployment script for prediction market system
 * @dev Deploys all contracts using CREATE2 for deterministic hook addresses
 */
contract DeployTestnet is Script {
    // CREATE2 Deployer Proxy for deterministic deployment
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    struct DeploymentAddresses {
        address poolManager;
        address collateralToken;
        address hook;
        address tokenManager;
        address oracle;
    }
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read from environment variables
        address poolManager = vm.envAddress("POOL_MANAGER");
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");

        console2.log("=================================================");
        console2.log("TESTNET DEPLOYMENT");
        console2.log("=================================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("Network:", getChainName());
        console2.log("Pool Manager:", poolManager);
        console2.log("Collateral Token:", collateralToken);
        console2.log("=================================================");

        // Calculate required flags for hook permissions
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );

        // Mine for salt to get correct hook address
        bytes memory creationCode = type(PredictionMarketHook).creationCode;
        bytes memory constructorArgs = abi.encode(IPoolManager(poolManager));

        console2.log("\nMining for hook address with correct flags...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            creationCode,
            constructorArgs
        );

        console2.log("Found valid hook address:", hookAddress);
        console2.log("Salt:", uint256(salt));

        vm.startBroadcast(deployerPrivateKey);

        DeploymentAddresses memory addrs;
        addrs.poolManager = poolManager;
        addrs.collateralToken = collateralToken;

        // 1. Deploy Mock Oracle (for testing)
        console2.log("\n1. Deploying MockChainlinkOracle...");
        MockChainlinkOracle oracle = new MockChainlinkOracle();
        addrs.oracle = address(oracle);
        console2.log("   Oracle deployed at:", addrs.oracle);

        // 2. Deploy PredictionMarketHook using CREATE2 with the mined salt
        console2.log("\n2. Deploying PredictionMarketHook...");
        PredictionMarketHook hook = new PredictionMarketHook{salt: salt}(IPoolManager(poolManager));
        require(address(hook) == hookAddress, "Hook address mismatch");
        addrs.hook = address(hook);
        console2.log("   Hook deployed at:", addrs.hook);

        // 3. Deploy TokenManager
        console2.log("\n3. Deploying TokenManager...");
        TokenManager tokenManager = new TokenManager(address(hook));
        addrs.tokenManager = address(tokenManager);
        console2.log("   TokenManager deployed at:", addrs.tokenManager);

        vm.stopBroadcast();

        // 4. Save deployment addresses
        saveDeploymentAddresses(addrs);

        // 5. Print summary
        printDeploymentSummary(addrs);

        // 6. Verification instructions
        printVerificationInstructions(addrs);
    }
    
    function saveDeploymentAddresses(DeploymentAddresses memory addrs) internal {
        string memory chainName = getChainName();
        string memory json = string.concat(
            '{\n',
            '  "poolManager": "', vm.toString(addrs.poolManager), '",\n',
            '  "collateralToken": "', vm.toString(addrs.collateralToken), '",\n',
            '  "hook": "', vm.toString(addrs.hook), '",\n',
            '  "tokenManager": "', vm.toString(addrs.tokenManager), '",\n',
            '  "oracle": "', vm.toString(addrs.oracle), '"\n',
            '}'
        );

        string memory filename = string.concat("deployments/", chainName, ".json");
        vm.writeFile(filename, json);
        console2.log("\n\nDeployment addresses saved to:", filename);
    }
    
    function printDeploymentSummary(DeploymentAddresses memory addrs) internal view {
        console2.log("\n\n=================================================");
        console2.log("DEPLOYMENT SUMMARY");
        console2.log("=================================================");
        console2.log("Network:", getChainName());
        console2.log("Chain ID:", block.chainid);
        console2.log("\nCONTRACTS:");
        console2.log("  PoolManager:         ", addrs.poolManager);
        console2.log("  CollateralToken:     ", addrs.collateralToken);
        console2.log("  PredictionMarketHook:", addrs.hook);
        console2.log("  TokenManager:        ", addrs.tokenManager);
        console2.log("  MockOracle:          ", addrs.oracle);
        console2.log("=================================================");
        console2.log("\nUpdate your .env file with:");
        console2.log("HOOK_ADDRESS=%s", addrs.hook);
        console2.log("TOKEN_MANAGER=%s", addrs.tokenManager);
        console2.log("ORACLE_ADDRESS=%s", addrs.oracle);
    }
    
    function printVerificationInstructions(DeploymentAddresses memory addrs) internal view {
        console2.log("\n\nVERIFICATION INSTRUCTIONS:");
        console2.log("=================================================");
        console2.log("Use the following addresses to verify on block explorer:");
        console2.log("\n1. MockOracle:", addrs.oracle);
        console2.log("   Contract: src/mocks/MockChainlinkOracle.sol:MockChainlinkOracle");
        console2.log("   Constructor args: none");

        console2.log("\n2. PredictionMarketHook:", addrs.hook);
        console2.log("   Contract: src/PredictionMarketHook.sol:PredictionMarketHook");
        console2.log("   Constructor args: poolManager =", addrs.poolManager);

        console2.log("\n3. TokenManager:", addrs.tokenManager);
        console2.log("   Contract: src/TokenManager.sol:TokenManager");
        console2.log("   Constructor args: hook =", addrs.hook);

        string memory apiKeyVar = block.chainid == 84532 ? "BASESCAN_API_KEY" : "ARBISCAN_API_KEY";
        console2.log("\nAPI Key environment variable:", apiKeyVar);
        console2.log("=================================================");
    }
    
    function getChainName() internal view returns (string memory) {
        if (block.chainid == 84532) return "base-sepolia";
        if (block.chainid == 421614) return "arbitrum-sepolia";
        return "unknown";
    }
    
    function getEtherscanApiKey() internal view returns (string memory) {
        if (block.chainid == 84532) return vm.envString("BASESCAN_API_KEY");
        if (block.chainid == 421614) return vm.envString("ARBISCAN_API_KEY");
        return "";
    }
}
