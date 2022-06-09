//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./FNFT.sol";
import "./proxy/BeaconUpgradeable.sol";
import "./proxy/BeaconProxy.sol";
import "./interfaces/IFNFTFactory.sol";

contract FNFTFactory is
    OwnableUpgradeable,
    PausableUpgradeable,
    BeaconUpgradeable,
    IFNFTFactory
{
    enum FeeType { GovernanceFee, MaxCuratorFee }
    enum Boundary { Min, Max }

    /// @notice a mapping of fNFT ids (see getFnftId) to the address of the fNFT contract
    mapping(bytes32 => address) public fnfts;

    address public WETH;

    address public priceOracle;

    address public ifoFactory;

    /// @notice the maximum auction length
    uint256 public override maxAuctionLength;

    /// @notice the minimum auction length
    uint256 public override minAuctionLength;

    /// @notice governance fee max
    uint256 public override governanceFee;

    /// @notice max curator fee
    uint256 public override maxCuratorFee;

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

    event FNFTCreated(
        address indexed token,
        address FNFT,
        address creator,

        uint256 price,
        string name,
        string symbol
    );

    error MaxAuctionLengthOutOfBounds();
    error MinAuctionLengthOutOfBounds();
    error GovFeeTooHigh();
    error MinBidIncreaseOutOfBounds();
    error MinVotePercentageTooHigh();
    error MaxReserveFactorTooLow();
    error MinReserveFactorTooHigh();
    error ZeroAddressDisallowed();
    error MultiplierTooLow();

    function initialize(address _weth, address _ifoFactory) external initializer {
        __Ownable_init();
        __Pausable_init();
        __BeaconUpgradeable__init(address(new FNFT()));

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

    /// @notice the function to mint a fNFT
    /// @param _name the desired name of the vault
    /// @param _symbol the desired symbol of the vault
    /// @param _nft the ERC721 token address
    /// @param _tokenId the uint256 ID of the token
    /// @param _listPrice the initial price of the NFT
    /// @return the ID of the vault
    function mint(
        string memory _name,
        string memory _symbol,
        address _nft,
        uint256 _tokenId,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee
    ) external whenNotPaused returns (address) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFT.initialize.selector,
            msg.sender,
            _nft,
            _tokenId,
            _supply,
            _listPrice,
            _fee,
            _name,
            _symbol
        );

        address fnft = address(new BeaconProxy(address(this), _initializationCalldata));

        bytes32 fnftId = getFNFTId(_nft, _tokenId);

        emit FNFTCreated(_nft, fnft, msg.sender, _listPrice, _name, _symbol);

        fnfts[fnftId] = fnft;

        IERC721(_nft).safeTransferFrom(msg.sender, fnft, _tokenId);
        return fnft;
    }

    function getFNFTId(address nftContract, uint256 tokenId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftContract, tokenId));
    }

    function togglePaused() external onlyOwner {
        paused() ? _unpause() : _pause();
    }

    function setPriceOracle(address _newOracle) external onlyOwner {
        emit UpdatePriceOracle(priceOracle, _newOracle);
        priceOracle = _newOracle;
    }

    function setAuctionLength(Boundary boundary, uint256 _length) external onlyOwner {
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

    function setFee(FeeType feeType, uint256 _fee) external onlyOwner {
        if (feeType == FeeType.GovernanceFee) {
            if (_fee > 1000) revert GovFeeTooHigh();
            emit UpdateGovernanceFee(governanceFee, _fee);
            governanceFee = _fee;
        } else if (feeType == FeeType.MaxCuratorFee) {
            emit UpdateCuratorFee(maxCuratorFee, _fee);
            maxCuratorFee = _fee;
        }
    }

    function setMinBidIncrease(uint256 _min) external onlyOwner {
        if (_min > 1000 || _min < 100) revert MinBidIncreaseOutOfBounds();

        emit UpdateMinBidIncrease(minBidIncrease, _min);

        minBidIncrease = _min;
    }

    function setMinVotePercentage(uint256 _min) external onlyOwner {
        // 10000 is 100%
        if (_min > 10000) revert MinVotePercentageTooHigh();

        emit UpdateMinVotePercentage(minVotePercentage, _min);

        minVotePercentage = _min;
    }

    function setReserveFactor(Boundary boundary, uint256 _factor) external onlyOwner {
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
