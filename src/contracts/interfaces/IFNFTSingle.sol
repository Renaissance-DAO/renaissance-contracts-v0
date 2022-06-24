//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IVaultManager.sol";
import "./IUniswapV2Pair.sol";

interface IFNFTSingle {
    enum State {
        Inactive,
        Live,
        Ended,
        Redeemed
    }

    function token() external returns (address);

    function winning() external returns (address payable);

    function vaultId() external returns (uint256);

    function id() external returns (uint256);

    function auctionEnd() external returns (uint256);

    function auctionLength() external returns (uint256);

    function reserveTotal() external returns (uint256);

    function livePrice() external returns (uint256);

    function pair() external returns (IUniswapV2Pair);

    function auctionState() external returns (State);

    function factory() external returns (address);

    function vaultManager() external returns (IVaultManager);

    function verified() external returns (bool);

    function curator() external returns (address);

    function fee() external returns (uint256);

    function lastClaimed() external returns (uint256);

    function votingTokens() external returns (uint256);

    function initialReserve() external returns (uint256);

    function userReservePrice(address) external returns (uint256);

    function initialize(
        address _curator,
        address _token,
        uint256 _id,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee,
        string memory _name,
        string memory _symbol
    ) external;

    function reservePrice() external view returns (uint256);

    function kickCurator(address _curator) external;

    function removeReserve(address _user) external;

    function toggleVerified() external;

    function updateCurator(address _curator) external;

    function updateAuctionLength(uint256 _length) external;

    function updateFee(uint256 _fee) external;

    function claimFees() external;

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

    function setVaultMetadata(
        string calldata name_,
        string calldata symbol_
    ) external;

    /// @notice An event emitted when a user updates their price
    event PriceUpdate(address indexed user, uint256 price);
    /// @notice An event emitted when an auction starts
    event Start(address indexed buyer, uint256 price);
    /// @notice An event emitted when a bid is made
    event Bid(address indexed buyer, uint256 price);
    /// @notice An event emitted when an auction is won
    event Won(address indexed buyer, uint256 price);
    /// @notice An event emitted when someone redeems all tokens for the NFT
    event Redeem(address indexed redeemer);
    /// @notice An event emitted when someone cashes in ERC20 tokens for ETH from an ERC721 token sale
    event Cash(address indexed owner, uint256 shares);
    event UpdateAuctionLength(uint256 length);
    event UpdateCuratorFee(uint256 fee);
    event FeeClaimed(uint256 fee);
    event Verified(bool verified);
    event KickCurator(address indexed oldCurator, address indexed newCurator);
    event UpdateCurator(address indexed oldCurator, address indexed newCurator);

    error NotGov();
    error NotCurator();
    error SameCurator();
    error AuctionLive();
    error NotAnUpdate();
    error InvalidAuctionLength();
    error CanNotRaise();
    error FeeTooHigh();
    error AuctionEnded();
    error AuctionNotEnded();
    error NotEnoughETH();
    error PriceTooLow();
    error PriceTooHigh();
    error BidTooLow();
    error NotEnoughVoters();
    error AuctionNotLive();
    error NoTokens();
    error WrongToken();
}