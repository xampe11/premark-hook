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
 * @title TestBaseSepolia
 * @notice Integration testing script for deployed contracts on Base Sepolia
 * @dev Tests the full flow: create market, mint, burn, and redeem
 */
contract TestBaseSepolia is Script {
    using PoolIdLibrary for PoolKey;

    struct DeployedContracts {
        address poolManager;
        address collateralToken;
        address hook;
        address tokenManager;
        address oracle;
    }

    DeployedContracts public deployed;
    bytes32 public testMarketId;
    uint256 public testEventTimestamp;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load deployed contracts from file
        loadDeployedContracts();

        console2.log("=================================================");
        console2.log("TESTING DEPLOYED CONTRACTS ON BASE SEPOLIA");
        console2.log("=================================================");
        console2.log("Tester Address:", deployer);
        console2.log("Chain ID:", block.chainid);
        printContracts();
        console2.log("=================================================\n");

        // Check collateral balance
        uint256 collateralBalance = IERC20(deployed.collateralToken).balanceOf(deployer);
        console2.log("Your collateral balance:", collateralBalance);

        if (collateralBalance == 0) {
            console2.log("\nWARNING: You have no collateral tokens!");
            console2.log("You need to acquire some collateral tokens first to test minting.");
            console2.log("Collateral token address:", deployed.collateralToken);
            return;
        }

        // Run test suite
        console2.log("\n=================================================");
        console2.log("RUNNING TEST SUITE");
        console2.log("=================================================\n");

        // Test 1: Create a new market
        test_CreateMarket(deployerPrivateKey);

        // Test 2: Mint a complete set
        test_MintSet(deployerPrivateKey, collateralBalance);

        // Test 3: Check balances
        test_CheckBalances(deployer);

        // Test 4: Burn a set
        test_BurnSet(deployerPrivateKey);

        // Test 5: Update oracle price
        test_UpdateOracle(deployerPrivateKey);

        // Test 6: Get probability (Priority 1 feature)
        test_GetProbability();

        // Test 7: Resolve market and redeem winning tokens (Priority 1 features)
        test_ResolveAndRedeem(deployerPrivateKey, deployer);

        // Test 8: Withdraw fees (Priority 1 feature)
        test_WithdrawFees(deployerPrivateKey);

        console2.log("\n=================================================");
        console2.log("ALL TESTS COMPLETED");
        console2.log("=================================================");
    }

    function loadDeployedContracts() internal {
        // Read from deployment file
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/base-sepolia.json");
        string memory json = vm.readFile(path);

        deployed.poolManager = vm.parseJsonAddress(json, ".poolManager");
        deployed.collateralToken = vm.parseJsonAddress(json, ".collateralToken");
        deployed.hook = vm.parseJsonAddress(json, ".hook");
        deployed.tokenManager = vm.parseJsonAddress(json, ".tokenManager");
        deployed.oracle = vm.parseJsonAddress(json, ".oracle");

        console2.log("Loaded deployment addresses from:", path);
    }

    function printContracts() internal view {
        console2.log("PoolManager:     ", deployed.poolManager);
        console2.log("CollateralToken: ", deployed.collateralToken);
        console2.log("Hook:            ", deployed.hook);
        console2.log("TokenManager:    ", deployed.tokenManager);
        console2.log("Oracle:          ", deployed.oracle);
    }

    function test_CreateMarket(uint256 privateKey) internal {
        console2.log("\n[TEST 1] Creating a new prediction market...");
        console2.log("---------------------------------------------");

        // Generate unique market parameters
        testMarketId = keccak256(abi.encodePacked("BTC-100K-TEST-", block.timestamp));
        testEventTimestamp = block.timestamp + 30 days;
        uint8 numOutcomes = 2;

        console2.log("Market ID:", uint256(testMarketId));
        console2.log("Event Timestamp:", testEventTimestamp);
        console2.log("Number of Outcomes:", numOutcomes);

        vm.startBroadcast(privateKey);

        PredictionMarketHook hook = PredictionMarketHook(deployed.hook);

        // Create pool key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)), // Native currency
            currency1: Currency.wrap(deployed.collateralToken),
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: hook
        });

        try hook.initializeMarket(key, testMarketId, testEventTimestamp, deployed.oracle, numOutcomes) {
            console2.log("Market parameters initialized");
        } catch Error(string memory reason) {
            console2.log("Failed to initialize market:", reason);
            vm.stopBroadcast();
            return;
        }

        try IPoolManager(deployed.poolManager).initialize(key, 79228162514264337593543950336) {
            console2.log("Pool initialized successfully");
        } catch Error(string memory reason) {
            console2.log("Failed to initialize pool:", reason);
            vm.stopBroadcast();
            return;
        }

        vm.stopBroadcast();

        console2.log("\n[RESULT] Market created successfully!");
    }

    function test_MintSet(uint256 privateKey, uint256 balance) internal {
        console2.log("\n[TEST 2] Minting a complete set of outcome tokens...");
        console2.log("-----------------------------------------------------");

        // Use a small amount for testing (1% of balance or 10 tokens, whichever is smaller)
        uint256 mintAmount;
        if (balance > 1000) {
            mintAmount = balance / 100;
        } else {
            mintAmount = 10;
        }

        if (mintAmount > balance) {
            mintAmount = balance;
        }

        console2.log("Mint Amount:", mintAmount);

        vm.startBroadcast(privateKey);

        TokenManager tokenManager = TokenManager(deployed.tokenManager);
        IERC20 collateral = IERC20(deployed.collateralToken);

        // Approve TokenManager to spend collateral
        console2.log("Approving TokenManager...");
        collateral.approve(deployed.tokenManager, mintAmount);

        // Mint complete set
        try tokenManager.mintSet(testMarketId, mintAmount) {
            console2.log("Minted complete set successfully");
        } catch Error(string memory reason) {
            console2.log("Failed to mint set:", reason);
            vm.stopBroadcast();
            return;
        }

        vm.stopBroadcast();

        console2.log("\n[RESULT] Set minted successfully!");
    }

    function test_CheckBalances(address user) internal view {
        console2.log("\n[TEST 3] Checking token balances...");
        console2.log("------------------------------------");

        TokenManager tokenManager = TokenManager(deployed.tokenManager);

        // Get outcome tokens
        uint256 outcomeCount = tokenManager.getOutcomeCount(testMarketId);
        console2.log("Number of outcomes:", outcomeCount);

        for (uint256 i = 0; i < outcomeCount; i++) {
            address outcomeToken = tokenManager.getOutcomeToken(testMarketId, i);
            if (outcomeToken != address(0)) {
                uint256 balance = OutcomeToken(outcomeToken).balanceOf(user);
                string memory name = OutcomeToken(outcomeToken).name();
                console2.log(string.concat("Outcome ", vm.toString(i), " (", name, "): ", vm.toString(balance)));
            }
        }

        uint256 completeSetBalance = tokenManager.getCompleteSetBalance(testMarketId, user);
        console2.log("Complete set balance:", completeSetBalance);

        console2.log("\n[RESULT] Balances checked successfully!");
    }

    function test_BurnSet(uint256 privateKey) internal {
        console2.log("\n[TEST 4] Burning a portion of the complete set...");
        console2.log("--------------------------------------------------");

        address deployer = vm.addr(privateKey);
        TokenManager tokenManager = TokenManager(deployed.tokenManager);

        // Get current complete set balance
        uint256 completeSetBalance = tokenManager.getCompleteSetBalance(testMarketId, deployer);

        if (completeSetBalance == 0) {
            console2.log("No complete sets to burn");
            console2.log("\n[RESULT] Test skipped - no sets to burn");
            return;
        }

        // Burn half of the complete set
        uint256 burnAmount = completeSetBalance / 2;
        if (burnAmount == 0) burnAmount = completeSetBalance;

        console2.log("Burning amount:", burnAmount);

        vm.startBroadcast(privateKey);

        try tokenManager.burnSet(testMarketId, burnAmount) {
            console2.log("Burned set successfully");
        } catch Error(string memory reason) {
            console2.log("Failed to burn set:", reason);
            vm.stopBroadcast();
            return;
        }

        vm.stopBroadcast();

        console2.log("\n[RESULT] Set burned successfully!");

        // Check balances after burn
        uint256 newBalance = tokenManager.getCompleteSetBalance(testMarketId, deployer);
        console2.log("New complete set balance:", newBalance);
    }

    function test_UpdateOracle(uint256 privateKey) internal {
        console2.log("\n[TEST 5] Updating oracle price...");
        console2.log("----------------------------------");

        MockChainlinkOracle oracle = MockChainlinkOracle(deployed.oracle);

        // Set a test price (e.g., BTC at $95,000)
        int256 newPrice = 95000 * 1e8; // Chainlink uses 8 decimals
        console2.log("Setting new price:", uint256(newPrice));

        vm.startBroadcast(privateKey);

        try oracle.setLatestAnswer(newPrice) {
            console2.log("Oracle price updated");
        } catch Error(string memory reason) {
            console2.log("Failed to update oracle:", reason);
            vm.stopBroadcast();
            return;
        }

        vm.stopBroadcast();

        // Read back the price
        (, int256 answer,,,) = oracle.latestRoundData();
        console2.log("Current oracle price:", uint256(answer));

        console2.log("\n[RESULT] Oracle updated successfully!");
    }

    function test_GetProbability() internal view {
        console2.log("\n[TEST 6] Getting current market probability...");
        console2.log("-----------------------------------------------");

        PredictionMarketHook hook = PredictionMarketHook(deployed.hook);

        // Get pool ID from the pool key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(deployed.collateralToken),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });

        PoolId poolId = key.toId();

        try hook.getCurrentProbability(poolId) returns (uint256 probability) {
            // Probability is in 1e18 format, convert to percentage
            uint256 percentage = (probability * 100) / 1e18;
            console2.log("Current probability:", probability);
            console2.log("As percentage:", percentage, "%");
            console2.log("\n[RESULT] Probability retrieved successfully!");
        } catch Error(string memory reason) {
            console2.log("Failed to get probability:", reason);
            console2.log("\n[RESULT] Test failed");
        }
    }

    function test_ResolveAndRedeem(uint256 privateKey, address deployer) internal {
        console2.log("\n[TEST 7] Resolving market and redeeming winning tokens...");
        console2.log("----------------------------------------------------------");

        PredictionMarketHook hook = PredictionMarketHook(deployed.hook);
        TokenManager tokenManager = TokenManager(deployed.tokenManager);
        MockChainlinkOracle oracle = MockChainlinkOracle(deployed.oracle);

        // Get pool ID
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(deployed.collateralToken),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        PoolId poolId = key.toId();

        // Check if we have outcome tokens to redeem
        uint256 outcomeCount = tokenManager.getOutcomeCount(testMarketId);
        if (outcomeCount == 0) {
            console2.log("No outcome tokens found - skipping redemption test");
            console2.log("\n[RESULT] Test skipped");
            return;
        }

        address yesToken = tokenManager.getOutcomeToken(testMarketId, 1);
        uint256 yesBalance = OutcomeToken(yesToken).balanceOf(deployer);

        if (yesBalance == 0) {
            console2.log("No YES tokens to redeem - skipping redemption test");
            console2.log("\n[RESULT] Test skipped");
            return;
        }

        console2.log("YES token balance before:", yesBalance);

        vm.startBroadcast(privateKey);

        // Warp time to after event
        vm.warp(testEventTimestamp + 1);
        console2.log("Warped to after event time");

        // Set oracle result (YES wins = outcome 1)
        try oracle.setLatestAnswerWithTimestamp(1, testEventTimestamp + 1) {
            console2.log("Oracle set to YES outcome");
        } catch Error(string memory reason) {
            console2.log("Failed to set oracle:", reason);
            vm.stopBroadcast();
            return;
        }

        // Resolve market
        try hook.resolveMarket(poolId) {
            console2.log("Market resolved successfully");
        } catch Error(string memory reason) {
            console2.log("Failed to resolve market:", reason);
            vm.stopBroadcast();
            return;
        }

        // Wait for dispute period (72 hours)
        vm.warp(testEventTimestamp + 1 + 72 hours);
        console2.log("Dispute period ended");

        // Get collateral balance before redemption
        uint256 collateralBefore = IERC20(deployed.collateralToken).balanceOf(deployer);
        console2.log("Collateral balance before redemption:", collateralBefore);

        // Redeem winning tokens (should get 98% back due to 2% fee)
        uint256 redeemAmount = yesBalance;
        try hook.redeemWinningTokens(poolId, redeemAmount) {
            console2.log("Redeemed", redeemAmount, "winning tokens");
        } catch Error(string memory reason) {
            console2.log("Failed to redeem tokens:", reason);
            vm.stopBroadcast();
            return;
        }

        vm.stopBroadcast();

        // Check balances after redemption
        uint256 collateralAfter = IERC20(deployed.collateralToken).balanceOf(deployer);
        uint256 collateralReceived = collateralAfter - collateralBefore;
        uint256 expectedPayout = redeemAmount - (redeemAmount * 2 / 100); // 98%

        console2.log("Collateral received:", collateralReceived);
        console2.log("Expected payout (98%):", expectedPayout);
        console2.log("Fee collected (2%):", redeemAmount - collateralReceived);

        console2.log("\n[RESULT] Redemption completed successfully!");
    }

    function test_WithdrawFees(uint256 privateKey) internal {
        console2.log("\n[TEST 8] Withdrawing protocol fees...");
        console2.log("--------------------------------------");

        PredictionMarketHook hook = PredictionMarketHook(deployed.hook);
        address deployer = vm.addr(privateKey);

        // Check protocol fees
        uint256 protocolFees = hook.protocolFees(deployed.collateralToken);
        console2.log("Protocol fees available:", protocolFees);

        if (protocolFees == 0) {
            console2.log("No fees to withdraw");
            console2.log("\n[RESULT] Test skipped - no fees available");
            return;
        }

        uint256 balanceBefore = IERC20(deployed.collateralToken).balanceOf(deployer);

        vm.startBroadcast(privateKey);

        try hook.withdrawFees(deployed.collateralToken, deployer, protocolFees) {
            console2.log("Fees withdrawn successfully");
        } catch Error(string memory reason) {
            console2.log("Failed to withdraw fees:", reason);
            vm.stopBroadcast();
            return;
        }

        vm.stopBroadcast();

        uint256 balanceAfter = IERC20(deployed.collateralToken).balanceOf(deployer);
        uint256 feesReceived = balanceAfter - balanceBefore;

        console2.log("Fees received:", feesReceived);
        console2.log("\n[RESULT] Fees withdrawn successfully!");
    }

    // Additional helper function to test a specific market ID
    function testExistingMarket(bytes32 marketId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        loadDeployedContracts();

        console2.log("=================================================");
        console2.log("TESTING EXISTING MARKET");
        console2.log("=================================================");
        console2.log("Market ID:", uint256(marketId));

        testMarketId = marketId;

        test_CheckBalances(deployer);
    }
}
