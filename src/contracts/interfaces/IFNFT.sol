//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IVaultManager.sol";
import "./IUniswapV2Pair.sol";

interface IFNFT {
    function vaultId() external returns (uint256);

    function id() external returns (uint256);

    function pair() external returns (IUniswapV2Pair);

    function factory() external returns (address);

    function vaultManager() external returns (IVaultManager);

    function verified() external returns (bool);

    function setVaultMetadata(
        string calldata name_,
        string calldata symbol_
    ) external;

    //ERC20 Interface

    function decimals() external returns (uint8);

    function balanceOf(address _account) external returns (uint256);

    function totalSupply() external returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}