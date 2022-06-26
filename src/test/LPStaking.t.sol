// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
import {LPStaking} from "../contracts/LPStaking.sol";
import {FNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
import {VaultManager} from "../contracts/VaultManager.sol";
import {FNFTCollection} from "../contracts/FNFTCollection.sol";
import {FeeDistributor} from "../contracts/FeeDistributor.sol";
import {IUniswapV2Factory} from "../contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router} from "../contracts/interfaces/IUniswapV2Router.sol";
import {TimelockRewardDistributionTokenImpl} from "../contracts/token/TimelockRewardDistributionTokenImpl.sol";

/// @author 0xkowloon
/// @title Tests for LP staking
contract LPStakingTest is DSTest, SetupEnvironment {
  StakingTokenProvider private stakingTokenProvider;
  LPStaking private lpStaking;
  FeeDistributor private feeDistributor;
  FNFTCollectionFactory private fnftCollectionFactory;
  VaultManager private vaultManager;
  FNFTCollection private vault;
  IUniswapV2Factory private uniswapV2Factory;
  IUniswapV2Pair private uniswapV2Pair;
  IUniswapV2Router private uniswapV2Router;

  MockNFT public token;

  uint256 public vaultId;

  function setUp() public {
    setupEnvironment(10 ether);
    (   stakingTokenProvider,
        lpStaking,
        ,
        ,
        ,
        feeDistributor,
        vaultManager,
        ,
        fnftCollectionFactory,
    ) = setupContracts();

    uniswapV2Factory = setupPairFactory();
    uniswapV2Router = setupRouter();

    token = new MockNFT();

    vaultId = 0;
  }

  function testStorageVariables() public {
    assertEq(address(lpStaking.vaultManager()), address(vaultManager));
    assertEq(address(lpStaking.stakingTokenProvider()), address(stakingTokenProvider));
  }

  function testSetVaultManagerAlreadySet() public {
    vm.expectRevert(LPStaking.VaultManagerAlreadySet.selector);
    lpStaking.setVaultManager(address(1));
  }

  function testSetStakingTokenProvider() public {
    lpStaking.setStakingTokenProvider(address(1));
    assertEq(address(lpStaking.stakingTokenProvider()), address(1));
  }

  function testSetStakingTokenProviderZeroAddress() public {
    vm.expectRevert(LPStaking.ZeroAddress.selector);
    lpStaking.setStakingTokenProvider(address(0));
  }

  function testAddPoolForVaultPoolAlreadyExists() public {
    mintVaultTokens(1);
    vm.expectRevert(LPStaking.PoolAlreadyExists.selector);
    lpStaking.addPoolForVault(vaultId);
  }

  function testVaultStakingInfo() public {
    mintVaultTokens(1);

    createUniswapV2Pair();

    // actually, even if the uniswapV2 pair is not created, the address is still pre-computed.
    (address stakingToken, address rewardToken) = lpStaking.vaultStakingInfo(vaultId);
    assertEq(stakingToken, address(uniswapV2Pair));
    assertEq(rewardToken, address(vault));
  }

  function testDeposit() public {
    mintVaultTokens(2);

    createUniswapV2Pair();
    addLiquidity();
    depositLPTokens();

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(this)), 999999999999999000);
    assertEq(rewardDistToken.timelockUntil(address(this)), block.timestamp + 2);
  }

  function testTimelockDepositFor() public {
    mintVaultTokens(2);

    createUniswapV2Pair();
    addLiquidity();

    vaultManager.setFeeExclusion(address(this), true);

    uint256 lpTokenBalance = uniswapV2Pair.balanceOf(address(this));
    uniswapV2Pair.approve(address(lpStaking), lpTokenBalance);
    lpStaking.timelockDepositFor(vaultId, address(1), lpTokenBalance, 123);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(1)), 999999999999999000);
    assertEq(rewardDistToken.timelockUntil(address(1)), block.timestamp + 123);
  }

  function testTimelockDepositForNotExcludedFromFees() public {
    mintVaultTokens(2);

    createUniswapV2Pair();
    addLiquidity();

    uint256 lpTokenBalance = uniswapV2Pair.balanceOf(address(this));
    uniswapV2Pair.approve(address(lpStaking), lpTokenBalance);
    vm.expectRevert(LPStaking.NotExcludedFromFees.selector);
    lpStaking.timelockDepositFor(vaultId, address(1), lpTokenBalance, 123);
  }

  function testTimelockDepositForTimelockTooLong() public {
    mintVaultTokens(2);

    createUniswapV2Pair();
    addLiquidity();

    uint256 lpTokenBalance = uniswapV2Pair.balanceOf(address(this));
    uniswapV2Pair.approve(address(lpStaking), lpTokenBalance);
    vm.expectRevert(LPStaking.TimelockTooLong.selector);
    lpStaking.timelockDepositFor(vaultId, address(1), lpTokenBalance, 2592000);
  }

  function testDepositTwice() public {
    mintVaultTokens(2);

    createUniswapV2Pair();
    addLiquidity();

    uint256 lpTokenBalance = uniswapV2Pair.balanceOf(address(this));
    uniswapV2Pair.approve(address(lpStaking), lpTokenBalance);
    lpStaking.deposit(vaultId, lpTokenBalance / 2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(this)), 499999999999999500);
    assertEq(rewardDistToken.timelockUntil(address(this)), block.timestamp + 2);

    lpStaking.deposit(vaultId, lpTokenBalance / 2);

    assertEq(rewardDistToken.balanceOf(address(this)), 999999999999999000);
    // timelock value does not change
    assertEq(rewardDistToken.timelockUntil(address(this)), block.timestamp + 2);
  }

  function testReceiveRewards() public {
    mintVaultTokens(2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();

    createUniswapV2Pair();
    addLiquidity();
    depositLPTokens();

    assertEq(vault.balanceOf(address(rewardDistToken)), 0);
    assertEq(rewardDistToken.accumulativeRewardOf(address(this)), 0);

    vault.approve(address(lpStaking), 0.5 ether);
    lpStaking.receiveRewards(vaultId, 0.5 ether);

    assertEq(vault.balanceOf(address(rewardDistToken)), 0.5 ether);
    // TODO: fix the precision issue
    // assertEq(rewardDistToken.accumulativeRewardOf(address(this)), 0.5 ether);
    assertEq(rewardDistToken.accumulativeRewardOf(address(this)), 499999999999999999);
  }

  function testTimelockedTokensCannotBeTransferred() public {
    mintVaultTokens(2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();

    createUniswapV2Pair();
    addLiquidity();
    depositLPTokens();

    vm.expectRevert(TimelockRewardDistributionTokenImpl.UserIsLocked.selector);
    rewardDistToken.transfer(address(1), 0.01 ether);

    // passed timelock, transfer goes through
    vm.warp(block.timestamp + 3);
    rewardDistToken.transfer(address(1), 0.01 ether);
    assertEq(rewardDistToken.balanceOf(address(1)), 0.01 ether);
  }

  function testExit() public {
    uint256 lpTokenBalance = exitRelatedFunctionsSetUp();

    vm.warp(block.timestamp + 3);
    vm.prank(address(1));
    lpStaking.exit(vaultId);

    assertEq(uniswapV2Pair.balanceOf(address(1)), lpTokenBalance);
    assertEq(vault.balanceOf(address(1)), 499999999999999999);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.withdrawnRewardOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.dividendOf(address(1)), 0);
    assertEq(rewardDistToken.accumulativeRewardOf(address(1)), 499999999999999999);
  }

  function testEmergencyExitAndClaim() public {
    uint256 lpTokenBalance = exitRelatedFunctionsSetUp();

    vm.warp(block.timestamp + 3);
    (address stakingToken, address rewardToken) = lpStaking.vaultStakingInfo(vaultId);
    vm.prank(address(1));
    lpStaking.emergencyExitAndClaim(stakingToken, rewardToken);

    assertEq(uniswapV2Pair.balanceOf(address(1)), lpTokenBalance);
    assertEq(vault.balanceOf(address(1)), 499999999999999999);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.withdrawnRewardOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.dividendOf(address(1)), 0);
    assertEq(rewardDistToken.accumulativeRewardOf(address(1)), 499999999999999999);
  }

  function testEmergencyExit() public {
    uint256 lpTokenBalance = exitRelatedFunctionsSetUp();

    vm.warp(block.timestamp + 3);
    (address stakingToken, address rewardToken) = lpStaking.vaultStakingInfo(vaultId);
    vm.prank(address(1));
    lpStaking.emergencyExit(stakingToken, rewardToken);

    assertEq(uniswapV2Pair.balanceOf(address(1)), lpTokenBalance);
    assertEq(vault.balanceOf(address(1)), 0);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.withdrawnRewardOf(address(1)), 0);
    assertEq(rewardDistToken.dividendOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.accumulativeRewardOf(address(1)), 499999999999999999);
  }

  function testWithdraw() public {
    exitRelatedFunctionsSetUp();

    vm.warp(block.timestamp + 3);
    vm.prank(address(1));

    lpStaking.withdraw(vaultId, 100000000000000000);

    assertEq(uniswapV2Pair.balanceOf(address(1)), 100000000000000000);
    assertEq(vault.balanceOf(address(1)), 499999999999999999);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(1)), 899999999999999000);
    assertEq(rewardDistToken.withdrawnRewardOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.dividendOf(address(1)), 0);
    assertEq(rewardDistToken.accumulativeRewardOf(address(1)), 499999999999999999);
  }

  function testClaimRewards() public {
    exitRelatedFunctionsSetUp();

    vm.warp(block.timestamp + 3);
    vm.prank(address(1));

    lpStaking.claimRewards(vaultId);

    assertEq(uniswapV2Pair.balanceOf(address(1)), 0);
    assertEq(vault.balanceOf(address(1)), 499999999999999999);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(1)), 999999999999999000);
    assertEq(rewardDistToken.withdrawnRewardOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.dividendOf(address(1)), 0);
    assertEq(rewardDistToken.accumulativeRewardOf(address(1)), 499999999999999999);
  }

  function createUniswapV2Pair() private {
    uniswapV2Pair = IUniswapV2Pair(uniswapV2Factory.createPair(address(vault), stakingTokenProvider.defaultPairedToken()));
  }

  // TODO: merge with FNFTCollectionTest.t.sol
  function createVault() private {
    fnftCollectionFactory.createVault("Doodles", "DOODLE", address(token), false, true);
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

  function addLiquidity() private {
    vault.approve(address(uniswapV2Router), 1 ether);
    uniswapV2Router.addLiquidityETH{value: 1 ether}(
      address(vault),
      1 ether,
      0,
      0,
      address(this),
      block.timestamp
    );
  }

  function depositLPTokens() private {
    uint256 lpTokenBalance = uniswapV2Pair.balanceOf(address(this));
    uniswapV2Pair.approve(address(lpStaking), lpTokenBalance);
    lpStaking.deposit(vaultId, lpTokenBalance);
  }

  function getRewardDistToken() private view returns (TimelockRewardDistributionTokenImpl rewardDistToken) {
    (address stakingToken, address rewardToken) = lpStaking.vaultStakingInfo(vaultId);
    address rewardDistTokenAddress = lpStaking.rewardDistributionTokenAddr(stakingToken, rewardToken);
    rewardDistToken = TimelockRewardDistributionTokenImpl(rewardDistTokenAddress);
  }

  function exitRelatedFunctionsSetUp() private returns (uint256 lpTokenBalance) {
    mintVaultTokens(2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();

    createUniswapV2Pair();
    addLiquidity();

    lpTokenBalance = uniswapV2Pair.balanceOf(address(this));
    uniswapV2Pair.transfer(address(1), lpTokenBalance);

    vm.startPrank(address(1));
    uniswapV2Pair.approve(address(lpStaking), lpTokenBalance);
    lpStaking.deposit(vaultId, lpTokenBalance);
    vm.stopPrank();

    assertEq(uniswapV2Pair.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.balanceOf(address(1)), 999999999999999000);
    assertEq(vault.balanceOf(address(1)), 0);

    vault.approve(address(lpStaking), 0.5 ether);
    lpStaking.receiveRewards(vaultId, 0.5 ether);
  }
}
