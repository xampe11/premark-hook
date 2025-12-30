// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/**
 * @title MintTestTokens
 * @notice Helper script to mint test tokens for testing
 */
contract MintTestTokens is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");

        // Parse recipient and amount from command line or use defaults
        address recipient = vm.envOr("MINT_TO", deployer);
        uint256 amount = vm.envOr("MINT_AMOUNT", uint256(10_000 * 10 ** 6)); // Default: 10k USDC

        console2.log("=================================================");
        console2.log("MINTING TEST TOKENS");
        console2.log("=================================================");
        console2.log("Collateral Token:", collateralToken);
        console2.log("Recipient:", recipient);
        console2.log("Amount:", amount);
        console2.log("=================================================");

        vm.startBroadcast(deployerPrivateKey);

        MockUSDC mockUSDC = MockUSDC(collateralToken);

        uint256 balanceBefore = mockUSDC.balanceOf(recipient);
        console2.log("\nBalance before:", balanceBefore);

        mockUSDC.mint(recipient, amount);

        uint256 balanceAfter = mockUSDC.balanceOf(recipient);
        console2.log("Balance after:", balanceAfter);
        console2.log("Minted:", balanceAfter - balanceBefore);

        vm.stopBroadcast();

        console2.log("\n=================================================");
        console2.log("SUCCESS! Tokens minted.");
        console2.log("=================================================");
    }

    /**
     * @notice Mint standard test amount to an address
     * @param recipient Address to mint to
     */
    function mintTo(address recipient) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");

        console2.log("Minting test tokens to:", recipient);

        vm.startBroadcast(deployerPrivateKey);

        MockUSDC mockUSDC = MockUSDC(collateralToken);
        mockUSDC.mintTestAmount(recipient);

        vm.stopBroadcast();

        console2.log("Minted 10,000 USDC to", recipient);
    }

    /**
     * @notice Mint to multiple addresses
     * @param recipients Array of addresses to mint to
     */
    function mintToMultiple(address[] calldata recipients) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");

        console2.log("Minting to", recipients.length, "addresses");

        vm.startBroadcast(deployerPrivateKey);

        MockUSDC mockUSDC = MockUSDC(collateralToken);

        for (uint256 i = 0; i < recipients.length; i++) {
            mockUSDC.mintTestAmount(recipients[i]);
            console2.log("Minted to:", recipients[i]);
        }

        vm.stopBroadcast();

        console2.log("\nAll tokens minted successfully!");
    }
}
