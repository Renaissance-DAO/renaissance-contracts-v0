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
}