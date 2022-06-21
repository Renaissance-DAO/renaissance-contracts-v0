//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IVaultManager {     
    function excludedFromFees(address) external view returns (bool);
    function feeDistributor() external view returns (address);
    function WETH() external view returns (address);
    function priceOracle() external view returns (address);
    function ifoFactory() external view returns (address);
    function numVaults() external view returns (uint256);
    function feeReceiver() external view returns (address payable);
    function togglePaused() external;
    function setPriceOracle(address _newOracle) external;
    function setFeeDistributor(address _feeDistributor) external;
    function setFeeExclusion(address _excludedAddr, bool excluded) external;
    function setFeeReceiver(address payable _receiver) external;
    function vaultsForAsset(address assetAddress, uint256 tokenId) external view returns (address[] memory);
    function vault(uint256 vaultId) external view returns (address);
    function vaults(uint256) external view returns (address);

    event UpdatePriceOracle(address _old, address _new);
    event UpdateFeeReceiver(address _old, address _new);
    event NewFeeDistributor(address oldDistributor, address newDistributor);
    event FeeExclusion(address target, bool excluded);

    error MaxAuctionLengthOutOfBounds();
    error MinAuctionLengthOutOfBounds();
    error FeeTooHigh();
    error MinBidIncreaseOutOfBounds();
    error MinVotePercentageTooHigh();
    error MaxReserveFactorTooLow();
    error MinReserveFactorTooHigh();
    error ZeroAddressDisallowed();
    error MultiplierTooLow();
}
