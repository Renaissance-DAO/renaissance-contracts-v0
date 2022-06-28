//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "../contracts/IFOFactory.sol";
import "../contracts/mocks/NFT.sol";
import {console, CheatCodes, SetupEnvironment} from "./utils/utils.sol";
import {Deployer} from "../contracts/proxy/Deployer.sol";


/// @author andy8052
/// @title Tests for the ifoFactory
contract IFOFactoryTest is DSTest, SetupEnvironment {
    IFOFactory public ifoFactory;

    function setUp() public {
        setupEnvironment(10 ether);
        (   ,
            ,
            ifoFactory,
            ,
            ,
            ,
            ,
            ,
            ,
        ) = setupContracts();
    }

    function test_setCreatorIFOLock() public {
        ifoFactory.setCreatorIFOLock(true);
        assertTrue(ifoFactory.creatorIFOLock());
    }

    function test_setMinimumDuration() public {
        ifoFactory.setMinimumDuration(0);
        assertEq(ifoFactory.minimumDuration(), 0);
    }

    function test_setMaximumDuration() public {
        ifoFactory.setMaximumDuration(86401);
        assertEq(ifoFactory.maximumDuration(), 86401);
    }

    function testInvalidMinimumDuration() public {
        ifoFactory.setMaximumDuration(86401);
        vm.expectRevert(IIFOFactory.InvalidDuration.selector);
        ifoFactory.setMinimumDuration(86402);
    }

    function testInvalidMaximumDuration() public {
        uint256 val = ifoFactory.minimumDuration() - 1;
        vm.expectRevert(IIFOFactory.InvalidDuration.selector);
        ifoFactory.setMaximumDuration(val);
    }

    function test_setCreatorUtilityContract() public {
        ifoFactory.setCreatorUtilityContract(address(1));
        assertEq(ifoFactory.creatorUtilityContract(), address(1));

        ifoFactory.setCreatorUtilityContract(address(0));
        assertEq(ifoFactory.creatorUtilityContract(), address(0));
    }

    function test_setGovernanceFee() public {
        ifoFactory.setGovernanceFee(1000);
        assertEq(ifoFactory.governanceFee(), 1000);
    }

    function testSetGovernanceFeeTooHigh() public {
        vm.expectRevert(IIFOFactory.FeeTooHigh.selector);
        ifoFactory.setGovernanceFee(1001);
    }

    function test_setFeeReceiver() public {
        ifoFactory.setFeeReceiver(payable(address(1)));
        assertEq(ifoFactory.feeReceiver(), payable(address(1)));
    }

    function testSetFeeReceiverZeroAddressDisallowed() public {
        vm.expectRevert(IIFOFactory.ZeroAddressDisallowed.selector);
        ifoFactory.setFeeReceiver(payable(address(0)));
    }
}
