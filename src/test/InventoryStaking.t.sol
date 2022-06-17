// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {InventoryStaking} from "../contracts/InventoryStaking.sol";
import {FNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";

/// @author 0xkowloon
/// @title Tests for inventory staking
contract InventoryStakingTest is DSTest, SetupEnvironment {
  FNFTCollectionFactory private factory;
  InventoryStaking private inventoryStaking;
  MockNFT public token;

  function setUp() public {
    setupEnvironment(10 ether);
    (
      ,
      ,
      ,
      factory,
      inventoryStaking
    ) = setupCollectionVaultContracts();

    token = new MockNFT();
  }

  function testStorageVariables() public {
    assertEq(address(inventoryStaking.fnftCollectionFactory()), address(factory));
    assertEq(address(inventoryStaking.timelockExcludeList()), address(0));
    assertEq(inventoryStaking.inventoryLockTimeErc20(), 0);
  }

  function testSetInventoryLockTimeErc20() public {
    inventoryStaking.setInventoryLockTimeErc20(14 days);
    assertEq(inventoryStaking.inventoryLockTimeErc20(), 14 days);
  }

  function testSetInventoryLockTimeErc20LockTooLong() public {
    vm.expectRevert(InventoryStaking.LockTooLong.selector);
    inventoryStaking.setInventoryLockTimeErc20(14 days + 1 seconds);
    assertEq(inventoryStaking.inventoryLockTimeErc20(), 0);
  }
}