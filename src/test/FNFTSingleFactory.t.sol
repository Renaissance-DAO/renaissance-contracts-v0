//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import {IFNFTSingleFactory} from "../contracts/FNFTSingleFactory.sol";
import "../contracts/mocks/NFT.sol";
import {console, CheatCodes, SetupEnvironment} from "./utils/utils.sol";


/// @title Tests for the fnftSingleFactory
contract FNFTSingleFactoryTest is DSTest, SetupEnvironment {
    IFNFTSingleFactory public fnftSingleFactory;
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

    function testSetMaxAuction() public {
        fnftSingleFactory.setAuctionLength(IFNFTSingleFactory.Boundary.Max, 4 weeks);
        assertEq(fnftSingleFactory.maxAuctionLength(), 4 weeks);
    }

    function testSetMaxAuctionLengthTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.MaxAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setAuctionLength(IFNFTSingleFactory.Boundary.Max, 10 weeks);
    }

    function testSetMaxAuctionLengthTooLow() public {
        vm.expectRevert(IFNFTSingleFactory.MaxAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setAuctionLength(IFNFTSingleFactory.Boundary.Max, 2.9 days);
    }

    function testSetMinAuction() public {
        fnftSingleFactory.setAuctionLength(IFNFTSingleFactory.Boundary.Min, 1 weeks);
    }

    function testSetMinAuctionLengthTooLow() public {
        vm.expectRevert(IFNFTSingleFactory.MinAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setAuctionLength(IFNFTSingleFactory.Boundary.Min, 0.1 days);
    }

    function testSetMinAuctionLengthTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.MinAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setAuctionLength(IFNFTSingleFactory.Boundary.Min, 5 weeks);
    }

    function testSetGovernanceFee() public {
        fnftSingleFactory.setFee(IFNFTSingleFactory.FeeType.GovernanceFee, 1000);
    }

    // too high
    function testSetGovernanceFeeTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.FeeTooHigh.selector);
        fnftSingleFactory.setFee(IFNFTSingleFactory.FeeType.GovernanceFee, 1001);
    }

    function testSetMinBidIncrease() public {
        fnftSingleFactory.setMinBidIncrease(750);
    }

    // too high
    function testSetMinBidIncreaseTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.MinBidIncreaseOutOfBounds.selector);
        fnftSingleFactory.setMinBidIncrease(1100);
    }

    // too low
    function testSetMinBidIncreaseTooLow() public {
        vm.expectRevert(IFNFTSingleFactory.MinBidIncreaseOutOfBounds.selector);
        fnftSingleFactory.setMinBidIncrease(50);
    }

    function testSetMaxReserveFactor() public {
        fnftSingleFactory.setReserveFactor(IFNFTSingleFactory.Boundary.Max, 100000);
    }

    function testSetMaxReserveFactorTooLow() public {
        vm.expectRevert(IFNFTSingleFactory.MaxReserveFactorTooLow.selector);
        fnftSingleFactory.setReserveFactor(IFNFTSingleFactory.Boundary.Max, 2000);
    }

    function testSetMinReserveFactor() public {
        fnftSingleFactory.setReserveFactor(IFNFTSingleFactory.Boundary.Min, 4000);
    }

    function testSetMaxReserveFactorTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.MinReserveFactorTooHigh.selector);
        fnftSingleFactory.setReserveFactor(IFNFTSingleFactory.Boundary.Min, 60000);
    }

    function testSetFlashLoanFeeTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.FeeTooHigh.selector);
        fnftSingleFactory.setFlashLoanFee(501);
    }

    function testSetFlashLoanFeeNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(1));
        fnftSingleFactory.setFlashLoanFee(499);
    }
}
