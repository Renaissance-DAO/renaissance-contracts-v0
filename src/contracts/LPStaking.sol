// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "./interfaces/ILPStaking.sol";
import "./interfaces/IStakingTokenProvider.sol";
import "./interfaces/IVaultManager.sol";
import "./token/TimelockRewardDistributionTokenImpl.sol";
import "./util/Pausable.sol";

// Author: 0xKiwi.

// Pausing codes for LP staking are:
// 10: Deposit

contract LPStaking is ILPStaking, Pausable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(uint256 => StakingPool) public override vaultStakingInfo;

    IStakingTokenProvider public override stakingTokenProvider;
    TimelockRewardDistributionTokenImpl public override timelockRewardDistTokenImpl;
    IVaultManager public override vaultManager;

    function __LPStaking__init(address _vaultManager, address _stakingTokenProvider) external override initializer {
        __Ownable_init();
        if (_stakingTokenProvider == address(0)) revert ZeroAddress();
        if (address(timelockRewardDistTokenImpl) != address(0)) revert TimelockRewardDistTokenImplAlreadySet();
        vaultManager = IVaultManager(_vaultManager);
        stakingTokenProvider = IStakingTokenProvider(_stakingTokenProvider);
        timelockRewardDistTokenImpl = new TimelockRewardDistributionTokenImpl();
        timelockRewardDistTokenImpl.__TimelockRewardDistributionToken_init(IERC20Upgradeable(address(0)), "", "");
    }

    modifier onlyAdmin() {
        if (msg.sender != owner() && msg.sender != vaultManager.feeDistributor()) revert Unauthorized();
        _;
    }

    function addPoolForVault(uint256 vaultId) external override onlyAdmin {
        if (address(vaultManager) == address(0)) revert VaultManagerNotSet();
        if (vaultStakingInfo[vaultId].stakingToken != address(0)) revert PoolAlreadyExists();
        address _rewardToken = vaultManager.vault(vaultId);
        address _stakingToken = stakingTokenProvider.stakingTokenForVaultToken(_rewardToken);
        StakingPool memory pool = StakingPool(_stakingToken, _rewardToken);
        vaultStakingInfo[vaultId] = pool;
        address newRewardDistToken = _deployDividendToken(pool);
        emit PoolCreated(vaultId, newRewardDistToken);
    }

    function deposit(uint256 vaultId, uint256 amount) external override {
        onlyOwnerIfPaused(10);
        // Check the pool in case its been updated.
        updatePoolForVault(vaultId);

        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        IERC20Upgradeable(pool.stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        TimelockRewardDistributionTokenImpl rewardDistToken = rewardDistributionToken(pool);

        // If the user has an existing timelock, check if it is in the future.
        uint256 currentTimelock = rewardDistToken.timelockUntil(msg.sender);
        if (currentTimelock > block.timestamp) {
            // Maintain the same timelock if they already have one.
            // We do this instead of patching in the token because
            // the reward distribution token contracts as currently deployed are not upgradeable.
            rewardDistToken.timelockMint(msg.sender, amount, currentTimelock-block.timestamp);
        } else {
            // Timelock for 2 seconds if they don't already have a timelock to prevent flash loans.
            rewardDistToken.timelockMint(msg.sender, amount, 2);
        }
    }

    function claimMultipleRewards(uint256[] calldata vaultIds) external override {
        uint256 length = vaultIds.length;
        for (uint256 i; i < length;) {
            claimRewards(vaultIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function emergencyExit(address _stakingToken, address _rewardToken) external override {
        StakingPool memory pool = StakingPool(_stakingToken, _rewardToken);
        TimelockRewardDistributionTokenImpl dist = rewardDistributionToken(pool);
        if (!isContract(address(dist))) revert NotAPool();
        _withdraw(pool, dist.balanceOf(msg.sender), msg.sender);
    }

    function emergencyExitAndClaim(address _stakingToken, address _rewardToken) external override {
        StakingPool memory pool = StakingPool(_stakingToken, _rewardToken);
        TimelockRewardDistributionTokenImpl dist = rewardDistributionToken(pool);
        if (!isContract(address(dist))) revert NotAPool();
        _claimRewards(pool, msg.sender);
        _withdraw(pool, dist.balanceOf(msg.sender), msg.sender);
    }

    function exit(uint256 vaultId) external override {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        _claimRewards(pool, msg.sender);
        _withdraw(pool, balanceOf(vaultId, msg.sender), msg.sender);
    }

    function lockedLPBalance(uint256 vaultId, address who) external view override returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        TimelockRewardDistributionTokenImpl dist = rewardDistributionToken(pool);
        if(block.timestamp > dist.timelockUntil(who)) {
            return 0;
        }
        return dist.balanceOf(who);
    }

    function lockedUntil(uint256 vaultId, address who) external view override returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        TimelockRewardDistributionTokenImpl dist = rewardDistributionToken(pool);
        return dist.timelockUntil(who);
    }

    function receiveRewards(uint256 vaultId, uint256 amount) external override onlyAdmin returns (bool) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) {
            // In case the pair is updated, but not yet
            return false;
        }

        TimelockRewardDistributionTokenImpl rewardDistToken = rewardDistributionToken(pool);
        // Don't distribute rewards unless there are people to distribute to.
        // Also added here if the distribution token is not deployed, just forfeit rewards for now.
        if (!isContract(address(rewardDistToken)) || rewardDistToken.totalSupply() == 0) {
            return false;
        }
        // We "pull" to the dividend tokens so the vault only needs to approve this contract.
        IERC20Upgradeable(pool.rewardToken).safeTransferFrom(msg.sender, address(rewardDistToken), amount);
        rewardDistToken.distributeRewards(amount);
        emit FeesReceived(vaultId, amount);
        return true;
    }

    function rewardDistributionToken(uint256 vaultId) external view override returns (TimelockRewardDistributionTokenImpl) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) {
            return TimelockRewardDistributionTokenImpl(address(0));
        }
        return rewardDistributionToken(pool);
    }

    // TODO: missing event emission
    function setStakingTokenProvider(address _stakingTokenProvider) external override onlyOwner {
        if (_stakingTokenProvider == address(0)) revert ZeroAddress();
        stakingTokenProvider = IStakingTokenProvider(_stakingTokenProvider);
    }

    function timelockDepositFor(uint256 vaultId, address account, uint256 amount, uint256 timelockLength) external override {
        if (timelockLength >= 2592000) revert TimelockTooLong();
        if (!vaultManager.excludedFromFees(msg.sender)) revert NotExcludedFromFees();
        onlyOwnerIfPaused(10);
        // Check the pool in case its been updated.
        updatePoolForVault(vaultId);
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        IERC20Upgradeable(pool.stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        rewardDistributionToken(pool).timelockMint(account, amount, timelockLength);
    }

    // In case the provider changes, this lets the pool be updated. Anyone can call it.
    function updatePoolForVault(uint256 vaultId) public override {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        // Not letting people use this function to create new pools.
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        address _stakingToken = stakingTokenProvider.stakingTokenForVaultToken(pool.rewardToken);
        StakingPool memory newPool = StakingPool(_stakingToken, pool.rewardToken);
        vaultStakingInfo[vaultId] = newPool;

        // If the pool is already deployed, ignore the update.
        address addr = address(rewardDistributionToken(newPool));
        if (isContract(addr)) {
            return;
        }
        address newRewardDistToken = _deployDividendToken(newPool);
        emit PoolUpdated(vaultId, newRewardDistToken);
    }

    function updatePoolForVaults(uint256[] calldata vaultIds) external override {
        uint256 length = vaultIds.length;
        for (uint256 i; i < length;) {
            updatePoolForVault(vaultIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function withdraw(uint256 vaultId, uint256 amount) external override {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        _claimRewards(pool, msg.sender);
        _withdraw(pool, amount, msg.sender);
    }

    function balanceOf(uint256 vaultId, address addr) public view override returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        TimelockRewardDistributionTokenImpl dist = rewardDistributionToken(pool);
        if (!isContract(address(dist))) revert NotAPool();
        return dist.balanceOf(addr);
    }

    function claimRewards(uint256 vaultId) public override {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        _claimRewards(pool, msg.sender);
    }

    // Note: this function does not guarantee the token is deployed, we leave that check to elsewhere to save gas.
    function rewardDistributionToken(StakingPool memory pool) public view override returns (TimelockRewardDistributionTokenImpl) {
        bytes32 salt = keccak256(abi.encodePacked(pool.stakingToken, pool.rewardToken, uint256(2) /* small nonce to change tokens */));
        address tokenAddr = ClonesUpgradeable.predictDeterministicAddress(address(timelockRewardDistTokenImpl), salt);
        return TimelockRewardDistributionTokenImpl(tokenAddr);
    }

    function rewardDistributionTokenAddr(address stakedToken, address rewardToken) public view override returns (address) {
        StakingPool memory pool = StakingPool(stakedToken, rewardToken);
        return address(rewardDistributionToken(pool));
    }

    function retrieveTokens(uint256 vaultId, uint256 amount, address from, address to) public override onlyOwner {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        TimelockRewardDistributionTokenImpl rewardDistToken = rewardDistributionToken(pool);
        rewardDistToken.burnFrom(from, amount);
        rewardDistToken.mint(to, amount);
    }

    function _claimRewards(StakingPool memory pool, address account) internal {
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        rewardDistributionToken(pool).withdrawReward(account);
    }

    function _deployDividendToken(StakingPool memory pool) internal returns (address) {
        // Changed to use new nonces.
        bytes32 salt = keccak256(abi.encodePacked(pool.stakingToken, pool.rewardToken, uint256(2)));
        address rewardDistToken = ClonesUpgradeable.cloneDeterministic(address(timelockRewardDistTokenImpl), salt);
        string memory name = stakingTokenProvider.nameForStakingToken(pool.rewardToken);
        TimelockRewardDistributionTokenImpl(rewardDistToken).__TimelockRewardDistributionToken_init(IERC20Upgradeable(pool.rewardToken), name, name);
        return rewardDistToken;
    }

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function _withdraw(StakingPool memory pool, uint256 amount, address account) internal {
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        rewardDistributionToken(pool).burnFrom(account, amount);
        IERC20Upgradeable(pool.stakingToken).safeTransfer(account, amount);
    }
}