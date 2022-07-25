// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {SetupEnvironment} from "./utils/utils.sol";
import {StakingZap} from "../contracts/StakingZap.sol";
import {VaultManager} from "../contracts/VaultManager.sol";
import {LPStaking} from "../contracts/LPStaking.sol";
import {FeeDistributor} from "../contracts/FeeDistributor.sol";
import {FNFTStaking} from "../contracts/FNFTStaking.sol";
import {IUniswapV2Router} from "../contracts/interfaces/IUniswapV2Router.sol";

contract StakingZapTest is DSTest, SetupEnvironment {
    IUniswapV2Router private router;
    FeeDistributor private feeDistributor;
    VaultManager private vaultManager;
    StakingZap private stakingZap;
    LPStaking private lpStaking;
    FNFTStaking private fnftStaking;

    function setUp() public {
        setupEnvironment(10 ether);
        (   ,
            lpStaking,
            ,
            ,
            ,
            feeDistributor,
            vaultManager,
            ,
            ,
            fnftStaking
        ) = setupContracts();
        router = setupRouter();
        stakingZap = new StakingZap(address(vaultManager), address(router));
        feeDistributor.setFNFTStakingAddress(address(fnftStaking));
    }

    function testAssignStakingContracts() public {
        assertEq(address(stakingZap.lpStaking()), address(0));
        assertEq(address(stakingZap.fnftStaking()), address(0));

        stakingZap.assignStakingContracts();

        assertEq(address(stakingZap.lpStaking()), address(lpStaking));
        assertEq(address(stakingZap.fnftStaking()), address(fnftStaking));
    }

    event LPLockTimeUpdated(uint256 oldLockTime, uint256 newLockTime);
    event InventoryLockTimeUpdated(uint256 oldLockTime, uint256 newLockTime);

    function testSetLPLockTime() public {
        vm.expectEmit(true, false, false, true);
        emit LPLockTimeUpdated(48 hours, 7 days);
        stakingZap.setLPLockTime(7 days);
    }

    function testSetInventoryLockTime() public {
        vm.expectEmit(true, false, false, true);
        emit InventoryLockTimeUpdated(7 days, 14 days);
        stakingZap.setInventoryLockTime(14 days);
    }
}