// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";

contract CrowdfundingTest is Test {
    Crowdfunding public crowdfunding;

    address public creator = makeAddr("creator");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant GOAL = 5 ether;
    uint256 public constant DURATION_DAYS = 7;

    function setUp() public {
        crowdfunding = new Crowdfunding();

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_CreateCampaign() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign(
            "Build Game",
            "Decentralized RPG",
            GOAL,
            DURATION_DAYS
        );

        assertEq(campaignId, 1);
        assertEq(crowdfunding.campaignCount(), 1);

        (
            address _creator,
            string memory _title,
            ,
            uint256 _goal,
            uint256 _deadline,
            uint256 _amountRaised,
            bool _claimed
        ) = crowdfunding.getCampaign(1);

        assertEq(_creator, creator);
        assertEq(_title, "Build Game");
        assertEq(_goal, GOAL);
        assertEq(_deadline, block.timestamp + (DURATION_DAYS * 1 days));
        assertEq(_amountRaised, 0);
        assertFalse(_claimed);
    }

    function test_Contribute() public {
        vm.prank(creator);
        crowdfunding.createCampaign(
            "Build Game",
            "Decentralized RPG",
            GOAL,
            DURATION_DAYS
        );

        vm.prank(alice);
        crowdfunding.contribute{value: 2 ether}(1);

        assertEq(crowdfunding.contributions(1, alice), 2 ether);

        (, , , , , uint256 amountRaised, ) = crowdfunding.getCampaign(1);
        assertEq(amountRaised, 2 ether);
        assertEq(address(crowdfunding).balance, 2 ether);
    }

    function test_RevertWhen_ContributingAfterDeadline() public {
        vm.prank(creator);
        crowdfunding.createCampaign(
            "Build Game",
            "Decentralized RPG",
            GOAL,
            DURATION_DAYS
        );

        vm.warp(block.timestamp + (DURATION_DAYS * 1 days) + 1);

        vm.prank(alice);
        vm.expectRevert("Campaign has ended");
        crowdfunding.contribute{value: 1 ether}(1);
    }

    function test_ClaimFundsSuccess() public {
        vm.prank(creator);
        crowdfunding.createCampaign(
            "Build Game",
            "Decentralized RPG",
            GOAL,
            DURATION_DAYS
        );

        vm.prank(alice);
        crowdfunding.contribute{value: 3 ether}(1);

        vm.prank(bob);
        crowdfunding.contribute{value: 2 ether}(1);

        vm.warp(block.timestamp + (DURATION_DAYS * 1 days) + 1);

        uint256 creatorBalanceBefore = creator.balance;

        vm.prank(creator);
        crowdfunding.claimFunds(1);

        assertEq(creator.balance, creatorBalanceBefore + 5 ether);
        assertEq(address(crowdfunding).balance, 0);

        (, , , , , , bool claimed) = crowdfunding.getCampaign(1);
        assertTrue(claimed);
    }

    function test_RevertWhen_NonCreatorClaimsFunds() public {
        vm.prank(creator);
        crowdfunding.createCampaign(
            "Build Game",
            "Decentralized RPG",
            GOAL,
            DURATION_DAYS
        );

        vm.prank(alice);
        crowdfunding.contribute{value: 5 ether}(1);

        vm.warp(block.timestamp + (DURATION_DAYS * 1 days) + 1);

        vm.prank(alice);
        vm.expectRevert("Only creator can claim");
        crowdfunding.claimFunds(1);
    }

    function test_ClaimRefundSuccess() public {
        vm.prank(creator);
        crowdfunding.createCampaign(
            "Build Game",
            "Decentralized RPG",
            GOAL,
            DURATION_DAYS
        );

        vm.prank(alice);
        crowdfunding.contribute{value: 2 ether}(1);

        vm.warp(block.timestamp + (DURATION_DAYS * 1 days) + 1);

        uint256 aliceBalanceBefore = alice.balance;

        vm.prank(alice);
        crowdfunding.claimRefund(1);

        assertEq(alice.balance, aliceBalanceBefore + 2 ether);
        assertEq(crowdfunding.contributions(1, alice), 0);
        assertEq(address(crowdfunding).balance, 0);
    }

    function test_RevertWhen_RefundClaimedTwice() public {
        vm.prank(creator);
        crowdfunding.createCampaign(
            "Build Game",
            "Decentralized RPG",
            GOAL,
            DURATION_DAYS
        );

        vm.prank(alice);
        crowdfunding.contribute{value: 2 ether}(1);

        vm.warp(block.timestamp + (DURATION_DAYS * 1 days) + 1);

        vm.prank(alice);
        crowdfunding.claimRefund(1);

        vm.prank(alice);
        vm.expectRevert("No funds to refund");
        crowdfunding.claimRefund(1);
    }
}
