//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IFNFTFactory.sol";

contract FNFTSettings is OwnableUpgradeable, IFNFTFactory {
    address public WETH;

    address public priceOracle;

    address public ifoFactory;

    /// @notice the maximum auction length
    uint256 public override maxAuctionLength;

    /// @notice the longest an auction can ever be
    uint256 public constant MAX_MAX_AUCTION_LENGTH = 8 weeks;

    /// @notice the minimum auction length
    uint256 public override minAuctionLength;

    /// @notice the shortest an auction can ever be
    uint256 public constant MIN_MIN_AUCTION_LENGTH = 1 days;

    /// @notice governance fee max
    uint256 public override governanceFee;

    /// @notice 10% fee is max
    uint256 public constant MAX_GOV_FEE = 1000;

    /// @notice max curator fee
    uint256 public override maxCuratorFee;

    /// @notice the % bid increase required for a new bid
    uint256 public override minBidIncrease;

    /// @notice 10% bid increase is max
    uint256 public constant MAX_MIN_BID_INCREASE = 1000;

    /// @notice 1% bid increase is min
    uint256 public constant MIN_MIN_BID_INCREASE = 100;

    /// @notice the % of tokens required to be voting for an auction to start
    uint256 public override minVotePercentage;

    /// @notice the max % increase over the initial
    uint256 public override maxReserveFactor;

    /// @notice the max % decrease from the initial
    uint256 public override minReserveFactor;

    /// @notice minimum size of fNFT-ETH LP pool for TWAP to take effect
    uint256 public override liquidityThreshold;

    /// @notice instant buy allowed if bid > MC * instantBuyMultiplier
    uint256 public override instantBuyMultiplier;

    /// @notice the address who receives auction fees
    address payable public override feeReceiver;

    event UpdatePriceOracle(address _old, address _new);

    event UpdateMaxAuctionLength(uint256 _old, uint256 _new);

    event UpdateMinAuctionLength(uint256 _old, uint256 _new);

    event UpdateGovernanceFee(uint256 _old, uint256 _new);

    event UpdateCuratorFee(uint256 _old, uint256 _new);

    event UpdateMinBidIncrease(uint256 _old, uint256 _new);

    event UpdateMinVotePercentage(uint256 _old, uint256 _new);

    event UpdateMaxReserveFactor(uint256 _old, uint256 _new);

    event UpdateMinReserveFactor(uint256 _old, uint256 _new);

    event UpdateLiquidityThreshold(uint256 _old, uint256 _new);

    event UpdateInstantBuyMultiplier(uint256 _old, uint256 _new);

    event UpdateFeeReceiver(address _old, address _new);

    error MaxAuctionLengthTooHigh();
    error MaxAuctionLengthTooLow();
    error MinAuctionLengthTooHigh();
    error MinAuctionLengthTooLow();
    error GovFeeTooHigh();
    error MinBidIncreaseTooHigh();
    error MinBidIncreaseTooLow();
    error MinVotePercentageTooHigh();
    error MaxReserveFactorTooLow();
    error MinReserveFactorTooHigh();
    error ZeroAddressDisallowed();
    error MultiplierTooLow();

    function initialize(address _weth, address _ifoFactory) external initializer {
        __Ownable_init();

        WETH = _weth;
        ifoFactory = _ifoFactory;
        maxAuctionLength = 2 weeks;
        minAuctionLength = 3 days;
        feeReceiver = payable(msg.sender);
        minReserveFactor = 2000; // 20%
        maxReserveFactor = 50000; // 500%
        minBidIncrease = 500; // 5%
        maxCuratorFee = 1000;
        minVotePercentage = 2500; // 25%
        liquidityThreshold = 15e18; // ~$30,000 USD in ETH
        instantBuyMultiplier = 15; // instant buy allowed if 1.5x MC
    }

    function setPriceOracle(address _newOracle) external onlyOwner {
        emit UpdatePriceOracle(priceOracle, _newOracle);
        priceOracle = _newOracle;
    }

    function setMaxAuctionLength(uint256 _length) external onlyOwner {
        if (_length > MAX_MAX_AUCTION_LENGTH) revert MaxAuctionLengthTooHigh();
        if (_length <= minAuctionLength) revert MaxAuctionLengthTooLow();

        emit UpdateMaxAuctionLength(maxAuctionLength, _length);

        maxAuctionLength = _length;
    }

    function setMinAuctionLength(uint256 _length) external onlyOwner {
        if (_length < MIN_MIN_AUCTION_LENGTH) revert MinAuctionLengthTooLow();
        if (_length >= maxAuctionLength) revert MinAuctionLengthTooHigh();

        emit UpdateMinAuctionLength(minAuctionLength, _length);

        minAuctionLength = _length;
    }

    function setGovernanceFee(uint256 _fee) external onlyOwner {
        if (_fee > MAX_GOV_FEE) revert GovFeeTooHigh();

        emit UpdateGovernanceFee(governanceFee, _fee);

        governanceFee = _fee;
    }

    function setMaxCuratorFee(uint256 _fee) external onlyOwner {
        emit UpdateCuratorFee(governanceFee, _fee);

        maxCuratorFee = _fee;
    }

    function setMinBidIncrease(uint256 _min) external onlyOwner {
        if (_min > MAX_MIN_BID_INCREASE) revert MinBidIncreaseTooHigh();
        if (_min < MIN_MIN_BID_INCREASE) revert MinBidIncreaseTooLow();

        emit UpdateMinBidIncrease(minBidIncrease, _min);

        minBidIncrease = _min;
    }

    function setMinVotePercentage(uint256 _min) external onlyOwner {
        // 10000 is 100%
        if (_min > 10000) revert MinVotePercentageTooHigh();

        emit UpdateMinVotePercentage(minVotePercentage, _min);

        minVotePercentage = _min;
    }

    function setMaxReserveFactor(uint256 _factor) external onlyOwner {
        if (_factor <= minReserveFactor) revert MaxReserveFactorTooLow();

        emit UpdateMaxReserveFactor(maxReserveFactor, _factor);

        maxReserveFactor = _factor;
    }

    function setMinReserveFactor(uint256 _factor) external onlyOwner {
        if (_factor >= maxReserveFactor) revert MinReserveFactorTooHigh();

        emit UpdateMinReserveFactor(minReserveFactor, _factor);

        minReserveFactor = _factor;
    }

    function setLiquidityThreshold(uint256 _threshold) external onlyOwner {
        emit UpdateLiquidityThreshold(liquidityThreshold, _threshold);

        liquidityThreshold = _threshold;
    }

    function setInstantBuyMultiplier(uint256 _multiplier) external onlyOwner {
        if (_multiplier < 10) revert MultiplierTooLow();

        emit UpdateInstantBuyMultiplier(instantBuyMultiplier, _multiplier);

        instantBuyMultiplier = _multiplier;
    }

    function setFeeReceiver(address payable _receiver) external onlyOwner {
        if (_receiver == address(0)) revert ZeroAddressDisallowed();

        emit UpdateFeeReceiver(feeReceiver, _receiver);

        feeReceiver = _receiver;
    }
}
