//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./FNFTSingle.sol";
import "./proxy/BeaconUpgradeable.sol";
import "./proxy/BeaconProxy.sol";
import "./interfaces/IFNFTSingleFactory.sol";
import "./interfaces/IVaultManager.sol";
import "./interfaces/IFeeDistributor.sol";

contract FNFTSingleFactory is
    IFNFTSingleFactory,
    OwnableUpgradeable,
    PausableUpgradeable,
    BeaconUpgradeable
{
    IVaultManager public override vaultManager;

    /// @notice fee exclusion for swaps
    uint256 public override swapFee;

    /// @notice governance fee max
    uint256 public override governanceFee;

    /// @notice max curator fee
    uint256 public override maxCuratorFee;

    /// @notice flash loan fee basis point
    uint256 public override flashLoanFee;

    /// @notice the maximum auction length
    uint256 public override maxAuctionLength;

    /// @notice the minimum auction length
    uint256 public override minAuctionLength;

    /// @notice the % bid increase required for a new bid
    uint256 public override minBidIncrease;

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

    function __FNFTSingleFactory_init(address _vaultManager) external override initializer {
        __Ownable_init();
        __Pausable_init();
        __BeaconUpgradeable__init(address(new FNFTSingle()));

        vaultManager = IVaultManager(_vaultManager);
        maxAuctionLength = 2 weeks;
        minAuctionLength = 3 days;
        minReserveFactor = 2000; // 20%
        maxReserveFactor = 50000; // 500%
        minBidIncrease = 500; // 5%
        maxCuratorFee = 1000;
        minVotePercentage = 2500; // 25%
        liquidityThreshold = 15e18; // ~$30,000 USD in ETH
        instantBuyMultiplier = 15; // instant buy allowed if 1.5x MC
    }

    /// @notice the function to mint a fnftSingle
    /// @param _name the desired name of the vault
    /// @param _symbol the desired symbol of the vault
    /// @param _nft the ERC721 token address
    /// @param _tokenId the uint256 ID of the token
    /// @param _listPrice the initial price of the NFT
    /// @return the ID of the vault
    function createVault(
        string memory _name,
        string memory _symbol,
        address _nft,
        uint256 _tokenId,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee
    ) external override whenNotPaused returns (address) {
        address fnftSingle = deployVault(
            _name,
            _symbol,
            _nft,
            _tokenId,
            _supply,
            _listPrice,
            _fee
        );
        IVaultManager _vaultManager = vaultManager;
        _vaultManager.addVault(fnftSingle);
        IERC721(_nft).safeTransferFrom(msg.sender, fnftSingle, _tokenId);

        emit FNFTSingleCreated(_nft, fnftSingle, msg.sender, _listPrice, _name, _symbol);
        return fnftSingle;
    }

    function togglePaused() external override onlyOwner {
        paused() ? _unpause() : _pause();
    }

    function setAuctionLength(Boundary boundary, uint256 _length) external override onlyOwner {
        if (boundary == Boundary.Min) {
            if (_length < 1 days || _length >= maxAuctionLength) revert MinAuctionLengthOutOfBounds();
            emit UpdateMinAuctionLength(minAuctionLength, _length);
            minAuctionLength = _length;
        } else if (boundary == Boundary.Max) {
            if (_length > 8 weeks || _length <= minAuctionLength) revert MaxAuctionLengthOutOfBounds();
            emit UpdateMaxAuctionLength(maxAuctionLength, _length);
            maxAuctionLength = _length;
        }
    }

    function setFee(FeeType feeType, uint256 _fee) external override onlyOwner {
        if (feeType == FeeType.GovernanceFee) {
            if (_fee > 1000) revert FeeTooHigh();
            emit UpdateGovernanceFee(governanceFee, _fee);
            governanceFee = _fee;
        } else if (feeType == FeeType.MaxCuratorFee) {
            emit UpdateCuratorFee(maxCuratorFee, _fee);
            maxCuratorFee = _fee;
        } else if (feeType == FeeType.SwapFee) {
            if (_fee > 500) revert FeeTooHigh();
            emit UpdateSwapFee(swapFee, _fee);
            swapFee = _fee;
        }
    }

    function setMinBidIncrease(uint256 _min) external override onlyOwner {
        if (_min > 1000 || _min < 100) revert MinBidIncreaseOutOfBounds();

        emit UpdateMinBidIncrease(minBidIncrease, _min);

        minBidIncrease = _min;
    }

    function setMinVotePercentage(uint256 _min) external override onlyOwner {
        // 10000 is 100%
        if (_min > 10000) revert MinVotePercentageTooHigh();

        emit UpdateMinVotePercentage(minVotePercentage, _min);

        minVotePercentage = _min;
    }

    function setReserveFactor(Boundary boundary, uint256 _factor) external override onlyOwner {
        if (boundary == Boundary.Min) {
            if (_factor >= maxReserveFactor) revert MinReserveFactorTooHigh();
            emit UpdateMinReserveFactor(minReserveFactor, _factor);
            minReserveFactor = _factor;
        } else if (boundary == Boundary.Max) {
            if (_factor <= minReserveFactor) revert MaxReserveFactorTooLow();
            emit UpdateMaxReserveFactor(maxReserveFactor, _factor);
            maxReserveFactor = _factor;
        }
    }

    function setLiquidityThreshold(uint256 _threshold) external override onlyOwner {
        emit UpdateLiquidityThreshold(liquidityThreshold, _threshold);

        liquidityThreshold = _threshold;
    }

    function setInstantBuyMultiplier(uint256 _multiplier) external override onlyOwner {
        if (_multiplier < 10) revert MultiplierTooLow();

        emit UpdateInstantBuyMultiplier(instantBuyMultiplier, _multiplier);

        instantBuyMultiplier = _multiplier;
    }

    function setFlashLoanFee(uint256 _flashLoanFee) external virtual override onlyOwner {
        if (_flashLoanFee > 500) revert FeeTooHigh();
        emit UpdateFlashLoanFee(flashLoanFee, _flashLoanFee);
        flashLoanFee = _flashLoanFee;
    }

    function deployVault(
        string memory _name,
        string memory _symbol,
        address _nft,
        uint256 _tokenId,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee
    ) internal returns (address) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTSingle.__FNFTSingle_init.selector,
            _name,
            _symbol,
            msg.sender,
            _nft,
            _tokenId,
            _supply,
            _listPrice,
            _fee
        );

        return address(new BeaconProxy(address(this), _initializationCalldata));
    }
}
