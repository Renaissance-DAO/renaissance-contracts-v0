// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {SimpleMockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {FNFTStaking, IFNFTStaking} from "../contracts/FNFTStaking.sol";
import {FNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
import {FNFTCollection} from "../contracts/FNFTCollection.sol";
import {FNFTStakingXTokenUpgradeable} from "../contracts/token/FNFTStakingXTokenUpgradeable.sol";
import {VaultManager} from "../contracts/VaultManager.sol";

/// @author 0xkowloon
/// @title Tests for inventory staking
contract FNFTStakingTest is DSTest, SetupEnvironment {
  FNFTCollection private vault;
  uint256 private vaultId = 0;
  VaultManager private vaultManager;
  FNFTCollectionFactory private fnftCollectionFactory;
  FNFTStaking private fnftStaking;
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
        fnftStaking
    ) = setupContracts();

    token = new SimpleMockNFT();
  }

  function testStorageVariables() public {
    assertEq(address(fnftStaking.vaultManager()), address(vaultManager));
    assertEq(address(fnftStaking.timelockExcludeList()), address(0));
    assertEq(fnftStaking.inventoryLockTimeErc20(), 0);
  }

  event InventoryLockTimeErc20Updated(uint256 oldInventoryLockTimeErc20, uint256 newInventoryLockTimeErc20);

  function testSetInventoryLockTimeErc20() public {
    vm.expectEmit(true, false, false, true);
    emit InventoryLockTimeErc20Updated(0, 14 days);
    fnftStaking.setInventoryLockTimeErc20(14 days);
    assertEq(fnftStaking.inventoryLockTimeErc20(), 14 days);
  }

  function testSetInventoryLockTimeErc20LockTooLong() public {
    vm.expectRevert(IFNFTStaking.LockTooLong.selector);
    fnftStaking.setInventoryLockTimeErc20(14 days + 1 seconds);
    assertEq(fnftStaking.inventoryLockTimeErc20(), 0);
  }

  event TimelockExcludeListUpdated(address oldTimelockExcludeList, address newTimelockExcludeList);

  function testSetTimelockExcludeList() public {
    vm.expectEmit(true, false, false, true);
    emit TimelockExcludeListUpdated(address(0), address(999));
    fnftStaking.setTimelockExcludeList(address(999));
    assertEq(address(fnftStaking.timelockExcludeList()), address(999));
  }

  function testDeployXTokenForVault() public {
    mintVaultTokens(1);

    vm.expectRevert(IFNFTStaking.XTokenNotDeployed.selector);
    fnftStaking.vaultXToken(vaultId);
    fnftStaking.deployXTokenForVault(vaultId);
    // contract deployed, does not throw an error
    fnftStaking.vaultXToken(vaultId);
  }

  function testDeposit() public {
    mintVaultTokens(2);

    fnftStaking.deployXTokenForVault(vaultId);
    fnftStaking.setInventoryLockTimeErc20(10 seconds);
    vault.approve(address(fnftStaking), 1 ether);
    fnftStaking.deposit(vaultId, 1 ether);

    assertEq(vault.balanceOf(address(this)), 0.8 ether);

    address xTokenAddress = fnftStaking.vaultXToken(vaultId);
    FNFTStakingXTokenUpgradeable xToken = FNFTStakingXTokenUpgradeable(xTokenAddress);
    assertEq(xToken.balanceOf(address(this)), 1 ether);
    assertEq(xToken.timelockUntil(address(this)), block.timestamp + 10 seconds);

    vault.transfer(address(1), 0.5 ether);
    vm.startPrank(address(1));
    vault.approve(address(fnftStaking), 0.5 ether);
    fnftStaking.deposit(vaultId, 0.5 ether);
    vm.stopPrank();
    assertEq(xToken.balanceOf(address(1)), 0.5 ether);
    assertEq(xToken.timelockUntil(address(1)), block.timestamp + 10 seconds);
  }

  function testTimelockMintFor() public {
    mintVaultTokens(1);

    fnftStaking.deployXTokenForVault(vaultId);
    vaultManager.setZapContract(address(123));
    vaultManager.setFeeExclusion(address(123), true);
    vm.prank(address(123));
    fnftStaking.timelockMintFor(vaultId, 123 ether, address(this), 3 seconds);

    // Nothing is taken from the account
    assertEq(vault.balanceOf(address(this)), 0.9 ether);

    address xTokenAddress = fnftStaking.vaultXToken(vaultId);
    FNFTStakingXTokenUpgradeable xToken = FNFTStakingXTokenUpgradeable(xTokenAddress);
    assertEq(xToken.balanceOf(address(this)), 123 ether);
    assertEq(xToken.timelockUntil(address(this)), block.timestamp + 3 seconds);
  }

  function testTimelockMintForNotZapContract() public {
    mintVaultTokens(1);

    fnftStaking.deployXTokenForVault(vaultId);
    vm.expectRevert(IFNFTStaking.NotZapContract.selector);
    fnftStaking.timelockMintFor(vaultId, 123 ether, address(this), 3 seconds);
  }

  function testTimelockMintForNotExcludedFromFees() public {
    mintVaultTokens(1);

    fnftStaking.deployXTokenForVault(vaultId);
    vaultManager.setZapContract(address(123));
    vm.prank(address(123));
    vm.expectRevert(IFNFTStaking.NotExcludedFromFees.selector);
    fnftStaking.timelockMintFor(vaultId, 123 ether, address(this), 3 seconds);
  }

  function testReceiveRewardsAndWithdraw() public {
    mintVaultTokens(2);

    fnftStaking.deployXTokenForVault(vaultId);

    vault.transfer(address(1), 1 ether);
    vm.startPrank(address(1));
    vault.approve(address(fnftStaking), 1 ether);
    fnftStaking.deposit(vaultId, 1 ether);
    vm.stopPrank();

    vault.transfer(address(2), 0.5 ether);
    vm.startPrank(address(2));
    vault.approve(address(fnftStaking), 0.5 ether);
    fnftStaking.deposit(vaultId, 0.5 ether);
    vm.stopPrank();

    address xTokenAddress = fnftStaking.vaultXToken(vaultId);
    FNFTStakingXTokenUpgradeable xToken = FNFTStakingXTokenUpgradeable(xTokenAddress);

    assertEq(fnftStaking.xTokenShareValue(vaultId), 1 ether);

    vault.approve(address(fnftStaking), 0.3 ether);
    fnftStaking.receiveRewards(vaultId, 0.3 ether);

    assertEq(fnftStaking.xTokenShareValue(vaultId), 1.2 ether);

    vm.warp(block.timestamp + 1 seconds);

    vm.prank(address(1));
    fnftStaking.withdraw(vaultId, 1 ether);
    assertEq(xToken.balanceOf(address(1)), 0);
    assertEq(vault.balanceOf(address(1)), 1.2 ether);

    vm.prank(address(2));
    fnftStaking.withdraw(vaultId, 0.5 ether);
    assertEq(xToken.balanceOf(address(2)), 0);
    assertEq(vault.balanceOf(address(2)), 0.6 ether);
  }

  function testVaultXTokenNotDeployed() public {
    mintVaultTokens(1);
    vm.expectRevert(IFNFTStaking.XTokenNotDeployed.selector);
    fnftStaking.vaultXToken(vaultId);
  }

  function testXTokenShareValueXTokenNotDeployed() public {
    mintVaultTokens(1);
    vm.expectRevert(IFNFTStaking.XTokenNotDeployed.selector);
    fnftStaking.xTokenShareValue(vaultId);
  }

  // NOTE: xTokenShareValue totalSupply > 0 scenarios tested above.
  function testXTokenShareValueZeroTotalSupply() public {
    mintVaultTokens(1);
    fnftStaking.deployXTokenForVault(vaultId);
    assertEq(fnftStaking.xTokenShareValue(vaultId), 1e18);
  }

  function testXTokenAddr() public {
    mintVaultTokens(1);
    // the address before and after deploy are the same
    address xTokenAddress = fnftStaking.xTokenAddr(address(vault));
    fnftStaking.deployXTokenForVault(vaultId);
    assertEq(fnftStaking.xTokenAddr(address(vault)), xTokenAddress);
  }

  function testXTokenStorageVariables() public {
    mintVaultTokens(1);
    fnftStaking.deployXTokenForVault(vaultId);
    FNFTStakingXTokenUpgradeable xToken = FNFTStakingXTokenUpgradeable(fnftStaking.vaultXToken(vaultId));
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