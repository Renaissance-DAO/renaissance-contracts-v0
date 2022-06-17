// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {InventoryStaking} from "../contracts/InventoryStaking.sol";
import {FNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
import {FNFTCollection} from "../contracts/FNFTCollection.sol";
import {XTokenUpgradeable} from "../contracts/token/XTokenUpgradeable.sol";

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

  function testDeposit() public {
    mintVaultTokens(2);

    inventoryStaking.deployXTokenForVault(0);
    inventoryStaking.setInventoryLockTimeErc20(10 seconds);
    vault.approve(address(inventoryStaking), 1 ether);
    inventoryStaking.deposit(0, 1 ether);

    assertEq(vault.balanceOf(address(this)), 0.8 ether);

    address xTokenAddress = inventoryStaking.vaultXToken(0);
    XTokenUpgradeable xToken = XTokenUpgradeable(xTokenAddress);
    assertEq(xToken.balanceOf(address(this)), 1 ether);
    assertEq(xToken.timelockUntil(address(this)), block.timestamp + 10 seconds);

    vault.transfer(address(1), 0.5 ether);
    vm.startPrank(address(1));
    vault.approve(address(inventoryStaking), 0.5 ether);
    inventoryStaking.deposit(0, 0.5 ether);
    vm.stopPrank();
    assertEq(xToken.balanceOf(address(1)), 0.5 ether);
    assertEq(xToken.timelockUntil(address(1)), block.timestamp + 10 seconds);
  }

  function testTimelockMintFor() public {
    mintVaultTokens(1);

    inventoryStaking.deployXTokenForVault(0);
    factory.setZapContract(address(123));
    factory.setFeeExclusion(address(123), true);
    vm.prank(address(123));
    inventoryStaking.timelockMintFor(0, 123 ether, address(this), 3 seconds);

    // Nothing is taken from the account
    assertEq(vault.balanceOf(address(this)), 0.9 ether);

    address xTokenAddress = inventoryStaking.vaultXToken(0);
    XTokenUpgradeable xToken = XTokenUpgradeable(xTokenAddress);
    assertEq(xToken.balanceOf(address(this)), 123 ether);
    assertEq(xToken.timelockUntil(address(this)), block.timestamp + 3 seconds);
  }

  function testTimelockMintForNotZapContract() public {
    mintVaultTokens(1);

    inventoryStaking.deployXTokenForVault(0);
    vm.expectRevert(InventoryStaking.NotZapContract.selector);
    inventoryStaking.timelockMintFor(0, 123 ether, address(this), 3 seconds);
  }

  function testTimelockMintForNotExcludedFromFees() public {
    mintVaultTokens(1);

    inventoryStaking.deployXTokenForVault(0);
    factory.setZapContract(address(123));
    vm.prank(address(123));
    vm.expectRevert(InventoryStaking.NotExcludedFromFees.selector);
    inventoryStaking.timelockMintFor(0, 123 ether, address(this), 3 seconds);
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