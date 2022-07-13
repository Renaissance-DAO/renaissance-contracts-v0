// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC3156FlashBorrowerUpgradeable.sol";

import "./IEligibility.sol";
import "./IFNFTCollectionFactory.sol";
import "./IVaultManager.sol";
import "../token/ERC20Upgradeable.sol";

interface IFNFTCollection is IERC20Upgradeable {
    enum AuctionState { Inactive, Live, Ended }

    struct Auction {
        uint256 livePrice;
        uint256 end;
        AuctionState state;
        address winning;
    }

    function vaultManager() external view returns (IVaultManager);

    function curator() external view returns (address);

    function assetAddress() external view returns (address);

    function factory() external view returns (IFNFTCollectionFactory);

    function eligibilityStorage() external view returns (IEligibility);

    function is1155() external view returns (bool);

    function allowAllItems() external view returns (bool);

    function enableMint() external view returns (bool);

    function enableRandomRedeem() external view returns (bool);

    function enableTargetRedeem() external view returns (bool);

    function enableRandomSwap() external view returns (bool);

    function enableTargetSwap() external view returns (bool);

    function enableBid() external view returns (bool);

    function auctionLength() external view returns (uint256);

    function quantity1155(uint256) external view returns (uint256);

    function vaultId() external view returns (uint256);

    function nftIdAt(uint256 holdingsIndex) external view returns (uint256);

    function allHoldings() external view returns (uint256[] memory);

    function totalHoldings() external view returns (uint256);

    function mintFee() external view returns (uint256);

    function randomRedeemFee() external view returns (uint256);

    function targetRedeemFee() external view returns (uint256);

    function randomSwapFee() external view returns (uint256);

    function targetSwapFee() external view returns (uint256);

    function vaultFees() external view returns (uint256, uint256, uint256, uint256, uint256);

    function shutdown(address recipient) external;

    function version() external returns (string memory);

    function __FNFTCollection_init(
        string calldata _name,
        string calldata _symbol,
        address _curator,
        address _assetAddress,
        bool _is1155,
        bool _allowAllItems
    ) external;

    function finalizeVault() external;

    function setVaultMetadata(
        string calldata name_,
        string calldata symbol_
    ) external;

    function setVaultFeatures(
        bool _enableMint,
        bool _enableRandomRedeem,
        bool _enableTargetRedeem,
        bool _enableRandomSwap,
        bool _enableTargetSwap,
        bool _enableBid
    ) external;

    function setFees(
        uint256 _mintFee,
        uint256 _randomRedeemFee,
        uint256 _targetRedeemFee,
        uint256 _randomSwapFee,
        uint256 _targetSwapFee
    ) external;

    function setAuctionLength(uint256 _auctionLength) external;

    function disableVaultFees() external;

    // This function allows for an easy setup of any eligibility module contract from the EligibilityManager.
    // It takes in ABI encoded parameters for the desired module. This is to make sure they can all follow
    // a similar interface.
    function deployEligibilityStorage(
        uint256 moduleIndex,
        bytes calldata initData
    ) external returns (address);

    // The curator has control over options like fees and features
    function setCurator(address _curator) external;

    function mint(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts /* ignored for ERC721 vaults */
    ) external returns (uint256);

    function mintTo(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts, /* ignored for ERC721 vaults */
        address to
    ) external returns (uint256);

    function redeem(uint256 amount, uint256[] calldata specificIds)
        external
        returns (uint256[] calldata);

    function redeemTo(
        uint256 amount,
        uint256[] calldata specificIds,
        address to
    ) external returns (uint256[] calldata);

    function swap(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts, /* ignored for ERC721 vaults */
        uint256[] calldata specificIds
    ) external returns (uint256[] calldata);

    function swapTo(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts, /* ignored for ERC721 vaults */
        uint256[] calldata specificIds,
        address to
    ) external returns (uint256[] calldata);
    function withdraw(uint256[] calldata tokenIds) external returns (uint256[] memory);

    function startAuction(uint256 tokenId, uint256 price) external;
    function bid(uint256 tokenId, uint256 price) external;
    function endAuction(uint256 tokenId) external;

    function flashFee(address borrowedToken, uint256 amount) external view returns (uint256);

    function flashLoan(
        IERC3156FlashBorrowerUpgradeable receiver,
        address borrowedToken,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);

    function allValidNFTs(uint256[] calldata tokenIds)
        external
        view
        returns (bool);

    function getAuction(uint256 tokenId) external view returns (uint256, uint256, AuctionState, address);
    function getDepositor(uint256 tokenId) external view returns (address);

    // /// @notice An event emitted when someone redeems all tokens for the NFT
    // event TokenRedeemed(address indexed redeemer);

    event AuctionLengthUpdated(uint256 length);
    /// @notice An event emitted when an auction starts
    event AuctionStarted(address indexed buyer, uint256 tokenId, uint256 price);
    /// @notice An event emitted when an auction is won
    event AuctionWon(address indexed buyer, uint256 tokenId, uint256 price);
    /// @notice An event emitted when a bid is made
    event BidMade(address indexed buyer, uint256 tokenId, uint256 price);
    event CuratorUpdated(address oldCurator, address newCurator);
    event EligibilityDeployed(uint256 moduleIndex, address eligibilityAddr);
    event Minted(uint256[] nftIds, uint256[] amounts, address to);
    event Redeemed(uint256[] nftIds, uint256[] specificIds, address to);
    event Swapped(
        uint256[] nftIds,
        uint256[] amounts,
        uint256[] specificIds,
        uint256[] redeemedIds,
        address to
    );
    event VaultInit(
        uint256 indexed vaultId,
        address assetAddress,
        bool is1155,
        bool allowAllItems
    );
    event VaultFeaturesUpdated(
      bool enableMint,
      bool enableRandomRedeem,
      bool enableTargetRedeem,
      bool enableRandomSwap,
      bool enableTargetSwap,
      bool enableBid
    );
    event VaultShutdown(address assetAddress, uint256 numItems, address recipient);

    error AuctionEnded();
    error AuctionLive();
    error AuctionNotEnded();
    error AuctionNotLive();
    error BidDisabled();
    error BidEnabled();
    error BidTooLow();
    error EligibilityAlreadySet();
    error FeeTooHigh();
    error IneligibleNFTs();
    error InvalidAuctionLength();
    error MintDisabled();
    error NFTAlreadyInCollection();
    error NotCurator();
    error NotNFTOwner();
    error NotInVault();
    error NotOwner();
    error Paused();
    error RandomRedeemDisabled();
    error RandomSwapDisabled();
    error TargetRedeemDisabled();
    error TargetSwapDisabled();
    error TooManyNFTs();
    error InvalidToken();
    error SameCurator();
    error ZeroAddress();
    error ZeroTransferAmount();
}