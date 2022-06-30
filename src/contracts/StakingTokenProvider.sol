// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

// Author: 0xKiwi.

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./interfaces/IStakingTokenProvider.sol";

contract StakingTokenProvider is IStakingTokenProvider, OwnableUpgradeable {
  mapping(address => string) public override pairedPrefix;
  mapping(address => address) public override pairedToken;

  address public override defaultPairedToken;
  address public override uniLikeExchange;

  string public override defaultPrefix;

  // This is an address provder to allow us to abstract out what liquidity
  // our vault tokens should be paired with.
  function __StakingTokenProvider_init(address _uniLikeExchange, address _defaultPairedtoken, string memory _defaultPrefix) public override initializer {
    __Ownable_init();
    if (_uniLikeExchange == address(0)) revert ZeroAddress();
    if (_defaultPairedtoken == address(0)) revert ZeroAddress();
    uniLikeExchange = _uniLikeExchange;
    defaultPairedToken = _defaultPairedtoken;
    defaultPrefix = _defaultPrefix;
  }

  function nameForStakingToken(address _vaultToken) external view override returns (string memory) {
    string memory _pairedPrefix = pairedPrefix[_vaultToken];
    if (bytes(_pairedPrefix).length == 0) {
      _pairedPrefix = defaultPrefix;
    }
    address _pairedToken = pairedToken[_vaultToken];
    if (_pairedToken == address(0)) {
      _pairedToken = defaultPairedToken;
    }

    string memory symbol1 = IERC20Metadata(_vaultToken).symbol();
    string memory symbol2 = IERC20Metadata(_pairedToken).symbol();
    return string(abi.encodePacked(_pairedPrefix, symbol1, symbol2));
  }

  function pairForVaultToken(address _vaultToken, address _pairedToken) external view override returns (address) {
    return _pairFor(uniLikeExchange, _vaultToken, _pairedToken);
  }

  function setDefaultPairedToken(address _defaultPairedToken, string calldata _defaultPrefix) external override onlyOwner {
    emit DefaultPairedTokenUpdated(defaultPairedToken, _defaultPairedToken);
    defaultPairedToken = _defaultPairedToken;
    defaultPrefix = _defaultPrefix;
  }

  function setPairedTokenForVaultToken(address _vaultToken, address _newPairedToken, string calldata _newPrefix) external override onlyOwner {
    if (_newPairedToken == address(0)) revert ZeroAddress();
    emit PairedTokenForVaultUpdated(_vaultToken, pairedToken[_vaultToken], _newPairedToken);
    pairedToken[_vaultToken] = _newPairedToken;
    pairedPrefix[_vaultToken] = _newPrefix;
  }

  function stakingTokenForVaultToken(address _vaultToken) external view override returns (address) {
    address _pairedToken = pairedToken[_vaultToken];
    if (_pairedToken == address(0)) {
      _pairedToken = defaultPairedToken;
    }
    return _pairFor(uniLikeExchange, _vaultToken, _pairedToken);
  }

  // calculates the CREATE2 address for a pair without making any external calls
  function _pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
      (address token0, address token1) = _sortTokens(tokenA, tokenB);
      pair = address(uint160(uint256(keccak256(abi.encodePacked(
              hex'ff',
              factory,
              keccak256(abi.encodePacked(token0, token1)),
              hex'754e1d90e536e4c1df81b7f030f47b4ca80c87120e145c294f098c83a6cb5ace' // init code hash
      )))));
  }

  // returns sorted token addresses, used to handle return values from pairs sorted in this order
  function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
      if (tokenA == tokenB) revert IdenticalAddress();
      (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
      if (token0 == address(0)) revert ZeroAddress();
  }
}