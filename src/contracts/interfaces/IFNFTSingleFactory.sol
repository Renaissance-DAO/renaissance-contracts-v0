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

    function setFactoryFees(
        uint256 _governanceFee,
        uint256 _maxCuratorFee,
        uint256 _flashLoanFee,
        uint256 _swapFee
    ) external;

    function setFactoryThresholds(
        uint256 _maxAuctionLength,
        uint256 _minAuctionLength,
        uint256 _minReserveFactor,
        uint256 _maxReserveFactor,
        uint256 _minBidIncrease,
        uint256 _minVotePercentage,
        uint256 _liquidityThreshold
    ) external;

    function setInstantBuyMultiplier(uint256 _instantBuyMultiplier) external;

    event MaxAuctionLengthUpdated(uint256 oldMaxAuctionLength, uint256 newMaxAuctionLength);
    event MinAuctionLengthUpdated(uint256 oldMinAuctionLength, uint256 newMinAuctionLength);
    event GovernanceFeeUpdated(uint256 oldGovernanceFee, uint256 newGovernanceFee);
    event CuratorFeeUpdated(uint256 oldCuratorFee, uint256 newCuratorFee);
    event FactoryFeesUpdated(uint256 governanceFee, uint256 maxCuratorFee, uint256 flashLoanFee, uint256 swapFee);
    event FactoryThresholdsUpdated(
        uint256 maxAuctionLength,
        uint256 minAuctionLength,
        uint256 minReserveFactor,
        uint256 maxReserveFactor,
        uint256 minBidIncrease,
        uint256 minVotePercentage,
        uint256 liquidityThreshold
    );
    event SwapFeeUpdated(uint256 oldSwapFee, uint256 newSwapFee);
    event MinBidIncreaseUpdated(uint256 oldMinBidIncrease, uint256 newMinBidIncrease);
    event MinVotePercentageUpdated(uint256 oldMinVotePercentage, uint256 newMinVotePercentage);
    event MaxReserveFactorUpdated(uint256 oldMaxReserveFactor, uint256 newMaxReserveFactor);
    event MinReserveFactorUpdated(uint256 oldMinReserveFactor, uint256 newMinReserveFactor);
    event LiquidityThresholdUpdated(uint256 oldLiquidityThreshold, uint256 newLiquidityThreshold);
    event InstantBuyMultiplierUpdated(uint256 oldInstantBuyMultiplier, uint256 newInstantBuyMultiplier);
    event FlashLoanFeeUpdated(uint256 oldFlashLoanFee, uint256 newFlashLoanFee);
    event FeeExclusionUpdated(address target, bool excluded);
    event FNFTSingleCreated(
        address indexed token,
        address fnftSingle,
        address creator,

        uint256 price,
        string name,
        string symbol
    );

    error FeeTooHigh();
    error MaxAuctionLengthOutOfBounds();
    error MinAuctionLengthOutOfBounds();
    error MinBidIncreaseOutOfBounds();
    error MinReserveFactorTooHigh();
    error MaxReserveFactorTooLow();
    error MinVotePercentageTooHigh();
    error MultiplierTooLow();
    error ZeroAddress();
}
