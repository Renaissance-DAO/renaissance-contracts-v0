//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "../contracts/FNFTSingleFactory.sol";
import "../contracts/mocks/NFT.sol";
import {console, CheatCodes, SetupEnvironment} from "./utils/utils.sol";


/// @title Tests for the fnftSingleFactory
contract FNFTSingleFactoryTest is DSTest, SetupEnvironment {
    FNFTSingleFactory public fnftSingleFactory;
    MockNFT public token;
    MockNFT public token2;

    function setUp() public {
        setupEnvironment(10 ether);
        (   ,
            ,
            ,
            ,
            ,
            ,
            ,
            fnftSingleFactory,
            ,
        ) = setupContracts();

        token = new MockNFT();
        token2 = new MockNFT();
    }

    function test_setMaxAuction() public {
        fnftSingleFactory.setAuctionLength(FNFTSingleFactory.Boundary.Max, 4 weeks);
        assertEq(fnftSingleFactory.maxAuctionLength(), 4 weeks);
    }

    function testSetMaxAuctionLengthTooHigh() public {
        vm.expectRevert(FNFTSingleFactory.MaxAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setAuctionLength(FNFTSingleFactory.Boundary.Max, 10 weeks);
    }

    function testSetMaxAuctionLengthTooLow() public {
        vm.expectRevert(FNFTSingleFactory.MaxAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setAuctionLength(FNFTSingleFactory.Boundary.Max, 2.9 days);
    }

    function test_setMinAuction() public {
        fnftSingleFactory.setAuctionLength(FNFTSingleFactory.Boundary.Min, 1 weeks);
    }

    function testSetMinAuctionLengthTooLow() public {
        vm.expectRevert(FNFTSingleFactory.MinAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setAuctionLength(FNFTSingleFactory.Boundary.Min, 0.1 days);
    }

    function testSetMinAuctionLengthTooHigh() public {
        vm.expectRevert(FNFTSingleFactory.MinAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setAuctionLength(FNFTSingleFactory.Boundary.Min, 5 weeks);
    }

    function test_setGovernanceFee() public {
        fnftSingleFactory.setFee(FNFTSingleFactory.FeeType.GovernanceFee, 1000);
    }

    // too high
    function testSetGovernanceFeeTooHigh() public {
        vm.expectRevert(FNFTSingleFactory.FeeTooHigh.selector);
        fnftSingleFactory.setFee(FNFTSingleFactory.FeeType.GovernanceFee, 1001);
    }

    function test_setMinBidIncrease() public {
        fnftSingleFactory.setMinBidIncrease(750);
    }

    // too high
    function testSetMinBidIncreaseTooHigh() public {
        vm.expectRevert(FNFTSingleFactory.MinBidIncreaseOutOfBounds.selector);
        fnftSingleFactory.setMinBidIncrease(1100);
    }

    // too low
    function testSetMinBidIncreaseTooLow() public {
        vm.expectRevert(FNFTSingleFactory.MinBidIncreaseOutOfBounds.selector);
        fnftSingleFactory.setMinBidIncrease(50);
    }

    function test_setMaxReserveFactor() public {
        fnftSingleFactory.setReserveFactor(FNFTSingleFactory.Boundary.Max, 100000);
    }

    function testSetMaxReserveFactorTooLow() public {
        vm.expectRevert(FNFTSingleFactory.MaxReserveFactorTooLow.selector);
        fnftSingleFactory.setReserveFactor(FNFTSingleFactory.Boundary.Max, 2000);
    }

    function test_setMinReserveFactor() public {
        fnftSingleFactory.setReserveFactor(FNFTSingleFactory.Boundary.Min, 4000);
    }

    function testSetMaxReserveFactorTooHigh() public {
        vm.expectRevert(FNFTSingleFactory.MinReserveFactorTooHigh.selector);
        fnftSingleFactory.setReserveFactor(FNFTSingleFactory.Boundary.Min, 60000);
    }

    function testSetFlashLoanFeeTooHigh() public {
        vm.expectRevert(FNFTSingleFactory.FeeTooHigh.selector);
        fnftSingleFactory.setFlashLoanFee(501);
    }

    function testSetFlashLoanFeeNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(1));
        fnftSingleFactory.setFlashLoanFee(499);
    }
}
