// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./IVaultManager.sol";
import "./IStakingTokenProvider.sol";
import "../token/LPStakingXTokenUpgradeable.sol";

interface ILPStaking {
    struct StakingPool {
        address stakingToken;
        address baseToken;
    }

    function vaultManager() external view returns (IVaultManager);

    function stakingTokenProvider() external view returns (IStakingTokenProvider);

    function lpStakingXToken() external view returns (LPStakingXTokenUpgradeable);

    function vaultStakingInfo(uint256) external view returns (address, address);

    function __LPStaking__init(address _vaultManager, address _stakingTokenProvider) external;

    function setStakingTokenProvider(address _stakingTokenProvider) external;

    function addPoolForVault(uint256 vaultId) external;

    function updatePoolForVaults(uint256[] calldata vaultIds) external;

    function updatePoolForVault(uint256 vaultId) external;

    function receiveRewards(uint256 vaultId, uint256 amount) external returns (bool);

    function deposit(uint256 vaultId, uint256 amount) external;

    function timelockDepositFor(uint256 vaultId, address account, uint256 amount, uint256 timelockLength) external;

    function exit(uint256 vaultId) external;

    function emergencyExitAndClaim(address _stakingToken, address _baseToken) external;

    function emergencyExit(address _stakingToken, address _baseToken) external;

    function withdraw(uint256 vaultId, uint256 amount) external;

    function claimRewards(uint256 vaultId) external;

    function claimMultipleRewards(uint256[] calldata vaultIds) external;

    function xToken(uint256 vaultId) external view returns (LPStakingXTokenUpgradeable);

    function xTokenAddr(address stakedToken, address baseToken) external view returns (address);

    function balanceOf(uint256 vaultId, address addr) external view returns (uint256);

    function lockedUntil(uint256 vaultId, address who) external view returns (uint256);

    function lockedLPBalance(uint256 vaultId, address who) external view returns (uint256);

    function xToken(StakingPool memory pool) external view returns (LPStakingXTokenUpgradeable);

    function retrieveTokens(uint256 vaultId, uint256 amount, address from, address to) external;

    event StakingPoolCreated(uint256 vaultId, address xToken, address baseToken);
    event PoolUpdated(uint256 vaultId, address xToken);
    event FeesReceived(uint256 vaultId, uint256 amount, address xToken);
    event LPDeposited(uint256 vaultId, uint256 amount, address xToken, address sender);
    event XTokenWithdrawn(uint256 vaultId, uint256 amount, address xToken, address sender);
    event StakingTokenProviderUpdated(address oldStakingTokenProvider, address newStakingTokenProvider);

    error NotAPool();
    error NotDeployingProperDistro();
    error NotExcludedFromFees();
    error NothingToMigrate();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error LPStakingXTokenAlreadySet();
    error TimelockTooLong();
    error VaultManagerAlreadySet();
    error VaultManagerNotSet();
    error ZeroAddress();
}
