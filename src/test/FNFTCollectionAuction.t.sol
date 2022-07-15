// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {SimpleMockNFT} from "../contracts/mocks/NFT.sol";
import {Mock1155} from "../contracts/mocks/ERC1155.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {FlashBorrower} from "./utils/FlashBorrower.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
import {LPStaking} from "../contracts/LPStaking.sol";
import {FNFTCollectionFactory, IFNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
import {IPausable} from "../contracts/interfaces/IPausable.sol";
import {VaultManager} from "../contracts/VaultManager.sol";
import {FNFTCollection, IFNFTCollection} from "../contracts/FNFTCollection.sol";
import {FeeDistributor} from "../contracts/FeeDistributor.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
import {ERC20FlashMintUpgradeable} from "../contracts/token/ERC20FlashMintUpgradeable.sol";

/// @author 0xkowloon
/// @title Tests for FNFTCollection vault auctions
contract FNFTCollectionAuctionTest is DSTest, SetupEnvironment {
  StakingTokenProvider private stakingTokenProvider;
  LPStaking private lpStaking;
  FeeDistributor private feeDistributor;
  VaultManager private vaultManager;
  FNFTCollectionFactory private fnftCollectionFactory;
  FNFTCollection private vault;
  SimpleMockNFT private token;

  address private bidderOne = address(1);
  address private bidderTwo = address(2);

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

    token = new SimpleMockNFT();
  }

  function testGetAuctionInactive() public {
    mintVaultTokens(1);
    vault.setVaultFeatures(true, false, false, false, false, true);

    vm.expectRevert(IFNFTCollection.AuctionNotLive.selector);
    vault.getAuction(1);
  }

  function testStartAuction() public {
    startAuction();

    assertEq(vault.balanceOf(bidderOne), 0);
    (uint256 livePrice, uint256 end, IFNFTCollection.AuctionState state, address winning) = vault.getAuction(1);
    assertEq(livePrice, 1e18);
    assertEq(end, block.timestamp + 3 days);
    assertEq(uint256(state), 1);
    assertEq(winning, bidderOne);
  }

  function testStartAuctionFor1155Tokens() public {
    Mock1155 multiToken = new Mock1155();
    multiToken.mint(bidderOne, 1, 2);
    fnftCollectionFactory.createVault(address(multiToken), true, true, "Doodles", "DOODLE");
    vault = FNFTCollection(vaultManager.vault(uint256(0)));

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 1;

    vm.prank(bidderOne);
    multiToken.setApprovalForAll(address(vault), true);

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 2;

    vault.setVaultFeatures(true, true, true, true, true, true);

    vm.prank(bidderOne);
    vault.mint(tokenIds, amounts);

    vm.prank(bidderOne);
    vm.expectRevert(IFNFTCollection.BidDisabled.selector);
    vault.startAuction(1, 1e18);
  }

  function testStartAuctionBidDisabled() public {
    mintVaultTokens(2);

    vault.transfer(bidderOne, 1e18);

    vm.expectRevert(IFNFTCollection.BidDisabled.selector);
    vm.prank(bidderOne);
    vault.startAuction(1, 1e18);
  }

  function testStartAuctionPaused() public {
    pauseFeature(4);

    mintVaultTokens(2);

    vault.transfer(bidderOne, 1e18);

    vm.expectRevert(IFNFTCollection.Paused.selector);
    vm.prank(bidderOne);
    vault.startAuction(1, 1e18);
  }

  function testStartAuctionAuctionLive() public {
    startAuction();

    vault.transfer(bidderTwo, 1e18);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.AuctionLive.selector);
    vault.startAuction(1, 1e18);
  }

  function testStartAuctionBidTooLow() public {
    mintVaultTokens(2);
    vault.setVaultFeatures(true, false, false, false, false, true);

    vault.transfer(bidderOne, 1e18);

    vm.prank(bidderOne);
    vm.expectRevert(IFNFTCollection.BidTooLow.selector);
    vault.startAuction(1, 9e17);

  }

  function testBid() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vm.prank(bidderTwo);
    vault.bid(1, newBid);

    assertEq(vault.balanceOf(bidderOne), 1e18);
    assertEq(vault.balanceOf(bidderTwo), 0);

    (uint256 livePrice, uint256 end, IFNFTCollection.AuctionState state, address winning) = vault.getAuction(1);
    assertEq(livePrice, newBid);
    assertEq(end, block.timestamp + 3 days);
    assertEq(uint256(state), 1);
    assertEq(winning, bidderTwo);
  }

  function testBidBidDisabled() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vault.setVaultFeatures(true, false, false, false, false, false);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.BidDisabled.selector);
    vault.bid(1, newBid);
  }

  function testBidPaused() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    pauseFeature(4);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.Paused.selector);
    vault.bid(1, newBid);
  }

  function testBidAuctionNotLive() public {
    mintVaultTokens(2);
    vault.setVaultFeatures(true, false, false, false, false, true);

    vault.transfer(bidderOne, 1e18);

    vm.prank(bidderOne);
    vm.expectRevert(IFNFTCollection.AuctionNotLive.selector);
    vault.bid(1, 1e18);
  }

  function testBidBidTooLow() public {
    startAuction();

    uint256 newBid = 10499e14;
    vault.transfer(bidderTwo, newBid);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.BidTooLow.selector);
    vault.bid(1, newBid);
  }

  function testBidAuctionEnded() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vm.warp(block.timestamp + 3 days);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.AuctionEnded.selector);
    vault.bid(1, newBid);
  }

  function testBidExtendAuctionDuration() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    (,uint256 end,,) = vault.getAuction(1);

    vm.warp(end - 15 minutes);
    uint256 newEnd = end + 15 minutes;

    vm.prank(bidderTwo);
    vault.bid(1, newBid);

    (uint256 livePrice, uint256 endAfterBid, IFNFTCollection.AuctionState state, address winning) = vault.getAuction(1);
    assertEq(livePrice, newBid);
    assertEq(endAfterBid, newEnd);
    assertEq(uint256(state), 1);
    assertEq(winning, bidderTwo);
  }

  function testEndAuction() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    address depositor = address(this);
    uint256 currentDepositorBalance = vault.balanceOf(depositor);

    vm.prank(bidderTwo);
    vault.bid(1, newBid);
    vm.warp(block.timestamp + 3 days);
    vault.endAuction(1);

    vm.expectRevert(IFNFTCollection.AuctionNotLive.selector);
    vault.getAuction(1);

    assertEq(vault.balanceOf(depositor), currentDepositorBalance + 500e14);
    assertEq(token.ownerOf(1), bidderTwo);
    vm.expectRevert(IFNFTCollection.NotInVault.selector);
    vault.getDepositor(1);
  }

  function testEndAuctionBidDisabled() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vm.prank(bidderTwo);
    vault.bid(1, newBid);
    vm.warp(block.timestamp + 3 days);
    vault.setVaultFeatures(true, false, false, false, false, false);
    vm.expectRevert(IFNFTCollection.BidDisabled.selector);
    vault.endAuction(1);
  }

  function testEndAuctionPaused() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vm.prank(bidderTwo);
    vault.bid(1, newBid);
    vm.warp(block.timestamp + 3 days);

    pauseFeature(4);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.Paused.selector);
    vault.endAuction(1);
  }

  function testEndAuctionAuctionNotLive() public {
    mintVaultTokens(2);
    vault.setVaultFeatures(true, false, false, false, false, true);

    vault.transfer(bidderOne, 1e18);

    vm.prank(bidderOne);
    vm.expectRevert(IFNFTCollection.AuctionNotLive.selector);
    vault.endAuction(1);
  }

  function testEndAuctionAuctionNotEnded() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vm.startPrank(bidderTwo);
    vault.bid(1, newBid);

    vm.warp(block.timestamp + 3 days - 1 seconds);
    vm.expectRevert(IFNFTCollection.AuctionNotEnded.selector);
    vault.endAuction(1);
    vm.stopPrank();
  }

  function testRedeemSwapBidEnabled() public {
    mintVaultTokens(2);
    token.mint(address(1), 3);
    vault.setVaultFeatures(true, true, true, true, true, true);

    vault.transfer(address(1), 1e18);

    vm.startPrank(address(1));

    vm.expectRevert(IFNFTCollection.BidEnabled.selector);
    vault.redeem(1, new uint256[](0));

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 1;
    vm.expectRevert(IFNFTCollection.BidEnabled.selector);
    vault.redeem(1, specificIds);

    token.setApprovalForAll(address(vault), true);
    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;

    uint256[] memory amounts = new uint256[](1);
    tokenIds[0] = 1;

    vm.expectRevert(IFNFTCollection.BidEnabled.selector);
    vault.swap(tokenIds, amounts, new uint256[](0));

    vm.expectRevert(IFNFTCollection.BidEnabled.selector);
    vault.swap(tokenIds, amounts, specificIds);

    vm.stopPrank();
  }

  function createVault() private {
    fnftCollectionFactory.createVault(address(token), false, true, "Doodles", "DOODLE");
    vault = FNFTCollection(vaultManager.vault(uint256(0)));
  }

  function testSetMinBidIncrease() public {
    vm.expectRevert(IFNFTCollectionFactory.MinBidIncreaseOutOfBounds.selector);
    fnftCollectionFactory.setFactoryThresholds(8 weeks, 1 days, 99);

    vm.expectRevert(IFNFTCollectionFactory.MinBidIncreaseOutOfBounds.selector);
    fnftCollectionFactory.setFactoryThresholds(8 weeks, 1 days, 1001);

    fnftCollectionFactory.setFactoryThresholds(8 weeks, 1 days, 1000);
    assertEq(fnftCollectionFactory.minBidIncrease(), 1000);
  }

  function testWithdraw() public {
    address depositor = address(1);

    createVault();

    vm.startPrank(depositor);
    uint256[] memory tokenIds = mintNFTs(depositor, 3);
    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);
    vm.stopPrank();

    vault.setVaultFeatures(true, false, false, false, false, true);

    assertEq(token.balanceOf(address(vault)), 3);
    assertEq(token.balanceOf(depositor), 0);
    assertEq(vault.balanceOf(depositor), 27e17);

    assertEq(vault.getDepositor(1), depositor);
    assertEq(vault.getDepositor(2), depositor);
    assertEq(vault.getDepositor(3), depositor);

    uint256[] memory withdrawTokenIds = new uint256[](2);
    withdrawTokenIds[0] = 1;
    withdrawTokenIds[1] = 2;
    vm.prank(depositor);
    vault.withdraw(withdrawTokenIds);

    assertEq(token.balanceOf(address(vault)), 1);
    assertEq(token.balanceOf(depositor), 2);
    assertEq(vault.balanceOf(depositor), 5e17);

    vm.expectRevert(IFNFTCollection.NotInVault.selector);
    vault.getDepositor(1);
    vm.expectRevert(IFNFTCollection.NotInVault.selector);
    vault.getDepositor(2);

    assertEq(vault.getDepositor(3), depositor);
  }

  function testWithdrawNotOwner() public {
    address depositor = address(1);

    createVault();

    vm.startPrank(depositor);
    uint256[] memory tokenIds = mintNFTs(depositor, 3);
    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);
    vault.transfer(address(2), 27e17);
    vm.stopPrank();

    vault.setVaultFeatures(true, false, false, false, false, true);

    uint256[] memory withdrawTokenIds = new uint256[](2);
    withdrawTokenIds[0] = 1;
    withdrawTokenIds[1] = 2;
    vm.prank(address(2));
    vm.expectRevert(IFNFTCollection.NotNFTOwner.selector);
    vault.withdraw(withdrawTokenIds);
  }

  function testWithdrawBidDisabled() public {
    address depositor = address(1);

    createVault();

    vm.startPrank(depositor);
    uint256[] memory tokenIds = mintNFTs(depositor, 3);
    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);
    vm.stopPrank();

    uint256[] memory withdrawTokenIds = new uint256[](2);
    withdrawTokenIds[0] = 1;
    withdrawTokenIds[1] = 2;
    vm.prank(depositor);
    vm.expectRevert(IFNFTCollection.BidDisabled.selector);
    vault.withdraw(withdrawTokenIds);
  }

  function testWithdrawPaused() public {
    address depositor = address(1);

    createVault();

    vm.startPrank(depositor);
    uint256[] memory tokenIds = mintNFTs(depositor, 3);
    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);
    vm.stopPrank();

    vault.setVaultFeatures(true, false, false, false, false, true);
    pauseFeature(2);

    uint256[] memory withdrawTokenIds = new uint256[](2);
    withdrawTokenIds[0] = 1;
    withdrawTokenIds[1] = 2;
    vm.prank(depositor);
    vm.expectRevert(IFNFTCollection.Paused.selector);
    vault.withdraw(withdrawTokenIds);
  }

  function mintNFTs(address to, uint256 amount) private returns (uint256[] memory tokenIds) {
    tokenIds = new uint256[](amount);

    for (uint i; i < amount; i++) {
      token.mint(to, i + 1);
      tokenIds[i] = i + 1;
    }

    token.setApprovalForAll(address(vault), true);
  }

  function mintVaultTokens(uint256 amount) private {
    createVault();

    uint256[] memory tokenIds = mintNFTs(address(this), amount);
    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);
  }

  function pauseFeature(uint256 lockId) private {
    fnftCollectionFactory.setIsGuardian(address(this), true);
    fnftCollectionFactory.pause(lockId);
  }

  function startAuction() private {
    mintVaultTokens(3);
    vault.setVaultFeatures(true, false, false, false, false, true);

    vault.transfer(bidderOne, 1e18);

    vm.prank(bidderOne);
    vault.startAuction(1, 1e18);
  }
}