//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./FNFTSingle.sol";
import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IFNFTSingleFactory.sol";
import "./interfaces/IVaultManager.sol";
import "./proxy/BeaconProxy.sol";
import "./proxy/BeaconUpgradeable.sol";

contract FNFTSingleFactory is
    IFNFTSingleFactory,
    OwnableUpgradeable,
    PausableUpgradeable,
    BeaconUpgradeable
{
    IVaultManager public override vaultManager;

    /// @notice flash loan fee basis point
    uint256 public override flashLoanFee;

    /// @notice governance fee max
    uint256 public override governanceFee;

    /// @notice instant buy allowed if bid > MC * instantBuyMultiplier
    uint256 public override instantBuyMultiplier;

    /// @notice minimum size of FNFT-ETH LP pool for TWAP to take effect
    uint256 public override liquidityThreshold;

    /// @notice the maximum auction length
    uint256 public override maxAuctionLength;

    /// @notice max curator fee
    uint256 public override maxCuratorFee;

    /// @notice the max % increase over the initial
    uint256 public override maxReserveFactor;

    /// @notice the minimum auction length
    uint256 public override minAuctionLength;

    /// @notice the % bid increase required for a new bid
    uint256 public override minBidIncrease;

    /// @notice the max % decrease from the initial
    uint256 public override minReserveFactor;

    /// @notice the % of tokens required to be voting for an auction to start
    uint256 public override minVotePercentage;

    /// @notice fee exclusion for swaps
    uint256 public override swapFee;

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

    function setAuctionLength(Boundary boundary, uint256 _auctionLength) external override onlyOwner {
        if (boundary == Boundary.Min) {
            if (_auctionLength < 1 days || _auctionLength >= maxAuctionLength) revert MinAuctionLengthOutOfBounds();
            emit MinAuctionLengthUpdated(minAuctionLength, _auctionLength);
            minAuctionLength = _auctionLength;
        } else if (boundary == Boundary.Max) {
            if (_auctionLength > 8 weeks || _auctionLength <= minAuctionLength) revert MaxAuctionLengthOutOfBounds();
            emit MaxAuctionLengthUpdated(maxAuctionLength, _auctionLength);
            maxAuctionLength = _auctionLength;
        }
    }

    function setFee(FeeType feeType, uint256 _fee) external override onlyOwner {
        if (feeType == FeeType.GovernanceFee) {
            if (_fee > 1000) revert FeeTooHigh();
            emit GovernanceFeeUpdated(governanceFee, _fee);
            governanceFee = _fee;
        } else if (feeType == FeeType.MaxCuratorFee) {
            emit CuratorFeeUpdated(maxCuratorFee, _fee);
            maxCuratorFee = _fee;
        } else if (feeType == FeeType.SwapFee) {
            if (_fee > 500) revert FeeTooHigh();
            emit SwapFeeUpdated(swapFee, _fee);
            swapFee = _fee;
        }
    }

    function setFlashLoanFee(uint256 _flashLoanFee) external virtual override onlyOwner {
        if (_flashLoanFee > 500) revert FeeTooHigh();
        emit FlashLoanFeeUpdated(flashLoanFee, _flashLoanFee);
        flashLoanFee = _flashLoanFee;
    }

    function setInstantBuyMultiplier(uint256 _instantBuyMultiplier) external override onlyOwner {
        if (_instantBuyMultiplier < 10) revert MultiplierTooLow();

        emit InstantBuyMultiplierUpdated(instantBuyMultiplier, _instantBuyMultiplier);

        instantBuyMultiplier = _instantBuyMultiplier;
    }

    function setLiquidityThreshold(uint256 _liquidityThreshold) external override onlyOwner {
        emit LiquidityThresholdUpdated(liquidityThreshold, _liquidityThreshold);

        liquidityThreshold = _liquidityThreshold;
    }

    function setMinBidIncrease(uint256 _minBidIncrease) external override onlyOwner {
        if (_minBidIncrease > 1000 || _minBidIncrease < 100) revert MinBidIncreaseOutOfBounds();

        emit MinBidIncreaseUpdated(minBidIncrease, _minBidIncrease);

        minBidIncrease = _minBidIncrease;
    }

    function setMinVotePercentage(uint256 _minVotePercentage) external override onlyOwner {
        // 10000 is 100%
        if (_minVotePercentage > 10000) revert MinVotePercentageTooHigh();

        emit MinVotePercentageUpdated(minVotePercentage, _minVotePercentage);

        minVotePercentage = _minVotePercentage;
    }

    function setReserveFactor(Boundary boundary, uint256 _reserveFactor) external override onlyOwner {
        if (boundary == Boundary.Min) {
            if (_reserveFactor >= maxReserveFactor) revert MinReserveFactorTooHigh();
            emit MinReserveFactorUpdated(minReserveFactor, _reserveFactor);
            minReserveFactor = _reserveFactor;
        } else if (boundary == Boundary.Max) {
            if (_reserveFactor <= minReserveFactor) revert MaxReserveFactorTooLow();
            emit MaxReserveFactorUpdated(maxReserveFactor, _reserveFactor);
            maxReserveFactor = _reserveFactor;
        }
    }

    function togglePaused() external override onlyOwner {
        paused() ? _unpause() : _pause();
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
