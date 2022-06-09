//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "../contracts/FNFTFactory.sol";
import "../contracts/mocks/NFT.sol";
import {console, CheatCodes, SetupEnvironment} from "./utils/utils.sol";


/// @title Tests for the fnftFactory
contract FNFTFactoryTest is DSTest, SetupEnvironment {
    FNFTFactory public fnftFactory;
    MockNFT public token;
    MockNFT public token2;    

    function setUp() public {
        setupEnvironment(10 ether);
        (, , , fnftFactory, ) = setupContracts(10 ether);

        token = new MockNFT();
        token2 = new MockNFT();
    }

    function test_setMaxAuction() public {
        fnftFactory.setAuctionLength(FNFTFactory.Boundary.Max, 4 weeks);
        assertEq(fnftFactory.maxAuctionLength(), 4 weeks);
    }

    function testSetMaxAuctionLengthTooHigh() public {
        vm.expectRevert(FNFTFactory.MaxAuctionLengthOutOfBounds.selector);
        fnftFactory.setAuctionLength(FNFTFactory.Boundary.Max, 10 weeks);
    }

    function testSetMaxAuctionLengthTooLow() public {
        vm.expectRevert(FNFTFactory.MaxAuctionLengthOutOfBounds.selector);
        fnftFactory.setAuctionLength(FNFTFactory.Boundary.Max, 2.9 days);
    }

    function test_setMinAuction() public {
        fnftFactory.setAuctionLength(FNFTFactory.Boundary.Min, 1 weeks);
    }

    function testSetMinAuctionLengthTooLow() public {
        vm.expectRevert(FNFTFactory.MinAuctionLengthOutOfBounds.selector);
        fnftFactory.setAuctionLength(FNFTFactory.Boundary.Min, 0.1 days);
    }

    function testSetMinAuctionLengthTooHigh() public {
        vm.expectRevert(FNFTFactory.MinAuctionLengthOutOfBounds.selector);
        fnftFactory.setAuctionLength(FNFTFactory.Boundary.Min, 5 weeks);
    }

    function test_setGovernanceFee() public {
        fnftFactory.setFee(FNFTFactory.FeeType.GovernanceFee, 1000);
    }

    // too high
    function testSetGovernanceFeeTooHigh() public {
        vm.expectRevert(FNFTFactory.GovFeeTooHigh.selector);
        fnftFactory.setFee(FNFTFactory.FeeType.GovernanceFee, 1001);
    }

    function test_setMinBidIncrease() public {
        fnftFactory.setMinBidIncrease(750);
    }

    // too high
    function testSetMinBidIncreaseTooHigh() public {
        vm.expectRevert(FNFTFactory.MinBidIncreaseOutOfBounds.selector);
        fnftFactory.setMinBidIncrease(1100);
    }

    // too low
    function testSetMinBidIncreaseTooLow() public {
        vm.expectRevert(FNFTFactory.MinBidIncreaseOutOfBounds.selector);
        fnftFactory.setMinBidIncrease(50);
    }

    function test_setMaxReserveFactor() public {
        fnftFactory.setReserveFactor(FNFTFactory.Boundary.Max, 100000);
    }

    function testSetMaxReserveFactorTooLow() public {
        vm.expectRevert(FNFTFactory.MaxReserveFactorTooLow.selector);
        fnftFactory.setReserveFactor(FNFTFactory.Boundary.Max, 2000);
    }

    function test_setMinReserveFactor() public {
        fnftFactory.setReserveFactor(FNFTFactory.Boundary.Min, 4000);
    }

    function testSetMaxReserveFactorTooHigh() public {
        vm.expectRevert(FNFTFactory.MinReserveFactorTooHigh.selector);
        fnftFactory.setReserveFactor(FNFTFactory.Boundary.Min, 60000);
    }

    function test_setFeeReceiver() public {
        fnftFactory.setFeeReceiver(payable(address(this)));
    }
}
