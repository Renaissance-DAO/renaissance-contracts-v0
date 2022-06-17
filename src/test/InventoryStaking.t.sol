// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {InventoryStaking} from "../contracts/InventoryStaking.sol";
import {FNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
import {FNFTCollection} from "../contracts/FNFTCollection.sol";

/// @author 0xkowloon
/// @title Tests for inventory staking
contract InventoryStakingTest is DSTest, SetupEnvironment {
  FNFTCollection private vault;
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

  function testDeployXTokenForVault() public {
    mintVaultTokens(1);

    vm.expectRevert(InventoryStaking.XTokenNotDeployed.selector);
    inventoryStaking.vaultXToken(0);
    inventoryStaking.deployXTokenForVault(0);
    // contract deployed, does not throw an error
    inventoryStaking.vaultXToken(0);
  }

  // TODO: merge with FNFTCollectionTest.t.sol
  function createVault() private {
    factory.createVault("Doodles", "DOODLE", address(token), false, true);
    vault = FNFTCollection(factory.vault(0));
  }

  function mintVaultTokens(uint256 numberOfTokens) private {
    createVault();

    uint256[] memory tokenIds = new uint256[](numberOfTokens);

    for (uint i; i < numberOfTokens; i++) {
      token.mint(address(this), i + 1);
      tokenIds[i] = i + 1;
    }

    token.setApprovalForAll(address(vault), true);

    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);
  }
}