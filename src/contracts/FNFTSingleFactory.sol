//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./interfaces/IFNFTSingleFactory.sol";
import "./interfaces/IOwnable.sol";
import "./interfaces/IVaultManager.sol";
import "./proxy/BeaconProxy.sol";
import "./proxy/BeaconUpgradeable.sol";
import "./util/Pausable.sol";

contract FNFTSingleFactory is
    IFNFTSingleFactory,
    Pausable,
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

    function __FNFTSingleFactory_init(address _vaultManager, address _fnftSingle) external override initializer {
        if (_vaultManager == address(0)) revert ZeroAddress();
        if (_fnftSingle == address(0)) revert ZeroAddress();
        __Pausable_init();
        __BeaconUpgradeable__init(_fnftSingle);
        vaultManager = IVaultManager(_vaultManager);
        maxAuctionLength = 2 weeks;
        minAuctionLength = 3 days;
        minReserveFactor = 2000; // 20%
        maxReserveFactor = 50000; // 500%
        minBidIncrease = 500; // 5%
        maxCuratorFee = 1000;
        minVotePercentage = 2500; // 25%
        liquidityThreshold = 30e18; // ~$30,000 USD in ETH
        instantBuyMultiplier = 15; // instant buy allowed if 1.5x MC
    }

    /// @notice the function to mint a fnftSingle
    /// @param _nft the ERC721 token address
    /// @param _tokenId the uint256 id of the token
    /// @param _supply vault token supply
    /// @param _listPrice the initial price of the NFT
    /// @param _fee curator fee
    /// @param _name the desired name of the vault
    /// @param _symbol the desired symbol of the vault
    /// @return vaultId
    function createVault(
        address _nft,
        uint256 _tokenId,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee,
        string memory _name,
        string memory _symbol
    ) external virtual override returns (address) {
        onlyOwnerIfPaused(0);
        if (childImplementation() == address(0)) revert ZeroAddress();
        IVaultManager _vaultManager = vaultManager;
        address fnftSingle = _deployVault(
            _name,
            _symbol,
            _nft,
            _tokenId,
            _supply,
            _listPrice,
            _fee
        );
        uint vaultId = _vaultManager.addVault(fnftSingle);
        IERC721(_nft).safeTransferFrom(msg.sender, fnftSingle, _tokenId);

        emit VaultCreated(vaultId, msg.sender, fnftSingle, _nft, _tokenId, _supply, _listPrice, _name, _symbol);
        return fnftSingle;
    }

    function setFactoryFees(
        uint256 _governanceFee,
        uint256 _maxCuratorFee,
        uint256 _flashLoanFee,
        uint256 _swapFee
    ) public virtual override onlyOwner {
        if (_governanceFee > 1000) revert FeeTooHigh();
        if (_swapFee > 500) revert FeeTooHigh();
        if (_flashLoanFee > 500) revert FeeTooHigh();
        if (_maxCuratorFee > 2000) revert FeeTooHigh();

        governanceFee = _governanceFee;
        maxCuratorFee = _maxCuratorFee;
        flashLoanFee = _flashLoanFee;
        swapFee = _swapFee;

        emit FactoryFeesUpdated(_governanceFee, _maxCuratorFee, _flashLoanFee, _swapFee);
    }

    function setFactoryThresholds(
        uint256 _maxAuctionLength,
        uint256 _minAuctionLength,
        uint256 _minReserveFactor,
        uint256 _maxReserveFactor,
        uint256 _minBidIncrease,
        uint256 _minVotePercentage,
        uint256 _liquidityThreshold,
        uint256 _instantBuyMultiplier
    ) public virtual override onlyOwner {
        if (_minAuctionLength < 1 days || _minAuctionLength >= maxAuctionLength) revert MinAuctionLengthOutOfBounds();
        if (_maxAuctionLength > 8 weeks || _maxAuctionLength <= minAuctionLength) revert MaxAuctionLengthOutOfBounds();

        if (_minReserveFactor >= maxReserveFactor) revert MinReserveFactorTooHigh();
        if (_maxReserveFactor <= minReserveFactor) revert MaxReserveFactorTooLow();

        if (_minBidIncrease > 1000 || _minBidIncrease < 100) revert MinBidIncreaseOutOfBounds();
        if (_minVotePercentage > 10000) revert MinVotePercentageTooHigh();

        if (_instantBuyMultiplier < 10) revert MultiplierTooLow();

        maxAuctionLength = _maxAuctionLength;
        minAuctionLength = _minAuctionLength;
        minReserveFactor = _minReserveFactor;
        maxReserveFactor = _maxReserveFactor;
        minBidIncrease = _minBidIncrease;
        minVotePercentage = _minVotePercentage;
        liquidityThreshold = _liquidityThreshold;
        instantBuyMultiplier = _instantBuyMultiplier;

        emit FactoryThresholdsUpdated(
            _maxAuctionLength,
            _minAuctionLength,
            _minReserveFactor,
            _maxReserveFactor,
            _minBidIncrease,
            _minVotePercentage,
            _liquidityThreshold,
            _instantBuyMultiplier
        );
    }

    /// @dev 0x86a777ab == FNFTSingle.__FNFTSingle_init.selector
    function _deployVault(
        string memory _name,
        string memory _symbol,
        address _nft,
        uint256 _tokenId,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee
    ) internal returns (address) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            0x86a777ab,
            _name,
            _symbol,
            msg.sender,
            _nft,
            _tokenId,
            _supply,
            _listPrice,
            _fee
        );

        address newBeaconProxy = address(new BeaconProxy(address(this), _initializationCalldata));

        // Owner for administrative functions.
        IOwnable(newBeaconProxy).transferOwnership(owner());

        return newBeaconProxy;
    }
}
