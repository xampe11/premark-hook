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
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

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

        // Check if we should deploy our own collateral token or use existing
        address collateralToken;
        bool deployCollateral = vm.envOr("DEPLOY_COLLATERAL", true);

        console2.log("=================================================");
        console2.log("TESTNET DEPLOYMENT");
        console2.log("=================================================");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("Network:", getChainName());
        console2.log("Pool Manager:", poolManager);
        console2.log("Deploy Collateral:", deployCollateral);
        console2.log("=================================================");

        // Calculate required flags for hook permissions
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );

        // We need to pre-compute the hook address because of circular dependency:
        // - Hook needs TokenManager address in constructor
        // - TokenManager needs Hook address in constructor
        // Solution: Deploy TokenManager with predicted Hook address, then deploy Hook

        // Calculate how many contracts will be deployed before TokenManager
        // 1. MockUSDC (if deployCollateral) or nothing
        // 2. MockChainlinkOracle
        // 3. TokenManager <- this is what we want to predict
        uint256 currentNonce = vm.getNonce(deployer);
        uint256 nonceOffset = deployCollateral ? 2 : 1; // +1 for oracle, +1 for USDC if deploying
        address predictedTokenManager = vm.computeCreateAddress(deployer, currentNonce + nonceOffset);

        console2.log("\nCurrent nonce:", currentNonce);
        console2.log("Predicted TokenManager address:", predictedTokenManager);

        // Mine for salt to get correct hook address (with TokenManager in constructor)
        bytes memory creationCode = type(PredictionMarketHook).creationCode;
        bytes memory constructorArgs = abi.encode(IPoolManager(poolManager), predictedTokenManager);

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

        // 1. Deploy collateral token (if needed)
        if (deployCollateral) {
            console2.log("\n1. Deploying Mock USDC...");
            MockUSDC mockUSDC = new MockUSDC();
            addrs.collateralToken = address(mockUSDC);
            console2.log("   Mock USDC deployed at:", addrs.collateralToken);
            console2.log("   Initial balance:", mockUSDC.balanceOf(deployer));
        } else {
            collateralToken = vm.envAddress("COLLATERAL_TOKEN");
            addrs.collateralToken = collateralToken;
            console2.log("\n1. Using existing collateral token:", collateralToken);
        }

        // 2. Deploy Mock Oracle (for testing)
        console2.log("\n2. Deploying MockChainlinkOracle...");
        MockChainlinkOracle oracle = new MockChainlinkOracle();
        addrs.oracle = address(oracle);
        console2.log("   Oracle deployed at:", addrs.oracle);

        // 3. Deploy TokenManager FIRST (with predicted Hook address)
        console2.log("\n3. Deploying TokenManager...");
        TokenManager tokenManager = new TokenManager(hookAddress);
        addrs.tokenManager = address(tokenManager);
        console2.log("   TokenManager deployed at:", addrs.tokenManager);

        // Verify prediction was correct
        require(address(tokenManager) == predictedTokenManager, "TokenManager address prediction failed");

        // 4. Deploy PredictionMarketHook using CREATE2 with the mined salt
        console2.log("\n4. Deploying PredictionMarketHook...");
        PredictionMarketHook hook = new PredictionMarketHook{salt: salt}(IPoolManager(poolManager), address(tokenManager));
        require(address(hook) == hookAddress, "Hook address mismatch");
        addrs.hook = address(hook);
        console2.log("   Hook deployed at:", addrs.hook);

        vm.stopBroadcast();

        // 5. Save deployment addresses
        saveDeploymentAddresses(addrs);

        // 6. Print summary
        printDeploymentSummary(addrs, deployCollateral);

        // 7. Verification instructions
        printVerificationInstructions(addrs, deployCollateral);
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
    
    function printDeploymentSummary(DeploymentAddresses memory addrs, bool deployedCollateral) internal view {
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
        if (deployedCollateral) {
            console2.log("COLLATERAL_TOKEN=%s", addrs.collateralToken);
        }
        console2.log("HOOK_ADDRESS=%s", addrs.hook);
        console2.log("TOKEN_MANAGER=%s", addrs.tokenManager);
        console2.log("ORACLE_ADDRESS=%s", addrs.oracle);
    }
    
    function printVerificationInstructions(DeploymentAddresses memory addrs, bool deployedCollateral) internal view {
        console2.log("\n\nVERIFICATION INSTRUCTIONS:");
        console2.log("=================================================");
        console2.log("Use the following addresses to verify on block explorer:");

        uint8 contractNum = 1;

        if (deployedCollateral) {
            console2.log("\n%d. MockUSDC:", contractNum, addrs.collateralToken);
            console2.log("   Contract: src/mocks/MockUSDC.sol:MockUSDC");
            console2.log("   Constructor args: none");
            contractNum++;
        }

        console2.log("\n%d. MockOracle:", contractNum, addrs.oracle);
        console2.log("   Contract: src/mocks/MockChainlinkOracle.sol:MockChainlinkOracle");
        console2.log("   Constructor args: none");
        contractNum++;

        console2.log("\n%d. PredictionMarketHook:", contractNum, addrs.hook);
        console2.log("   Contract: src/PredictionMarketHook.sol:PredictionMarketHook");
        console2.log("   Constructor args: poolManager =", addrs.poolManager);
        contractNum++;

        console2.log("\n%d. TokenManager:", contractNum, addrs.tokenManager);
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
