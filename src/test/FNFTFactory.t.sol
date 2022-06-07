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
        (, , , , fnftFactory, ) = setupContracts(10 ether);

        token = new MockNFT();
        token2 = new MockNFT();
    }

    function test_setMaxAuction() public {
        fnftFactory.setMaxAuctionLength(4 weeks);
        assertEq(fnftFactory.maxAuctionLength(), 4 weeks);
    }

    function testSetMaxAuctionLengthTooHigh() public {
        vm.expectRevert(FNFTFactory.MaxAuctionLengthTooHigh.selector);
        fnftFactory.setMaxAuctionLength(10 weeks);
    }

    function testSetMaxAuctionLengthTooLow() public {
        vm.expectRevert(fnftFactory.MaxAuctionLengthTooLow.selector);
        fnftFactory.setMaxAuctionLength(2.9 days);
    }

    function test_setMinAuction() public {
        fnftFactory.setMinAuctionLength(1 weeks);
    }

    function testSetMinAuctionLengthTooLow() public {
        vm.expectRevert(fnftFactory.MinAuctionLengthTooLow.selector);
        fnftFactory.setMinAuctionLength(0.1 days);
    }

    function testSetMinAuctionLengthTooHigh() public {
        vm.expectRevert(fnftFactory.MinAuctionLengthTooHigh.selector);
        fnftFactory.setMinAuctionLength(5 weeks);
    }

    function test_setGovernanceFee() public {
        fnftFactory.setGovernanceFee(1000);
    }

    // too high
    function testSetGovernanceFeeTooHigh() public {
        vm.expectRevert(fnftFactory.GovFeeTooHigh.selector);
        fnftFactory.setGovernanceFee(1001);
    }

    function test_setMinBidIncrease() public {
        fnftFactory.setMinBidIncrease(750);
    }

    // too high
    function testSetMinBidIncreaseTooHigh() public {
        vm.expectRevert(fnftFactory.MinBidIncreaseTooHigh.selector);
        fnftFactory.setMinBidIncrease(1100);
    }

    // too low
    function testSetMinBidIncreaseTooLow() public {
        vm.expectRevert(fnftFactory.MinBidIncreaseTooLow.selector);
        fnftFactory.setMinBidIncrease(50);
    }

    function test_setMaxReserveFactor() public {
        fnftFactory.setMaxReserveFactor(100000);
    }

    function testSetMaxReserveFactorTooLow() public {
        vm.expectRevert(fnftFactory.MaxReserveFactorTooLow.selector);
        fnftFactory.setMaxReserveFactor(2000);
    }

    function test_setMinReserveFactor() public {
        fnftFactory.setMinReserveFactor(4000);
    }

    function testSetMaxReserveFactorTooHigh() public {
        vm.expectRevert(fnftFactory.MinReserveFactorTooHigh.selector);
        fnftFactory.setMinReserveFactor(60000);
    }

    function test_setFeeReceiver() public {
        fnftFactory.setFeeReceiver(payable(address(this)));
    }
}
