//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./FNFT.sol";
import "./proxy/BeaconUpgradeable.sol";
import "./proxy/BeaconProxy.sol";
import "./interfaces/IFNFTFactory.sol";
import "./interfaces/IFeeDistributor.sol";

contract FNFTFactory is
    OwnableUpgradeable,
    PausableUpgradeable,
    BeaconUpgradeable,
    IFNFTFactory
{
    enum FeeType { GovernanceFee, MaxCuratorFee, SwapFee }
    enum Boundary { Min, Max }

    /// @notice fee exclusion for swaps

    mapping(address => mapping(uint256 => address[])) _vaultsForAsset;    
    
    mapping(address => bool) public override excludedFromFees;

    mapping(uint256 => address) internal vaults;

    address public override feeDistributor;

    address public override WETH;

    address public override priceOracle;

    address public override ifoFactory;

    uint256 public override numVaults;

    uint256 public override swapFee;

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

    /// @notice flash loan fee basis point
    uint256 public override flashLoanFee;

    /// @notice the address who receives auction fees
    address payable public override feeReceiver;

    event UpdatePriceOracle(address _old, address _new);

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

    event UpdateFeeReceiver(address _old, address _new);

    event UpdateFlashLoanFee(uint256 oldFlashLoanFee, uint256 newFlashLoanFee);

    event NewFeeDistributor(address oldDistributor, address newDistributor);

    event FeeExclusion(address target, bool excluded);

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
    error FeeTooHigh();
    error MinBidIncreaseOutOfBounds();
    error MinVotePercentageTooHigh();
    error MaxReserveFactorTooLow();
    error MinReserveFactorTooHigh();
    error ZeroAddressDisallowed();
    error MultiplierTooLow();

    function initialize(address _weth, address _ifoFactory, address _feeDistributor) external initializer {
        __Ownable_init();
        __Pausable_init();
        __BeaconUpgradeable__init(address(new FNFT()));

        WETH = _weth;
        ifoFactory = _ifoFactory;
        feeDistributor = _feeDistributor;
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

        uint256 _vaultId = uint256(keccak256(abi.encodePacked(_nft, _tokenId, numVaults)));
        _vaultsForAsset[_nft][_tokenId].push(fnft);
        vaults[_vaultId] = fnft;
        numVaults++;        

        IERC721(_nft).safeTransferFrom(msg.sender, fnft, _tokenId);
        IFeeDistributor(feeDistributor).initializeSingleVaultReceivers(_vaultId);
        emit FNFTCreated(_nft, fnft, msg.sender, _listPrice, _name, _symbol);
        return fnft;
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

    function setFeeDistributor(address _feeDistributor) public onlyOwner virtual override {
        if (_feeDistributor == address(0)) revert ZeroAddressDisallowed();
        emit NewFeeDistributor(feeDistributor, _feeDistributor);
        feeDistributor = _feeDistributor;
    }

    function setFeeExclusion(address _excludedAddr, bool excluded) public onlyOwner virtual override {
        emit FeeExclusion(_excludedAddr, excluded);
        excludedFromFees[_excludedAddr] = excluded;
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

    function setFlashLoanFee(uint256 _flashLoanFee) external virtual override onlyOwner {
        if (_flashLoanFee > 500) revert FeeTooHigh();
        emit UpdateFlashLoanFee(flashLoanFee, _flashLoanFee);
        flashLoanFee = _flashLoanFee;
    }

    function vaultsForAsset(address assetAddress, uint256 tokenId) external view override virtual returns (address[] memory) {
        return _vaultsForAsset[assetAddress][tokenId];
    }

    function vault(uint256 vaultId) external view override virtual returns (address) {
        return vaults[vaultId];
    }
}
