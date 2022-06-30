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
        fnftSingleFactory.setFactoryThresholds(4 weeks, 3 days, 2000, 50000, 500, 2500, 30e18, 15);
        assertEq(fnftSingleFactory.maxAuctionLength(), 4 weeks);
    }

    function testSetMaxAuctionLengthTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.MaxAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setFactoryThresholds(10 weeks, 3 days, 2000, 50000, 500, 2500, 30e18, 15);
    }

    function testSetMaxAuctionLengthTooLow() public {
        vm.expectRevert(IFNFTSingleFactory.MaxAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setFactoryThresholds(2.9 days, 3 days, 2000, 50000, 500, 2500, 30e18, 15);
    }

    function testSetInstantBuyMultiplierTooLow() public {
        vm.expectRevert(IFNFTSingleFactory.MultiplierTooLow.selector);
        fnftSingleFactory.setFactoryThresholds(4 weeks, 3 days, 2000, 50000, 500, 2500, 30e18, 9);
    }

    function testSetMinAuction() public {
        fnftSingleFactory.setFactoryThresholds(2 weeks, 1 weeks, 2000, 50000, 500, 2500, 30e18, 15);
    }

    function testSetMinAuctionLengthTooLow() public {
        vm.expectRevert(IFNFTSingleFactory.MinAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setFactoryThresholds(2 weeks, 0.1 days, 2000, 50000, 500, 2500, 30e18, 15);
    }

    function testSetMinAuctionLengthTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.MinAuctionLengthOutOfBounds.selector);
        fnftSingleFactory.setFactoryThresholds(2 weeks, 5 weeks, 2000, 50000, 500, 2500, 30e18, 15);
    }

    function testSetFactoryFees() public {
        fnftSingleFactory.setFactoryFees(1000, 1000, 500, 500);
    }

    // too high
    function testSetGovernanceFeeTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.FeeTooHigh.selector);
        fnftSingleFactory.setFactoryFees(1001, 1000, 500, 500);
    }

    function testSetMinBidIncrease() public {
        fnftSingleFactory.setFactoryThresholds(2 weeks, 3 days, 2000, 50000, 750, 2500, 30e18, 15);
    }

    // too high
    function testSetMinBidIncreaseTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.MinBidIncreaseOutOfBounds.selector);
        fnftSingleFactory.setFactoryThresholds(2 weeks, 3 days, 2000, 50000, 1100, 2500, 30e18, 15);
    }

    // too low
    function testSetMinBidIncreaseTooLow() public {
        vm.expectRevert(IFNFTSingleFactory.MinBidIncreaseOutOfBounds.selector);
        fnftSingleFactory.setFactoryThresholds(2 weeks, 3 days, 2000, 50000, 50, 2500, 30e18, 15);
    }

    function testSetMaxReserveFactor() public {
        fnftSingleFactory.setFactoryThresholds(2 weeks, 3 days, 2000, 100000, 500, 2500, 30e18, 15);
    }

    function testSetMaxReserveFactorTooLow() public {
        vm.expectRevert(IFNFTSingleFactory.MaxReserveFactorTooLow.selector);
        fnftSingleFactory.setFactoryThresholds(2 weeks, 3 days, 2000, 2000, 500, 2500, 30e18, 15);
    }

    function testSetMinReserveFactor() public {
        fnftSingleFactory.setFactoryThresholds(2 weeks, 3 days, 4000, 50000, 500, 2500, 30e18, 15);
    }

    function testSetMaxReserveFactorTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.MinReserveFactorTooHigh.selector);
        fnftSingleFactory.setFactoryThresholds(2 weeks, 3 days, 60000, 50000, 500, 2500, 30e18, 15);
    }

    function testSetFlashLoanFeeTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.FeeTooHigh.selector);
        fnftSingleFactory.setFactoryFees(1000, 1000, 501, 500);
    }

    function testSetMaxCuratorFeeTooHigh() public {
        vm.expectRevert(IFNFTSingleFactory.FeeTooHigh.selector);
        fnftSingleFactory.setFactoryFees(1000, 2001, 501, 500);
    }

    function testSetFactoryFeesNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(1));
        fnftSingleFactory.setFactoryFees(1000, 1000, 500, 500);
    }
}
