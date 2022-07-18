// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {SimpleMockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {InventoryStaking, IInventoryStaking} from "../contracts/InventoryStaking.sol";
import {FNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
import {FNFTCollection} from "../contracts/FNFTCollection.sol";
import {XTokenUpgradeable} from "../contracts/token/XTokenUpgradeable.sol";
import {VaultManager} from "../contracts/VaultManager.sol";

/// @author 0xkowloon
/// @title Tests for inventory staking
contract InventoryStakingTest is DSTest, SetupEnvironment {
  FNFTCollection private vault;
  uint256 private vaultId = 0;
  VaultManager private vaultManager;
  FNFTCollectionFactory private fnftCollectionFactory;
  InventoryStaking private inventoryStaking;
  SimpleMockNFT private token;

  function setUp() public {
    setupEnvironment(10 ether);
    (   ,
        ,
        ,
        ,
        ,
        ,
        vaultManager,
        ,
        fnftCollectionFactory,
        inventoryStaking
    ) = setupContracts();

    token = new SimpleMockNFT();
  }

  function testStorageVariables() public {
    assertEq(address(inventoryStaking.vaultManager()), address(vaultManager));
    assertEq(address(inventoryStaking.timelockExcludeList()), address(0));
    assertEq(inventoryStaking.inventoryLockTimeErc20(), 0);
  }

  event InventoryLockTimeErc20Updated(uint256 oldInventoryLockTimeErc20, uint256 newInventoryLockTimeErc20);

  function testSetInventoryLockTimeErc20() public {
    vm.expectEmit(true, false, false, true);
    emit InventoryLockTimeErc20Updated(0, 14 days);
    inventoryStaking.setInventoryLockTimeErc20(14 days);
    assertEq(inventoryStaking.inventoryLockTimeErc20(), 14 days);
  }

  function testSetInventoryLockTimeErc20LockTooLong() public {
    vm.expectRevert(IInventoryStaking.LockTooLong.selector);
    inventoryStaking.setInventoryLockTimeErc20(14 days + 1 seconds);
    assertEq(inventoryStaking.inventoryLockTimeErc20(), 0);
  }

  event TimelockExcludeListUpdated(address oldTimelockExcludeList, address newTimelockExcludeList);

  function testSetTimelockExcludeList() public {
    vm.expectEmit(true, false, false, true);
    emit TimelockExcludeListUpdated(address(0), address(999));
    inventoryStaking.setTimelockExcludeList(address(999));
    assertEq(address(inventoryStaking.timelockExcludeList()), address(999));
  }

  function testDeployXTokenForVault() public {
    mintVaultTokens(1);

    vm.expectRevert(IInventoryStaking.XTokenNotDeployed.selector);
    inventoryStaking.vaultXToken(vaultId);
    inventoryStaking.deployXTokenForVault(vaultId);
    // contract deployed, does not throw an error
    inventoryStaking.vaultXToken(vaultId);
  }

  function testDeposit() public {
    mintVaultTokens(2);

    inventoryStaking.deployXTokenForVault(vaultId);
    inventoryStaking.setInventoryLockTimeErc20(10 seconds);
    vault.approve(address(inventoryStaking), 1 ether);
    inventoryStaking.deposit(vaultId, 1 ether);

    assertEq(vault.balanceOf(address(this)), 0.8 ether);

    address xTokenAddress = inventoryStaking.vaultXToken(vaultId);
    XTokenUpgradeable xToken = XTokenUpgradeable(xTokenAddress);
    assertEq(xToken.balanceOf(address(this)), 1 ether);
    assertEq(xToken.timelockUntil(address(this)), block.timestamp + 10 seconds);

    vault.transfer(address(1), 0.5 ether);
    vm.startPrank(address(1));
    vault.approve(address(inventoryStaking), 0.5 ether);
    inventoryStaking.deposit(vaultId, 0.5 ether);
    vm.stopPrank();
    assertEq(xToken.balanceOf(address(1)), 0.5 ether);
    assertEq(xToken.timelockUntil(address(1)), block.timestamp + 10 seconds);
  }

  function testTimelockMintFor() public {
    mintVaultTokens(1);

    inventoryStaking.deployXTokenForVault(vaultId);
    vaultManager.setZapContract(address(123));
    vaultManager.setFeeExclusion(address(123), true);
    vm.prank(address(123));
    inventoryStaking.timelockMintFor(vaultId, 123 ether, address(this), 3 seconds);

    // Nothing is taken from the account
    assertEq(vault.balanceOf(address(this)), 0.9 ether);

    address xTokenAddress = inventoryStaking.vaultXToken(vaultId);
    XTokenUpgradeable xToken = XTokenUpgradeable(xTokenAddress);
    assertEq(xToken.balanceOf(address(this)), 123 ether);
    assertEq(xToken.timelockUntil(address(this)), block.timestamp + 3 seconds);
  }

  function testTimelockMintForNotZapContract() public {
    mintVaultTokens(1);

    inventoryStaking.deployXTokenForVault(vaultId);
    vm.expectRevert(IInventoryStaking.NotZapContract.selector);
    inventoryStaking.timelockMintFor(vaultId, 123 ether, address(this), 3 seconds);
  }

  function testTimelockMintForNotExcludedFromFees() public {
    mintVaultTokens(1);

    inventoryStaking.deployXTokenForVault(vaultId);
    vaultManager.setZapContract(address(123));
    vm.prank(address(123));
    vm.expectRevert(IInventoryStaking.NotExcludedFromFees.selector);
    inventoryStaking.timelockMintFor(vaultId, 123 ether, address(this), 3 seconds);
  }

  function testReceiveRewardsAndWithdraw() public {
    mintVaultTokens(2);

    inventoryStaking.deployXTokenForVault(vaultId);

    vault.transfer(address(1), 1 ether);
    vm.startPrank(address(1));
    vault.approve(address(inventoryStaking), 1 ether);
    inventoryStaking.deposit(vaultId, 1 ether);
    vm.stopPrank();

    vault.transfer(address(2), 0.5 ether);
    vm.startPrank(address(2));
    vault.approve(address(inventoryStaking), 0.5 ether);
    inventoryStaking.deposit(vaultId, 0.5 ether);
    vm.stopPrank();

    address xTokenAddress = inventoryStaking.vaultXToken(vaultId);
    XTokenUpgradeable xToken = XTokenUpgradeable(xTokenAddress);

    assertEq(inventoryStaking.xTokenShareValue(vaultId), 1 ether);

    vault.approve(address(inventoryStaking), 0.3 ether);
    inventoryStaking.receiveRewards(vaultId, 0.3 ether);

    assertEq(inventoryStaking.xTokenShareValue(vaultId), 1.2 ether);

    vm.warp(block.timestamp + 1 seconds);

    vm.prank(address(1));
    inventoryStaking.withdraw(vaultId, 1 ether);
    assertEq(xToken.balanceOf(address(1)), 0);
    assertEq(vault.balanceOf(address(1)), 1.2 ether);

    vm.prank(address(2));
    inventoryStaking.withdraw(vaultId, 0.5 ether);
    assertEq(xToken.balanceOf(address(2)), 0);
    assertEq(vault.balanceOf(address(2)), 0.6 ether);
  }

  function testVaultXTokenNotDeployed() public {
    mintVaultTokens(1);
    vm.expectRevert(IInventoryStaking.XTokenNotDeployed.selector);
    inventoryStaking.vaultXToken(vaultId);
  }

  function testXTokenShareValueXTokenNotDeployed() public {
    mintVaultTokens(1);
    vm.expectRevert(IInventoryStaking.XTokenNotDeployed.selector);
    inventoryStaking.xTokenShareValue(vaultId);
  }

  // NOTE: xTokenShareValue totalSupply > 0 scenarios tested above.
  function testXTokenShareValueZeroTotalSupply() public {
    mintVaultTokens(1);
    inventoryStaking.deployXTokenForVault(vaultId);
    assertEq(inventoryStaking.xTokenShareValue(vaultId), 1e18);
  }

  function testXTokenAddr() public {
    mintVaultTokens(1);
    // the address before and after deploy are the same
    address xTokenAddress = inventoryStaking.xTokenAddr(address(vault));
    inventoryStaking.deployXTokenForVault(vaultId);
    assertEq(inventoryStaking.xTokenAddr(address(vault)), xTokenAddress);
  }

  function testXTokenStorageVariables() public {
    mintVaultTokens(1);
    inventoryStaking.deployXTokenForVault(vaultId);
    XTokenUpgradeable xToken = XTokenUpgradeable(inventoryStaking.vaultXToken(vaultId));
    assertEq(address(xToken.baseToken()), address(vault));
    assertEq(xToken.name(), "xDOODLE");
    assertEq(xToken.symbol(), "xDOODLE");
  }

  function createVault() private {
    fnftCollectionFactory.createVault(address(token), false, true, "Doodles", "DOODLE");
    vault = FNFTCollection(vaultManager.vault(vaultId));
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