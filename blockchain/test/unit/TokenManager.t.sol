// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {TokenManager} from "../../src/TokenManager.sol";
import {OutcomeToken} from "../../src/OutcomeToken.sol";

contract TokenManagerTest is Test {
    TokenManager tokenManager;
    MockERC20 collateral;
    OutcomeToken yesToken;
    OutcomeToken noToken;

    bytes32 constant MARKET_ID = keccak256("TEST-MARKET");
    uint256 constant EVENT_TIMESTAMP = 1735689600; // Jan 1, 2025

    address hook = makeAddr("hook");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // Deploy collateral
        collateral = new MockERC20("USDC", "USDC", 6);

        // Deploy token manager
        vm.prank(hook);
        tokenManager = new TokenManager(hook);

        // Deploy outcome tokens
        yesToken = new OutcomeToken("BTC-100K-YES", "YES", MARKET_ID, 1, EVENT_TIMESTAMP, address(tokenManager));

        noToken = new OutcomeToken("BTC-100K-NO", "NO", MARKET_ID, 0, EVENT_TIMESTAMP, address(tokenManager));

        // Register market
        address[] memory outcomes = new address[](2);
        outcomes[0] = address(noToken);
        outcomes[1] = address(yesToken);

        vm.prank(hook);
        tokenManager.registerMarket(MARKET_ID, outcomes, address(collateral));

        // Mint collateral to users
        collateral.mint(alice, 1000e6);
        collateral.mint(bob, 1000e6);
    }

    /*//////////////////////////////////////////////////////////////
                        MINT SET TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MintSet() public {
        uint256 amount = 100e6;

        vm.startPrank(alice);
        collateral.approve(address(tokenManager), amount);
        tokenManager.mintSet(MARKET_ID, amount);
        vm.stopPrank();

        // Alice should have YES and NO tokens
        assertEq(yesToken.balanceOf(alice), amount);
        assertEq(noToken.balanceOf(alice), amount);

        // TokenManager should have collateral
        assertEq(collateral.balanceOf(address(tokenManager)), amount);
    }

    function test_MintSet_MultipleUsers() public {
        uint256 aliceAmount = 100e6;
        uint256 bobAmount = 50e6;

        // Alice mints
        vm.startPrank(alice);
        collateral.approve(address(tokenManager), aliceAmount);
        tokenManager.mintSet(MARKET_ID, aliceAmount);
        vm.stopPrank();

        // Bob mints
        vm.startPrank(bob);
        collateral.approve(address(tokenManager), bobAmount);
        tokenManager.mintSet(MARKET_ID, bobAmount);
        vm.stopPrank();

        assertEq(yesToken.balanceOf(alice), aliceAmount);
        assertEq(yesToken.balanceOf(bob), bobAmount);
        assertEq(collateral.balanceOf(address(tokenManager)), aliceAmount + bobAmount);
    }

    function test_RevertIf_MintZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(TokenManager.InvalidAmount.selector);
        tokenManager.mintSet(MARKET_ID, 0);
    }

    function test_RevertIf_MintInsufficientCollateral() public {
        uint256 amount = 2000e6; // More than Alice has

        vm.startPrank(alice);
        collateral.approve(address(tokenManager), amount);
        vm.expectRevert();
        tokenManager.mintSet(MARKET_ID, amount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        BURN SET TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BurnSet() public {
        uint256 amount = 100e6;

        // First mint
        vm.startPrank(alice);
        collateral.approve(address(tokenManager), amount);
        tokenManager.mintSet(MARKET_ID, amount);

        // Then burn half
        uint256 burnAmount = 50e6;
        tokenManager.burnSet(MARKET_ID, burnAmount);
        vm.stopPrank();

        // Check balances
        assertEq(yesToken.balanceOf(alice), amount - burnAmount);
        assertEq(noToken.balanceOf(alice), amount - burnAmount);
        assertEq(collateral.balanceOf(alice), 1000e6 - amount + burnAmount);
    }

    function test_BurnSet_CompleteSet() public {
        uint256 amount = 100e6;

        // Mint and burn all
        vm.startPrank(alice);
        collateral.approve(address(tokenManager), amount);
        tokenManager.mintSet(MARKET_ID, amount);
        tokenManager.burnSet(MARKET_ID, amount);
        vm.stopPrank();

        // Should be back to starting state
        assertEq(yesToken.balanceOf(alice), 0);
        assertEq(noToken.balanceOf(alice), 0);
        assertEq(collateral.balanceOf(alice), 1000e6);
    }

    function test_RevertIf_BurnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(TokenManager.InvalidAmount.selector);
        tokenManager.burnSet(MARKET_ID, 0);
    }

    function test_RevertIf_BurnInsufficientTokens() public {
        uint256 mintAmount = 100e6;
        uint256 burnAmount = 150e6;

        vm.startPrank(alice);
        collateral.approve(address(tokenManager), mintAmount);
        tokenManager.mintSet(MARKET_ID, mintAmount);

        vm.expectRevert(TokenManager.InsufficientBalance.selector);
        tokenManager.burnSet(MARKET_ID, burnAmount);
        vm.stopPrank();
    }

    function test_RevertIf_BurnIncompleteSet() public {
        uint256 amount = 100e6;

        // Mint set
        vm.startPrank(alice);
        collateral.approve(address(tokenManager), amount);
        tokenManager.mintSet(MARKET_ID, amount);

        // Transfer away some YES tokens
        yesToken.transfer(bob, 50e6);

        // Try to burn full amount (but don't have enough YES tokens)
        vm.expectRevert(TokenManager.InsufficientBalance.selector);
        tokenManager.burnSet(MARKET_ID, amount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RedeemWinning_AfterResolution() public {
        uint256 amount = 100e6;

        // Mint set
        vm.startPrank(alice);
        collateral.approve(address(tokenManager), amount);
        tokenManager.mintSet(MARKET_ID, amount);
        vm.stopPrank();

        // Resolve market (YES wins)
        vm.prank(hook);
        tokenManager.resolveMarket(MARKET_ID, 1);

        // Redeem winning tokens
        vm.prank(alice);
        tokenManager.redeemWinning(MARKET_ID, amount);

        // Alice should have her collateral back
        assertEq(collateral.balanceOf(alice), 1000e6);
        assertEq(yesToken.balanceOf(alice), 0);
        // NO tokens are now worthless
        assertEq(noToken.balanceOf(alice), amount);
    }

    function test_RevertIf_RedeemBeforeResolution() public {
        uint256 amount = 100e6;

        vm.startPrank(alice);
        collateral.approve(address(tokenManager), amount);
        tokenManager.mintSet(MARKET_ID, amount);

        vm.expectRevert(TokenManager.MarketResolved.selector);
        tokenManager.redeemWinning(MARKET_ID, amount);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetOutcomeCount() public view {
        assertEq(tokenManager.getOutcomeCount(MARKET_ID), 2);
    }

    function test_GetOutcomeToken() public view {
        assertEq(tokenManager.getOutcomeToken(MARKET_ID, 0), address(noToken));
        assertEq(tokenManager.getOutcomeToken(MARKET_ID, 1), address(yesToken));
    }

    function test_GetCompleteSetBalance() public {
        uint256 amount = 100e6;

        // Initially zero
        assertEq(tokenManager.getCompleteSetBalance(MARKET_ID, alice), 0);

        // After minting
        vm.startPrank(alice);
        collateral.approve(address(tokenManager), amount);
        tokenManager.mintSet(MARKET_ID, amount);
        vm.stopPrank();

        assertEq(tokenManager.getCompleteSetBalance(MARKET_ID, alice), amount);

        // After transferring some YES tokens
        vm.prank(alice);
        yesToken.transfer(bob, 30e6);

        // Complete set balance is limited by minimum
        assertEq(tokenManager.getCompleteSetBalance(MARKET_ID, alice), 70e6);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MintAndBurn(uint256 amount) public {
        amount = bound(amount, 1, 1000e6);

        vm.startPrank(alice);
        collateral.approve(address(tokenManager), amount);
        tokenManager.mintSet(MARKET_ID, amount);
        tokenManager.burnSet(MARKET_ID, amount);
        vm.stopPrank();

        // Should return to original state
        assertEq(collateral.balanceOf(alice), 1000e6);
        assertEq(yesToken.balanceOf(alice), 0);
        assertEq(noToken.balanceOf(alice), 0);
    }

    function testFuzz_MultipleUsersIndependent(uint256 aliceAmount, uint256 bobAmount) public {
        aliceAmount = bound(aliceAmount, 1, 1000e6);
        bobAmount = bound(bobAmount, 1, 1000e6);

        // Alice mints
        vm.startPrank(alice);
        collateral.approve(address(tokenManager), aliceAmount);
        tokenManager.mintSet(MARKET_ID, aliceAmount);
        vm.stopPrank();

        // Bob mints
        vm.startPrank(bob);
        collateral.approve(address(tokenManager), bobAmount);
        tokenManager.mintSet(MARKET_ID, bobAmount);
        vm.stopPrank();

        // Check independence
        assertEq(yesToken.balanceOf(alice), aliceAmount);
        assertEq(yesToken.balanceOf(bob), bobAmount);
        assertEq(collateral.balanceOf(address(tokenManager)), aliceAmount + bobAmount);
    }
}
