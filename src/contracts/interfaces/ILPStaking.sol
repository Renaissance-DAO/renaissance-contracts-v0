// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./IVaultManager.sol";
import "./IStakingTokenProvider.sol";
import "../token/TimelockRewardDistributionTokenImpl.sol";

interface ILPStaking {
    struct StakingPool {
        address stakingToken;
        address rewardToken;
    }

    function vaultManager() external view returns (IVaultManager);

    function stakingTokenProvider() external view returns (IStakingTokenProvider);

    function timelockRewardDistTokenImpl() external view returns (TimelockRewardDistributionTokenImpl);

    function vaultStakingInfo(uint256) external view returns (address, address);

    function __LPStaking__init(address _vaultManager, address _stakingTokenProvider) external;

    function setStakingTokenProvider(address newProvider) external;

    function addPoolForVault(uint256 vaultId) external;

    function updatePoolForVaults(uint256[] calldata vaultIds) external;

    function updatePoolForVault(uint256 vaultId) external;

    function receiveRewards(uint256 vaultId, uint256 amount) external returns (bool);

    function deposit(uint256 vaultId, uint256 amount) external;

    function timelockDepositFor(uint256 vaultId, address account, uint256 amount, uint256 timelockLength) external;

    function exit(uint256 vaultId) external;

    function emergencyExitAndClaim(address _stakingToken, address _rewardToken) external;

    function emergencyExit(address _stakingToken, address _rewardToken) external;

    function withdraw(uint256 vaultId, uint256 amount) external;

    function claimRewards(uint256 vaultId) external;

    function claimMultipleRewards(uint256[] calldata vaultIds) external;

    function rewardDistributionToken(uint256 vaultId) external view returns (TimelockRewardDistributionTokenImpl);

    function rewardDistributionTokenAddr(address stakedToken, address rewardToken) external view returns (address);

    function balanceOf(uint256 vaultId, address addr) external view returns (uint256);

    function lockedUntil(uint256 vaultId, address who) external view returns (uint256);

    function lockedLPBalance(uint256 vaultId, address who) external view returns (uint256);

    function _rewardDistributionToken(StakingPool memory pool) external view returns (TimelockRewardDistributionTokenImpl);

    function retrieveTokens(uint256 vaultId, uint256 amount, address from, address to) external;

    event PoolCreated(uint256 vaultId, address pool);
    event PoolUpdated(uint256 vaultId, address pool);
    event FeesReceived(uint256 vaultId, uint256 amount);

    error VaultManagerAlreadySet();
    error VaultManagerNotSet();
    error NotAPool();
    error NotDeployingProperDistro();
    error NotExcludedFromFees();
    error NothingToMigrate();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error TimelockTooLong();
    error TimelockRewardDistTokenImplAlreadySet();
    error ZeroAddress();
}
