//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC3156FlashBorrowerUpgradeable.sol";

import "./IVaultManager.sol";
import "./IUniswapV2Pair.sol";
import "./IFNFTSingleFactory.sol";
import "../token/ERC20Upgradeable.sol";

interface IFNFTSingle  is IERC20Upgradeable {
    enum State {
        Inactive,
        Live,
        Ended,
        Redeemed
    }

    function token() external returns (address);

    function winning() external returns (address payable);

    function vaultId() external returns (uint256);

    function tokenId() external returns (uint256);

    function auctionEnd() external returns (uint256);

    function auctionLength() external returns (uint256);

    function reserveTotal() external returns (uint256);

    function livePrice() external returns (uint256);

    function pair() external returns (IUniswapV2Pair);

    function auctionState() external returns (State);

    function factory() external returns (IFNFTSingleFactory);

    function vaultManager() external returns (IVaultManager);

    function verified() external returns (bool);

    function curator() external returns (address);

    function curatorFee() external returns (uint256);

    function lastClaimed() external returns (uint256);

    function votingTokens() external returns (uint256);

    function initialReserve() external returns (uint256);

    function userReservePrice(address) external returns (uint256);

    function __FNFTSingle_init(
        string memory _name,
        string memory _symbol,
        address _curator,
        address _token,
        uint256 _id,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _curatorFee
    ) external;

    function reservePrice() external view returns (uint256);

    function kickCurator(address _curator) external;

    function removeReserve(address _user) external;

    function toggleVerified() external;

    function setCurator(address _curator) external;

    function setAuctionLength(uint256 _length) external;

    function setFee(uint256 _fee) external;

    function claimCuratorFees() external;

    function getAuctionPrice() external view returns (uint256);

    function buyItNow() external payable;

    function buyItNowPrice() external view returns (uint256);

    function updateUserPrice(uint256 newUserReserve) external;

    function getQuorum() external view returns (uint256);

    function start() external payable;

    function bid() external payable;

    function end() external;

    function redeem() external;

    function cash() external;

    function flashFee(address borrowedToken, uint256 amount) external view returns (uint256);

    function flashLoan(
        IERC3156FlashBorrowerUpgradeable receiver,
        address borrowedToken,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);

    function setVaultMetadata(
        string calldata name_,
        string calldata symbol_
    ) external;

    /// @notice An event emitted when a user updates their price
    event PriceUpdated(address indexed user, uint256 price);
    /// @notice An event emitted when an auction starts
    event AuctionStarted(address indexed buyer, uint256 price);
    /// @notice An event emitted when a bid is made
    event BidMade(address indexed buyer, uint256 price);
    /// @notice An event emitted when an auction is won
    event AuctionWon(address indexed buyer, uint256 price);
    /// @notice An event emitted when someone redeems all tokens for the NFT
    event TokenRedeemed(address indexed redeemer);
    /// @notice An event emitted when someone cashes in ERC20 tokens for ETH from an ERC721 token sale
    event CashWithdrawn(address indexed owner, uint256 shares);
    event AuctionLengthUpdated(uint256 length);
    event CuratorFeeUpdated(uint256 curatorFee);
    event CuratorFeeClaimed(uint256 curatorFee);
    event Verified(bool verified);
    event CuratorKicked(address indexed oldCurator, address indexed newCurator);
    event CuratorUpdated(address indexed oldCurator, address indexed newCurator);

    error AuctionEnded();
    error AuctionLive();
    error AuctionNotEnded();
    error AuctionNotLive();
    error BidTooLow();
    error CanNotRaise();
    error FeeTooHigh();
    error InvalidAuctionLength();
    error NotAnUpdate();
    error NotCurator();
    error NotEnoughETH();
    error NotEnoughVoters();
    error NotOwner();
    error NoTokens();
    error Paused();
    error PriceTooHigh();
    error PriceTooLow();
    error SameCurator();
    error InvalidToken();
    error ZeroAddress();
}