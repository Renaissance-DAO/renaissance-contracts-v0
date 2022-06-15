// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "../proxy/IBeacon.sol";

interface IFNFTCollectionFactory is IBeacon {
  // Read functions.
  function numVaults() external view returns (uint256);
  function zapContract() external view returns (address);
  function feeDistributor() external view returns (address);
  function eligibilityManager() external view returns (address);
  function vault(uint256 vaultId) external view returns (address);
  function priceOracle() external view returns (address);
  function WETH() external view returns (address);
  function allVaults() external view returns (address[] memory);
  function vaultsForAsset(address asset) external view returns (address[] memory);
  function isLocked(uint256 id) external view returns (bool);
  function excludedFromFees(address addr) external view returns (bool);
  function factoryMintFee() external view returns (uint64);
  function factoryRandomRedeemFee() external view returns (uint64);
  function factoryTargetRedeemFee() external view returns (uint64);
  function factoryRandomSwapFee() external view returns (uint64);
  function factoryTargetSwapFee() external view returns (uint64);
  function swapFee() external view returns (uint64);
  function vaultFees(uint256 vaultId) external view returns (uint256, uint256, uint256, uint256, uint256);
  function flashLoanFee() external view returns (uint64);

  event NewFeeDistributor(address oldDistributor, address newDistributor);
  event NewZapContract(address oldZap, address newZap);
  event FeeExclusion(address target, bool excluded);
  event UpdatePriceOracle(address oldPriceOracle, address newPriceOracle);
  event NewEligibilityManager(address oldEligManager, address newEligManager);
  event NewVault(uint256 indexed vaultId, address vaultAddress, address assetAddress);
  event UpdateVaultFees(uint256 vaultId, uint256 mintFee, uint256 randomRedeemFee, uint256 targetRedeemFee, uint256 randomSwapFee, uint256 targetSwapFee);
  event DisableVaultFees(uint256 vaultId);
  event UpdateFactoryFees(uint256 mintFee, uint256 randomRedeemFee, uint256 targetRedeemFee, uint256 randomSwapFee, uint256 targetSwapFee);
  event UpdateFlashLoanFee(uint256 oldFlashLoanFee, uint256 newFlashLoanFee);  
  event UpdateSwapFee(uint256 _old, uint256 _new);
  
  // Write functions.
  function __FNFTCollectionFactory_init(address _weth, address _feeDistributor) external;  
  function createVault(
      string calldata name,
      string calldata symbol,
      address _assetAddress,
      bool is1155,
      bool allowAllItems
  ) external returns (uint256);
  function setFeeDistributor(address _feeDistributor) external;
  function setEligibilityManager(address _eligibilityManager) external;
  function setZapContract(address _zapContract) external;
  function setFeeExclusion(address _excludedAddr, bool excluded) external;
  function setSwapFee(uint256 _swapFee) external;

  function setFactoryFees(
    uint256 mintFee,
    uint256 randomRedeemFee,
    uint256 targetRedeemFee,
    uint256 randomSwapFee,
    uint256 targetSwapFee
  ) external;
  function setVaultFees(
      uint256 vaultId,
      uint256 mintFee,
      uint256 randomRedeemFee,
      uint256 targetRedeemFee,
      uint256 randomSwapFee,
      uint256 targetSwapFee
  ) external;
  function disableVaultFees(uint256 vaultId) external;
  function setFlashLoanFee(uint256 fee) external;
  function setPriceOracle(address _newOracle) external;
}
