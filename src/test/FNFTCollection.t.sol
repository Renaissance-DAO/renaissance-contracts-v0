// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {SimpleMockNFT} from "../contracts/mocks/NFT.sol";
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
/// @title Tests for FNFTCollection vaults
contract FNFTCollectionTest is DSTest, SetupEnvironment {
  StakingTokenProvider private stakingTokenProvider;
  LPStaking private lpStaking;
  FeeDistributor private feeDistributor;
  VaultManager private vaultManager;
  FNFTCollectionFactory private fnftCollectionFactory;
  FNFTCollection private vault;
  SimpleMockNFT public token;

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

  function testVarsAfterFactoryInit() public {
    assertEq(vaultManager.feeDistributor(), address(feeDistributor));
    assertEq(FNFTCollection(fnftCollectionFactory.childImplementation()).vaultId(), 0);

    assertEq(fnftCollectionFactory.factoryMintFee(), 0.1 ether);
    assertEq(fnftCollectionFactory.factoryRandomRedeemFee(), 0.05 ether);
    assertEq(fnftCollectionFactory.factoryTargetRedeemFee(), 0.1 ether);
    assertEq(fnftCollectionFactory.factoryRandomSwapFee(), 0.05 ether);
    assertEq(fnftCollectionFactory.factoryTargetSwapFee(), 0.1 ether);
  }

  function testCreateVault() public {
    createVault();

    assertEq(vault.name(), "Doodles");
    assertEq(vault.symbol(), "DOODLE");
    assertEq(vault.assetAddress(), address(token));
    assertEq(vault.curator(), address(this));
    assertEq(vault.owner(), address(this));
    assertEq(vault.vaultId(), uint256(0));
    assertEq(address(vault.factory()), address(fnftCollectionFactory));
    assertTrue(!vault.is1155());
    assertTrue(vault.allowAllItems());
    assertTrue(vault.enableMint());
    assertTrue(vault.enableRandomRedeem());
    assertTrue(vault.enableTargetRedeem());
    assertTrue(vault.enableRandomSwap());
    assertTrue(vault.enableTargetSwap());

    assertEq(vaultManager.numVaults(), 1);
  }

  function testCreateVaultFactoryIsPaused() public {
    assertTrue(!IPausable(address(fnftCollectionFactory)).isPaused(0));
    pauseFeature(0);
    assertTrue(IPausable(address(fnftCollectionFactory)).isPaused(0));

    vm.prank(address(1));
    vm.expectRevert(IFNFTCollection.Paused.selector);
    fnftCollectionFactory.createVault(address(token), false, true, "Doodles", "DOODLE");
  }

  function testCreateVaultOwnerCanBypassPausedFactory() public {
    pauseFeature(0);
    createVault();

    assertEq(vault.name(), "Doodles");
  }

  function testSetVaultMetadata() public {
    createVault();

    vault.setVaultMetadata("Wassiverse", "WASSI");

    assertEq(vault.name(), "Wassiverse");
    assertEq(vault.symbol(), "WASSI");
  }

  function testSetVaultFees() public {
    fnftCollectionFactory.setVaultFees(
      0,
      0.2 ether,
      0.1 ether,
      0.2 ether,
      0.1 ether,
      0.2 ether
    );

    (
      uint256 mintFee,
      uint256 randomRedeemFee,
      uint256 targetRedeemFee,
      uint256 randomSwapFee,
      uint256 targetSwapFee
    ) = fnftCollectionFactory.vaultFees(0);

    assertEq(mintFee, 0.2 ether);
    assertEq(randomRedeemFee, 0.1 ether);
    assertEq(targetRedeemFee, 0.2 ether);
    assertEq(randomSwapFee, 0.1 ether);
    assertEq(targetSwapFee, 0.2 ether);
  }

  function testVaultFeesFallback() public {
    createVault();

    (
      uint256 mintFee,
      uint256 randomRedeemFee,
      uint256 targetRedeemFee,
      uint256 randomSwapFee,
      uint256 targetSwapFee
    ) = fnftCollectionFactory.vaultFees(0);

    assertEq(mintFee, 0.1 ether);
    assertEq(randomRedeemFee, 0.05 ether);
    assertEq(targetRedeemFee, 0.1 ether);
    assertEq(randomSwapFee, 0.05 ether);
    assertEq(targetSwapFee, 0.1 ether);
  }

  function testSetVaultFeesTooHigh() public {
    createVault();
    vm.expectRevert(IFNFTCollectionFactory.FeeTooHigh.selector);
    fnftCollectionFactory.setVaultFees(
      0,
      0.6 ether,
      0.6 ether,
      0.6 ether,
      0.6 ether,
      0.6 ether
    );
  }

  function testSetVaultFeatures() public {
    createVault();

    vault.setVaultFeatures(false, false, false, false, false, true);

    assertTrue(!vault.enableMint());
    assertTrue(!vault.enableRandomRedeem());
    assertTrue(!vault.enableTargetRedeem());
    assertTrue(!vault.enableRandomSwap());
    assertTrue(!vault.enableTargetSwap());
    assertTrue(vault.enableBid());
  }

  function testVaultMint() public {
    createVault();

    token.mint(address(this), 1);
    token.mint(address(this), 2);

    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);

    // given 2 NFTs, mint 2 vault tokens
    // 10% fee goes to the fee distributor
    // There are no stakers to distribute to, all fees go to treasury
    assertEq(vault.balanceOf(address(this)), 1.8 ether);
    assertEq(vault.balanceOf(TREASURY_ADDRESS), 0.2 ether);

    assertEq(token.balanceOf(address(vault)), 2);
  }

  function testVaultMintPaused() public {
    createVault();

    token.mint(address(1), 1);
    token.mint(address(1), 2);

    vm.prank(address(1));
    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    pauseFeature(1);

    vm.prank(address(1));
    vm.expectRevert(IFNFTCollection.Paused.selector);
    vault.mint(tokenIds, amounts);
  }

  function testVaultMintOwnerCanBypassPausedFactory() public {
    createVault();

    token.mint(address(this), 1);
    token.mint(address(this), 2);

    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    pauseFeature(1);

    vault.mint(tokenIds, amounts);

    assertEq(vault.balanceOf(address(this)), 1.8 ether);
    assertEq(vault.balanceOf(TREASURY_ADDRESS), 0.2 ether);

    assertEq(token.balanceOf(address(vault)), 2);
  }

  function testVaultMintDisabled() public {
    createVault();

    token.mint(address(this), 1);
    token.mint(address(this), 2);

    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    vault.setVaultFeatures(false, true, true, true, true, false);

    vm.expectRevert(IFNFTCollection.MintDisabled.selector);
    vault.mint(tokenIds, amounts);
  }

  function testTargetRedeem() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.2 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    vm.prank(address(1));
    vault.redeem(2, redeemTokenIds);

    assertEq(token.balanceOf(address(1)), 2);
    assertEq(token.ownerOf(1), address(1));
    assertEq(token.ownerOf(2), address(vault));
    assertEq(token.ownerOf(3), address(1));
    // 2 ETH + 0.1 ETH per target redeem
    assertEq(vault.balanceOf(address(1)), 0);
  }

  function testTargetRedeemInsufficientBalance() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.19 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    vm.prank(address(1));
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    vault.redeem(2, redeemTokenIds);
  }

  function testTargetRedeemDisabled() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.2 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    vault.setVaultFeatures(true, true, false, true, true, false);

    vm.prank(address(1));
    vm.expectRevert(IFNFTCollection.TargetRedeemDisabled.selector);
    vault.redeem(2, redeemTokenIds);
  }

  function testTargetRedeemPaused() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.2 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    pauseFeature(2);

    vm.prank(address(1));
    vm.expectRevert(IFNFTCollection.Paused.selector);
    vault.redeem(2, redeemTokenIds);
  }

  function testRandomRedeem() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.1 ether);

    vm.prank(address(1));
    vault.redeem(2, new uint256[](0));

    assertEq(token.balanceOf(address(1)), 2);
    assertEq(token.balanceOf(address(vault)), 1);
    assertEq(vault.balanceOf(address(1)), 0);
  }

  function testRandomRedeemInsufficientBalance() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.09 ether);

    vm.prank(address(1));
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    vault.redeem(2, new uint256[](0));
  }

  function testRandomRedeemDisabled() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.1 ether);

    vault.setVaultFeatures(true, false, true, true, true, false);

    vm.prank(address(1));
    vm.expectRevert(IFNFTCollection.RandomRedeemDisabled.selector);
    vault.redeem(2, new uint256[](0));
  }

  function testRandomRedeemPaused() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.1 ether);

    pauseFeature(2);

    vm.prank(address(1));
    vm.expectRevert(IFNFTCollection.Paused.selector);
    vault.redeem(2, new uint256[](0));
  }

  function testTargetSwap() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.1 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 2;

    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vault.swap(tokenIds, new uint256[](0), specificIds);
    vm.stopPrank();

    assertEq(vault.balanceOf(address(1)), 0);
    assertEq(token.ownerOf(2), address(1));
    assertEq(token.ownerOf(3), address(vault));
  }

  function testTargetSwapInsufficientBalance() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.09 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 2;

    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    vault.swap(tokenIds, new uint256[](0), specificIds);
    vm.stopPrank();
  }

  function testTargetSwapDisabled() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.1 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 2;

    vault.setVaultFeatures(true, true, true, true, false, false);

    failedSwap(tokenIds, specificIds, IFNFTCollection.TargetSwapDisabled.selector);
  }

  function testTargetSwapPaused() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.1 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 2;

    pauseFeature(3);

    failedSwap(tokenIds, specificIds, IFNFTCollection.Paused.selector);
  }

  function testRandomSwap() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.05 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vault.swap(tokenIds, new uint256[](0), new uint256[](0));
    vm.stopPrank();

    assertEq(vault.balanceOf(address(1)), 0);
    assertEq(token.balanceOf(address(1)), 1);
    assertEq(token.ownerOf(3), address(vault));
  }

  function testRandomSwapInsufficientBalance() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.04 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    vault.swap(tokenIds, new uint256[](0), new uint256[](0));
    vm.stopPrank();
  }

  function testRandomSwapDisabled() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.05 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    vault.setVaultFeatures(true, true, true, false, true, false);

    failedSwap(tokenIds, new uint256[](0), IFNFTCollection.RandomSwapDisabled.selector);
  }

  function testRandomSwapPaused() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.05 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    pauseFeature(3);

    failedSwap(tokenIds, new uint256[](0), IFNFTCollection.Paused.selector);
  }

  // TODO: we need an FNFTCollectionFactoryTest contract
  function testSetFlashLoanFeeTooHigh() public {
    vm.expectRevert(IFNFTCollectionFactory.FeeTooHigh.selector);
    // set flashLoanFee to 501
    fnftCollectionFactory.setFactoryFees(0.1 ether, 0.05 ether, 0.1 ether, 0.05 ether, 0.1 ether, 501);
  }

  function testSetFlashLoanFeeNotOwner() public {
    vm.expectRevert("Ownable: caller is not the owner");
    vm.prank(address(1));
    // set flashLoanFee to 499
    fnftCollectionFactory.setFactoryFees(0.1 ether, 0.05 ether, 0.1 ether, 0.05 ether, 0.1 ether, 499);
  }

  function testFlashLoanGood() public {
    mintVaultTokens(1);
    // set flashLoanFee to 100 (1%)
    fnftCollectionFactory.setFactoryFees(0.1 ether, 0.05 ether, 0.1 ether, 0.05 ether, 0.1 ether, 100);

    FlashBorrower flashBorrower = new FlashBorrower(address(vault));
    vault.transfer(address(flashBorrower), 0.01 ether); // for fees

    // we just want to know that the fee is distributed, we don't care what the destination is yet.
    feeDistributor.pauseFeeDistribution(true);

    assertEq(vault.totalSupply(), 1 ether);
    assertEq(vault.balanceOf(address(vault)), 0);

    uint256 treasuryBalanceBeforeFlashLoan = vault.balanceOf(address(TREASURY_ADDRESS));

    flashBorrower.goodFlashLoan(1 ether);

    assertEq(vault.totalSupply(), 1 ether);
    assertEq(vault.balanceOf(address(vault)), 0);
    assertEq(vault.balanceOf(address(flashBorrower)), 0);
    assertEq(vault.balanceOf(address(TREASURY_ADDRESS)) - treasuryBalanceBeforeFlashLoan, 0.01 ether);
    assertEq(vault.allowance(address(flashBorrower), address(vault)), 0);
  }

  function testFlashLoanGoodFeeExcluded() public {
    mintVaultTokens(1);
    // set flashLoanFee to 100 (1%)
    fnftCollectionFactory.setFactoryFees(0.1 ether, 0.05 ether, 0.1 ether, 0.05 ether, 0.1 ether, 100);

    FlashBorrower flashBorrower = new FlashBorrower(address(vault));
    vaultManager.setFeeExclusion(address(flashBorrower), true);

    assertEq(vault.totalSupply(), 1 ether);
    assertEq(vault.balanceOf(address(vault)), 0);

    uint256 treasuryBalanceBeforeFlashLoan = vault.balanceOf(address(TREASURY_ADDRESS));

    flashBorrower.goodFlashLoan(1 ether);

    assertEq(vault.totalSupply(), 1 ether);
    assertEq(vault.balanceOf(address(vault)), 0);
    assertEq(vault.balanceOf(address(flashBorrower)), 0);
    assertEq(vault.balanceOf(address(TREASURY_ADDRESS)) - treasuryBalanceBeforeFlashLoan, 0);
    assertEq(vault.allowance(address(flashBorrower), address(vault)), 0);
  }

  function testFlashLoanBad() public {
    mintVaultTokens(1);
    // set flashLoanFee to 100 (1%)
    fnftCollectionFactory.setFactoryFees(0.1 ether, 0.05 ether, 0.1 ether, 0.05 ether, 0.1 ether, 100);

    FlashBorrower flashBorrower = new FlashBorrower(address(vault));
    vault.transfer(address(flashBorrower), 0.01 ether); // for fees

    assertEq(vault.totalSupply(), 1 ether);
    assertEq(vault.balanceOf(address(vault)), 0);

    vm.expectRevert(ERC20FlashMintUpgradeable.FlashLoanNotRepaid.selector);
    flashBorrower.badFlashLoan(1 ether);

    assertEq(vault.totalSupply(), 1 ether);
    assertEq(vault.balanceOf(address(flashBorrower)), 0.01 ether);
    assertEq(vault.balanceOf(address(vault)), 0);
    assertEq(vault.allowance(address(flashBorrower), address(vault)), 0);
  }

  // TODO:
  // "not from vault" error
  // disable vault fees

  function createVault() private {
    fnftCollectionFactory.createVault(address(token), false, true, "Doodles", "DOODLE");
    vault = FNFTCollection(vaultManager.vault(uint256(0)));
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

  function pauseFeature(uint256 lockId) private {
    fnftCollectionFactory.setIsGuardian(address(this), true);
    fnftCollectionFactory.pause(lockId);
  }

  function failedSwap(uint256[] memory tokenIds, uint256[] memory specificIds, bytes4 errorSelector) private {
    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vm.expectRevert(errorSelector);
    vault.swap(tokenIds, new uint256[](0), specificIds);
    vm.stopPrank();
  }
}