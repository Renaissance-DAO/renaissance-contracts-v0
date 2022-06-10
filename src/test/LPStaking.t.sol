// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
// import {MockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
import {LPStaking} from "../contracts/LPStaking.sol";
import {FNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
// import {FNFTCollection} from "../contracts/FNFTCollection.sol";
import {FeeDistributor} from "../contracts/FeeDistributor.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";

/// @author 0xkowloon
/// @title Tests for LP staking
contract LPStakingTest is DSTest, SetupEnvironment {
  StakingTokenProvider private stakingTokenProvider;
  LPStaking private lpStaking;
  FeeDistributor private feeDistributor;
  FNFTCollectionFactory private factory;
  // FNFTCollection private vault;

  // MockNFT public token;

  function setUp() public {
    setupEnvironment(10 ether);
    (
      stakingTokenProvider,
      lpStaking,
      feeDistributor,
      factory
    ) = setupCollectionVaultContracts();

    // token = new MockNFT();
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
}