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

    function testSetCreatorIFOLock() public {
        ifoFactory.setCreatorIFOLock(true);
        assertTrue(ifoFactory.creatorIFOLock());
    }

    function testSetMinimumDuration() public {
        ifoFactory.setMinimumDuration(0);
        assertEq(ifoFactory.minimumDuration(), 0);
    }

    function testSetMaximumDuration() public {
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

    function testSetCreatorUtilityContract() public {
        ifoFactory.setCreatorUtilityContract(address(1));
        assertEq(ifoFactory.creatorUtilityContract(), address(1));

        ifoFactory.setCreatorUtilityContract(address(0));
        assertEq(ifoFactory.creatorUtilityContract(), address(0));
    }

    function testSetGovernanceFee() public {
        ifoFactory.setGovernanceFee(1000);
        assertEq(ifoFactory.governanceFee(), 1000);
    }

    function testSetGovernanceFeeTooHigh() public {
        vm.expectRevert(IIFOFactory.FeeTooHigh.selector);
        ifoFactory.setGovernanceFee(1001);
    }

    function testSetFeeReceiver() public {
        ifoFactory.setFeeReceiver(payable(address(1)));
        assertEq(ifoFactory.feeReceiver(), payable(address(1)));
    }

    function testSetFeeReceiverZeroAddress() public {
        vm.expectRevert(IIFOFactory.ZeroAddress.selector);
        ifoFactory.setFeeReceiver(payable(address(0)));
    }
}
