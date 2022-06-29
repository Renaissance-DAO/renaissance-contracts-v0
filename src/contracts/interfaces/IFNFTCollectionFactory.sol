// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../proxy/IBeacon.sol";
import "./IVaultManager.sol";

interface IFNFTCollectionFactory is IBeacon {
  struct VaultFees {
      bool active;
      uint64 mintFee;
      uint64 randomRedeemFee;
      uint64 targetRedeemFee;
      uint64 randomSwapFee;
      uint64 targetSwapFee;
  }

  // Read functions.
  function vaultManager() external view returns (IVaultManager);
  function eligibilityManager() external view returns (address);
  function isLocked(uint256 id) external view returns (bool);
  function factoryMintFee() external view returns (uint64);
  function factoryRandomRedeemFee() external view returns (uint64);
  function factoryTargetRedeemFee() external view returns (uint64);
  function factoryRandomSwapFee() external view returns (uint64);
  function factoryTargetSwapFee() external view returns (uint64);
  function swapFee() external view returns (uint256);
  function vaultFees(uint256 vaultId) external view returns (uint256, uint256, uint256, uint256, uint256);
  function flashLoanFee() external view returns (uint64);

  // Write functions.
  function __FNFTCollectionFactory_init(address _vaultManager) external;
  function createVault(
      string calldata _name,
      string calldata _symbol,
      address _assetAddress,
      bool is1155,
      bool allowAllItems
  ) external returns (address);
  function setEligibilityManager(address _eligibilityManager) external;
  function setSwapFee(uint256 _swapFee) external;

  function setFactoryFees(
    uint256 _factoryMintFee,
    uint256 _factoryRandomRedeemFee,
    uint256 _factoryTargetRedeemFee,
    uint256 _factoryRandomSwapFee,
    uint256 _factoryTargetSwapFee
  ) external;
  function setVaultFees(
      uint256 vaultId,
      uint256 _mintFee,
      uint256 _randomRedeemFee,
      uint256 _targetRedeemFee,
      uint256 _randomSwapFee,
      uint256 _targetSwapFee
  ) external;
  function disableVaultFees(uint256 vaultId) external;
  function setFlashLoanFee(uint256 _flashLoanFee) external;

  event FeeDistributorUpdated(address oldFeeDistributor, address newFeeDistributor);
  event FeeExclusionUpdated(address target, bool excluded);
  event PriceOracleUpdated(address oldPriceOracle, address newPriceOracle);
  event EligibilityManagerUpdated(address oldEligManager, address newEligManager);
  event VaultCreated(uint256 indexed vaultId, address vaultAddress, address assetAddress);
  event VaultFeesUpdated(uint256 vaultId, uint256 mintFee, uint256 randomRedeemFee, uint256 targetRedeemFee, uint256 randomSwapFee, uint256 targetSwapFee);
  event VaultFeesDisabled(uint256 vaultId);
  event FactoryFeesUpdated(uint256 mintFee, uint256 randomRedeemFee, uint256 targetRedeemFee, uint256 randomSwapFee, uint256 targetSwapFee);
  event FlashLoanFeeUpdated(uint256 oldFlashLoanFee, uint256 newFlashLoanFee);
  event SwapFeeUpdated(uint256 oldSwapFee, uint256 newSwapFee);

  error FeeTooHigh();
  error CallerIsNotVault();
  error ZeroAddress();
}
