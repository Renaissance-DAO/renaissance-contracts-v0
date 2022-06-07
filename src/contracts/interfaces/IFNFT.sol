//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFNFT {
    enum State {
        Inactive,
        Live,
        Ended,
        Redeemed
    }

    function decimals() external returns (uint8);

    function balanceOf(address _account) external returns (uint256);

    function totalSupply() external returns (uint256);

    function auctionState() external returns (uint256);

    function initialReserve() external returns (uint256);

    function userReservePrice(address _user) external returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function setVaultMetadata(string calldata name_, string calldata symbol_) external;
}
