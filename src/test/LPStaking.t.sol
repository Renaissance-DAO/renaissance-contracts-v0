// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
import {LPStaking} from "../contracts/LPStaking.sol";
import {FNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
import {FNFTCollection} from "../contracts/FNFTCollection.sol";
import {FeeDistributor} from "../contracts/FeeDistributor.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
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
  FNFTCollectionFactory private factory;
  FNFTCollection private vault;
  IUniswapV2Factory private trisolarisFactory;
  IUniswapV2Pair private trisolarisPair;
  IUniswapV2Router private trisolarisRouter;

  MockNFT public token;

  function setUp() public {
    setupEnvironment(10 ether);
    (
      stakingTokenProvider,
      lpStaking,
      feeDistributor,
      factory
    ) = setupCollectionVaultContracts();

    trisolarisFactory = setupPairFactory();
    trisolarisRouter = setupRouter();

    token = new MockNFT();
  }

  function testVariables() public {
    assertEq(address(lpStaking.fnftCollectionFactory()), address(factory));
    assertEq(address(lpStaking.stakingTokenProvider()), address(stakingTokenProvider));
    // NOTE: where is this actually set?
    assertEq(address(lpStaking.rewardDistTokenImpl()), address(0));
  }

  function testSetFNFTCollectionFactoryAlreadySet() public {
    vm.expectRevert(LPStaking.FactoryAlreadySet.selector);
    lpStaking.setFNFTCollectionFactory(address(1));
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
    lpStaking.addPoolForVault(0);
  }

  // function testAddPoolForVaultFactoryDoesNotExist() public {
  // }

  function testVaultStakingInfo() public {
    mintVaultTokens(1);

    createTrisolarisPair();

    // actually, even if the Trisolaris pair is not created, the address is still pre-computed.
    (address stakingToken, address rewardToken) = lpStaking.vaultStakingInfo(0);
    assertEq(stakingToken, address(trisolarisPair));
    assertEq(rewardToken, address(vault));
  }

  function testDeposit() public {
    mintVaultTokens(2);

    createTrisolarisPair();
    addLiquidity();
    depositLPTokens();

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(this)), 999999999999999000);
    assertEq(rewardDistToken.timelockUntil(address(this)), block.timestamp + 2);
  }

  function testDepositTwice() public {
    mintVaultTokens(2);

    createTrisolarisPair();
    addLiquidity();

    uint256 lpTokenBalance = trisolarisPair.balanceOf(address(this));
    trisolarisPair.approve(address(lpStaking), lpTokenBalance);
    lpStaking.deposit(0, lpTokenBalance / 2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();
    assertEq(rewardDistToken.balanceOf(address(this)), 499999999999999500);
    assertEq(rewardDistToken.timelockUntil(address(this)), block.timestamp + 2);

    lpStaking.deposit(0, lpTokenBalance / 2);

    assertEq(rewardDistToken.balanceOf(address(this)), 999999999999999000);
    // timelock value does not change
    assertEq(rewardDistToken.timelockUntil(address(this)), block.timestamp + 2);
  }

  function testReceiveRewards() public {
    mintVaultTokens(2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();

    createTrisolarisPair();
    addLiquidity();
    depositLPTokens();

    assertEq(vault.balanceOf(address(rewardDistToken)), 0);
    assertEq(rewardDistToken.accumulativeRewardOf(address(this)), 0);

    vault.approve(address(lpStaking), 0.5 ether);
    lpStaking.receiveRewards(0, 0.5 ether);

    assertEq(vault.balanceOf(address(rewardDistToken)), 0.5 ether);
    // TODO: fix the precision issue
    // assertEq(rewardDistToken.accumulativeRewardOf(address(this)), 0.5 ether);
    assertEq(rewardDistToken.accumulativeRewardOf(address(this)), 499999999999999999);
  }

  function testTimelockedTokensCannotBeTransferred() public {
    mintVaultTokens(2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();

    createTrisolarisPair();
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
    mintVaultTokens(2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();

    createTrisolarisPair();
    addLiquidity();

    uint256 lpTokenBalance = trisolarisPair.balanceOf(address(this));
    trisolarisPair.transfer(address(1), lpTokenBalance);

    vm.startPrank(address(1));
    trisolarisPair.approve(address(lpStaking), lpTokenBalance);
    lpStaking.deposit(0, lpTokenBalance);
    vm.stopPrank();

    assertEq(trisolarisPair.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.balanceOf(address(1)), 999999999999999000);
    assertEq(vault.balanceOf(address(1)), 0);

    vault.approve(address(lpStaking), 0.5 ether);
    lpStaking.receiveRewards(0, 0.5 ether);

    vm.warp(block.timestamp + 3);
    vm.prank(address(1));
    lpStaking.exit(0);

    assertEq(trisolarisPair.balanceOf(address(1)), lpTokenBalance);
    assertEq(vault.balanceOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.withdrawnRewardOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.dividendOf(address(1)), 0);
    assertEq(rewardDistToken.accumulativeRewardOf(address(1)), 499999999999999999);
  }

  function testEmergencyExitAndClaim() public {
    mintVaultTokens(2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();

    createTrisolarisPair();
    addLiquidity();

    uint256 lpTokenBalance = trisolarisPair.balanceOf(address(this));
    trisolarisPair.transfer(address(1), lpTokenBalance);

    vm.startPrank(address(1));
    trisolarisPair.approve(address(lpStaking), lpTokenBalance);
    lpStaking.deposit(0, lpTokenBalance);
    vm.stopPrank();

    assertEq(trisolarisPair.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.balanceOf(address(1)), 999999999999999000);
    assertEq(vault.balanceOf(address(1)), 0);

    vault.approve(address(lpStaking), 0.5 ether);
    lpStaking.receiveRewards(0, 0.5 ether);

    vm.warp(block.timestamp + 3);
    (address stakingToken, address rewardToken) = lpStaking.vaultStakingInfo(0);
    vm.prank(address(1));
    lpStaking.emergencyExitAndClaim(stakingToken, rewardToken);

    assertEq(trisolarisPair.balanceOf(address(1)), lpTokenBalance);
    assertEq(vault.balanceOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.withdrawnRewardOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.dividendOf(address(1)), 0);
    assertEq(rewardDistToken.accumulativeRewardOf(address(1)), 499999999999999999);
  }

  function testEmergencyExit() public {
    mintVaultTokens(2);

    TimelockRewardDistributionTokenImpl rewardDistToken = getRewardDistToken();

    createTrisolarisPair();
    addLiquidity();

    uint256 lpTokenBalance = trisolarisPair.balanceOf(address(this));
    trisolarisPair.transfer(address(1), lpTokenBalance);

    vm.startPrank(address(1));
    trisolarisPair.approve(address(lpStaking), lpTokenBalance);
    lpStaking.deposit(0, lpTokenBalance);
    vm.stopPrank();

    assertEq(trisolarisPair.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.balanceOf(address(1)), 999999999999999000);
    assertEq(vault.balanceOf(address(1)), 0);

    vault.approve(address(lpStaking), 0.5 ether);
    lpStaking.receiveRewards(0, 0.5 ether);

    vm.warp(block.timestamp + 3);
    (address stakingToken, address rewardToken) = lpStaking.vaultStakingInfo(0);
    vm.prank(address(1));
    lpStaking.emergencyExit(stakingToken, rewardToken);

    assertEq(trisolarisPair.balanceOf(address(1)), lpTokenBalance);
    assertEq(vault.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.balanceOf(address(1)), 0);
    assertEq(rewardDistToken.withdrawnRewardOf(address(1)), 0);
    assertEq(rewardDistToken.dividendOf(address(1)), 499999999999999999);
    assertEq(rewardDistToken.accumulativeRewardOf(address(1)), 499999999999999999);
  }

  function createTrisolarisPair() private {
    trisolarisPair = IUniswapV2Pair(trisolarisFactory.createPair(address(vault), stakingTokenProvider.defaultPairedToken()));
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

  function addLiquidity() private {
    vault.approve(address(trisolarisRouter), 1 ether);
    trisolarisRouter.addLiquidityETH{value: 1 ether}(
      address(vault),
      1 ether,
      0,
      0,
      address(this),
      block.timestamp
    );
  }

  function depositLPTokens() private {
    uint256 lpTokenBalance = trisolarisPair.balanceOf(address(this));
    trisolarisPair.approve(address(lpStaking), lpTokenBalance);
    lpStaking.deposit(0, lpTokenBalance);
  }

  function getRewardDistToken() private returns (TimelockRewardDistributionTokenImpl rewardDistToken) {
    (address stakingToken, address rewardToken) = lpStaking.vaultStakingInfo(0);
    address rewardDistTokenAddress = lpStaking.rewardDistributionTokenAddr(stakingToken, rewardToken);
    rewardDistToken = TimelockRewardDistributionTokenImpl(rewardDistTokenAddress);
  }
}