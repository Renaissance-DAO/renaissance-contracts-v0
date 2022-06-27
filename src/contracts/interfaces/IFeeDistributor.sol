// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./IVaultManager.sol";
import "./ILPStaking.sol";
import "./IInventoryStaking.sol";

interface IFeeDistributor {

  struct FeeReceiver {
    uint256 allocPoint;
    address receiver;
    bool isContract;
  }

  function vaultManager() external returns (IVaultManager);
  function lpStaking() external returns (ILPStaking);
  function inventoryStaking() external returns (IInventoryStaking);
  function treasury() external returns (address);
  function allocTotal() external returns (uint256);

  // Write functions.
  function __FeeDistributor__init__(address _vaultManager, address _lpStaking, address _treasury) external;
  function rescueTokens(address token) external;
  function distribute(uint256 vaultId) external;
  function addReceiver(uint256 _allocPoint, address _receiver, bool _isContract) external;
  function initializeVaultReceivers(uint256 _vaultId) external;

  function changeReceiverAlloc(uint256 _idx, uint256 _allocPoint) external;
  function changeReceiverAddress(uint256 _idx, address _address, bool _isContract) external;
  function removeReceiver(uint256 _receiverIdx) external;

  // Configuration functions.
  function setTreasuryAddress(address _treasury) external;
  function setLPStakingAddress(address _lpStaking) external;
  function setInventoryStakingAddress(address _inventoryStaking) external;
  function setVaultManager(address _vaultManager) external;
}