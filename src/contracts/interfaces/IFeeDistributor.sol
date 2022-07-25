// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./IVaultManager.sol";
import "./ILPStaking.sol";
import "./IFNFTStaking.sol";

interface IFeeDistributor {

  struct FeeReceiver {
    uint256 allocPoint;
    address receiver;
    bool isContract;
  }

  function distributionPaused() external returns (bool);

  function vaultManager() external returns (IVaultManager);

  function lpStaking() external returns (ILPStaking);

  function fnftStaking() external returns (IFNFTStaking);

  function treasury() external returns (address);

  function allocTotal() external returns (uint256);

  function feeReceivers(uint256) external returns (uint256, address, bool);

  function __FeeDistributor_init(address _vaultManager, address _lpStaking, address _treasury) external;

  function rescueTokens(address token) external;

  function distribute(uint256 vaultId) external;

  function addReceiver(uint256 _allocPoint, address _receiver, bool _isContract) external;

  function initializeVaultReceivers(uint256 _vaultId) external;

  function changeReceiverAlloc(uint256 _idx, uint256 _allocPoint) external;

  function changeReceiverAddress(uint256 _idx, address _address, bool _isContract) external;

  function removeReceiver(uint256 _receiverIdx) external;

  function setTreasuryAddress(address _treasury) external;

  function setLPStakingAddress(address _lpStaking) external;

  function setFNFTStakingAddress(address _inventoryStaking) external;

  function pauseFeeDistribution(bool _pause) external;

  event TreasuryAddressUpdated(address newTreasury);
  event LPStakingAddressUpdated(address newLPStaking);
  event FNFTStakingAddressUpdated(address newFNFTStaking);
  event DistributionPaused(bool paused);
  event FeeReceiverAdded(address receiver, uint256 allocPoint);
  event FeeReceiverAllocUpdated(address receiver, uint256 allocPoint);
  event FeeReceiverAddressUpdated(address oldReceiver, address newReceiver);
  event FeeReceiverRemoved(address receiver);

  error NotVaultManager();
  error OutOfBounds();
  error ZeroAddress();
}