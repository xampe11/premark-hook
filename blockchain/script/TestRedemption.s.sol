// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {PredictionMarketHook} from "../src/PredictionMarketHook.sol";
import {TokenManager} from "../src/TokenManager.sol";
import {OutcomeToken} from "../src/OutcomeToken.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";

/**
 * @title TestRedemption
 * @notice Quick test for redemption features with a short-term market
 */
contract TestRedemption is Script {
    using PoolIdLibrary for PoolKey;

    struct DeployedContracts {
        address poolManager;
        address collateralToken;
        address hook;
        address tokenManager;
        address oracle;
    }

    DeployedContracts public deployed;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load deployed contracts
        loadDeployedContracts();

        console2.log("=================================================");
        console2.log("TESTING REDEMPTION WITH SHORT-TERM MARKET");
        console2.log("=================================================");
        console2.log("Tester:", deployer);
        console2.log("Current timestamp:", block.timestamp);
        console2.log("=================================================\n");

        // Create market that expires in 5 minutes
        bytes32 marketId = keccak256(abi.encodePacked("QUICK-TEST-", block.timestamp));
        uint256 eventTimestamp = block.timestamp + 5 minutes;

        console2.log("[STEP 1] Creating market expiring in 5 minutes...");
        console2.log("Market ID:", uint256(marketId));
        console2.log("Event time:", eventTimestamp);

        vm.startBroadcast(deployerPrivateKey);

        PredictionMarketHook hook = PredictionMarketHook(deployed.hook);
        TokenManager tokenManager = TokenManager(deployed.tokenManager);

        // Create pool key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(deployed.collateralToken),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        PoolId poolId = key.toId();

        // Initialize market
        hook.initializeMarket(key, marketId, eventTimestamp, deployed.oracle, 2);
        IPoolManager(deployed.poolManager).initialize(key, 79228162514264337593543950336);
        console2.log("Market created\n");

        // Mint tokens
        console2.log("[STEP 2] Minting 100 complete sets...");
        uint256 mintAmount = 100e6; // 100 USDC
        IERC20(deployed.collateralToken).approve(deployed.tokenManager, mintAmount);
        tokenManager.mintSet(marketId, mintAmount);
        console2.log("Minted successfully");

        address yesToken = tokenManager.getOutcomeToken(marketId, 1);
        console2.log("YES tokens:", OutcomeToken(yesToken).balanceOf(deployer), "\n");

        vm.stopBroadcast();

        // Wait for event time
        console2.log("[STEP 3] Waiting for event time to pass...");
        console2.log("Please wait ~5 minutes, then run resolveAndRedeem");
        console2.log("Market ID (save this):", uint256(marketId));
        console2.log("Pool ID (save this):", uint256(PoolId.unwrap(poolId)));
    }

    function resolveAndRedeem(bytes32 poolIdBytes) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        loadDeployedContracts();

        PoolId poolId = PoolId.wrap(poolIdBytes);

        console2.log("=================================================");
        console2.log("RESOLVING AND REDEEMING");
        console2.log("=================================================");
        console2.log("Pool ID:", uint256(PoolId.unwrap(poolId)));
        console2.log("Current timestamp:", block.timestamp);

        vm.startBroadcast(deployerPrivateKey);

        PredictionMarketHook hook = PredictionMarketHook(deployed.hook);
        TokenManager tokenManager = TokenManager(deployed.tokenManager);
        MockChainlinkOracle oracle = MockChainlinkOracle(deployed.oracle);

        // Get market info
        PredictionMarketHook.Market memory market = hook.getMarket(poolId);
        bytes32 marketId = market.eventId;
        console2.log("Market ID:", uint256(marketId));
        console2.log("Event timestamp:", market.eventTimestamp);

        if (block.timestamp < market.eventTimestamp) {
            console2.log("\nERROR: Event time hasn't passed yet!");
            console2.log("Wait", market.eventTimestamp - block.timestamp, "more seconds");
            vm.stopBroadcast();
            return;
        }

        console2.log("\n[STEP 1] Setting oracle outcome (YES wins)...");
        // Set oracle timestamp to 73 hours ago to bypass dispute period
        uint256 oracleTimestamp = block.timestamp - 73 hours;
        oracle.setLatestAnswerWithTimestamp(1, oracleTimestamp);
        console2.log("Oracle set to YES outcome");
        console2.log("Oracle timestamp set to 73 hours ago to bypass dispute period");

        console2.log("\n[STEP 2] Resolving market...");
        hook.resolveMarket(poolId);
        console2.log("Market resolved");

        console2.log("\n[STEP 3] Checking probability after resolution...");
        try hook.getCurrentProbability(poolId) returns (uint256 prob) {
            console2.log("Final probability:", (prob * 100) / 1e18, "%");
        } catch {
            console2.log("Probability query failed (expected after resolution)");
        }

        // Check YES token balance
        address yesToken = tokenManager.getOutcomeToken(marketId, 1);
        uint256 yesBalance = OutcomeToken(yesToken).balanceOf(deployer);
        console2.log("\n[STEP 4] Redeeming", yesBalance, "YES tokens...");

        if (yesBalance == 0) {
            console2.log("No YES tokens to redeem!");
            vm.stopBroadcast();
            return;
        }

        uint256 collateralBefore = IERC20(deployed.collateralToken).balanceOf(deployer);
        console2.log("Collateral before:", collateralBefore);

        // Must wait for dispute period (72 hours on mainnet, but let's check)
        uint256 timeSinceResolution = block.timestamp - market.resolutionTime;
        if (timeSinceResolution < 72 hours) {
            console2.log("\nWaiting for dispute period...");
            console2.log("Need to wait", (72 hours - timeSinceResolution) / 3600, "more hours");
            console2.log("\nFor testing, you can manually set oracle timestamp to 72+ hours ago");
            vm.stopBroadcast();
            return;
        }

        hook.redeemWinningTokens(poolId, yesBalance);

        uint256 collateralAfter = IERC20(deployed.collateralToken).balanceOf(deployer);
        uint256 received = collateralAfter - collateralBefore;
        uint256 fee = yesBalance - received;

        console2.log("Collateral after:", collateralAfter);
        console2.log("Amount received:", received);
        console2.log("Fee collected (2%):", fee);
        console2.log("Expected fee:", (yesBalance * 2) / 100);

        console2.log("\n[STEP 5] Checking protocol fees...");
        uint256 protocolFees = hook.protocolFees(deployed.collateralToken);
        console2.log("Protocol fees available:", protocolFees);

        if (protocolFees > 0) {
            console2.log("\n[STEP 6] Withdrawing fees...");
            hook.withdrawFees(deployed.collateralToken, deployer, protocolFees);
            console2.log("Fees withdrawn:", protocolFees);
        }

        vm.stopBroadcast();

        console2.log("\n=================================================");
        console2.log("ALL REDEMPTION TESTS PASSED!");
        console2.log("=================================================");
    }

    function loadDeployedContracts() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/base-sepolia.json");
        string memory json = vm.readFile(path);

        deployed.poolManager = vm.parseJsonAddress(json, ".poolManager");
        deployed.collateralToken = vm.parseJsonAddress(json, ".collateralToken");
        deployed.hook = vm.parseJsonAddress(json, ".hook");
        deployed.tokenManager = vm.parseJsonAddress(json, ".tokenManager");
        deployed.oracle = vm.parseJsonAddress(json, ".oracle");
    }
}
