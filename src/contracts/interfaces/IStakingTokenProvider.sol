// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStakingTokenProvider {
    function uniLikeExchange() external returns (address);

    function defaultPairedToken() external returns (address);

    function defaultPrefix() external returns (string memory);

    function pairedToken(address) external returns (address);

    function pairedPrefix(address) external returns (string memory);

    function __StakingTokenProvider_init(address _uniLikeExchange, address _defaultPairedtoken, string memory _defaultPrefix) external;

    function setPairedTokenForVaultToken(address _vaultToken, address _newPairedToken, string calldata _newPrefix) external;

    function setDefaultPairedToken(address _defaultPairedToken, string calldata _defaultPrefix) external;

    function stakingTokenForVaultToken(address _vaultToken) external view returns (address);

    function nameForStakingToken(address _vaultToken) external view returns (string memory);

    function pairForVaultToken(address _vaultToken, address _pairedToken) external view returns (address);

    event DefaultPairedTokenUpdated(address oldDefaultPairedToken, address newDefaultPairedToken);
    event PairedTokenForVaultUpdated(address vaultToken, address oldPairedtoken, address newPairedToken);

    error IdenticalAddress();
    error ZeroAddress();
}