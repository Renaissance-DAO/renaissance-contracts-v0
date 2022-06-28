//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IPriceOracle} from "./IPriceOracle.sol";
import {IWETH} from "./IWETH.sol";
import {IVaultManager} from "./IVaultManager.sol";

interface IFNFTSingleFactory {
    enum FeeType { GovernanceFee, MaxCuratorFee, SwapFee }
    enum Boundary { Min, Max }

    function vaultManager() external view returns (IVaultManager);

    function swapFee() external view returns (uint256);

    function maxAuctionLength() external view returns (uint256);

    function minAuctionLength() external view returns (uint256);

    function maxCuratorFee() external view returns (uint256);

    function governanceFee() external view returns (uint256);

    function minBidIncrease() external view returns (uint256);

    function minVotePercentage() external view returns (uint256);

    function maxReserveFactor() external view returns (uint256);

    function minReserveFactor() external view returns (uint256);

    function liquidityThreshold() external view returns (uint256);

    function instantBuyMultiplier() external view returns (uint256);

    function __FNFTSingleFactory_init(address _vaultManager) external;

    function createVault(
        string memory _name,
        string memory _symbol,
        address _nft,
        uint256 _tokenId,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee
    ) external returns (address);

    function togglePaused() external;

    function flashLoanFee() external view returns (uint256);

    function setAuctionLength(Boundary boundary, uint256 _length) external;

    function setFee(FeeType feeType, uint256 _fee) external;

    function setMinBidIncrease(uint256 _min) external;

    function setMinVotePercentage(uint256 _min) external;

    function setReserveFactor(Boundary boundary, uint256 _factor) external;

    function setLiquidityThreshold(uint256 _threshold) external;

    function setInstantBuyMultiplier(uint256 _multiplier) external;

    function setFlashLoanFee(uint256 fee) external;

    event UpdateMaxAuctionLength(uint256 _old, uint256 _new);
    event UpdateMinAuctionLength(uint256 _old, uint256 _new);
    event UpdateGovernanceFee(uint256 _old, uint256 _new);
    event UpdateCuratorFee(uint256 _old, uint256 _new);
    event UpdateSwapFee(uint256 _old, uint256 _new);
    event UpdateMinBidIncrease(uint256 _old, uint256 _new);
    event UpdateMinVotePercentage(uint256 _old, uint256 _new);
    event UpdateMaxReserveFactor(uint256 _old, uint256 _new);
    event UpdateMinReserveFactor(uint256 _old, uint256 _new);
    event UpdateLiquidityThreshold(uint256 _old, uint256 _new);
    event UpdateInstantBuyMultiplier(uint256 _old, uint256 _new);
    event UpdateFlashLoanFee(uint256 oldFlashLoanFee, uint256 newFlashLoanFee);
    event FeeExclusion(address target, bool excluded);
    event FNFTSingleCreated(
        address indexed token,
        address fnftSingle,
        address creator,

        uint256 price,
        string name,
        string symbol
    );

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
