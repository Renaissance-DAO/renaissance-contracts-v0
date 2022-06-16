// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "./interfaces/IFNFTCollectionFactory.sol";
import "./interfaces/IRewardDistributionToken.sol";
import "./util/Pausable.sol";
import "./StakingTokenProvider.sol";
import "./token/TimelockRewardDistributionTokenImpl.sol";

// Author: 0xKiwi.

// Pausing codes for LP staking are:
// 10: Deposit

contract LPStaking is Pausable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IFNFTCollectionFactory public fnftCollectionFactory;
    IRewardDistributionToken public rewardDistTokenImpl;
    StakingTokenProvider public stakingTokenProvider;

    event PoolCreated(uint256 vaultId, address pool);
    event PoolUpdated(uint256 vaultId, address pool);
    event FeesReceived(uint256 vaultId, uint256 amount);

    struct StakingPool {
        address stakingToken;
        address rewardToken;
    }
    mapping(uint256 => StakingPool) public vaultStakingInfo;

    TimelockRewardDistributionTokenImpl public newTimelockRewardDistTokenImpl;

    error FactoryAlreadySet();
    error FactoryNotSet();
    error NotAPool();
    error NotDeployingProperDistro();
    error NotExcludedFromFees();
    error NothingToMigrate();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error TimelockTooLong();
    error TimelockRewardDistTokenImplAlreadySet();
    error ZeroAddress();

    function __LPStaking__init(address _stakingTokenProvider) external initializer {
        __Ownable_init();
        if (_stakingTokenProvider == address(0)) revert ZeroAddress();
        if (address(newTimelockRewardDistTokenImpl) != address(0)) revert TimelockRewardDistTokenImplAlreadySet();
        stakingTokenProvider = StakingTokenProvider(_stakingTokenProvider);
        newTimelockRewardDistTokenImpl = new TimelockRewardDistributionTokenImpl();
        newTimelockRewardDistTokenImpl.__TimelockRewardDistributionToken_init(IERC20Upgradeable(address(0)), "", "");
    }

    modifier onlyAdmin() {
        if (msg.sender != owner() && msg.sender != fnftCollectionFactory.feeDistributor()) revert Unauthorized();
        _;
    }

    function setFNFTCollectionFactory(address newFactory) external onlyOwner {
        if (address(fnftCollectionFactory) != address(0)) revert FactoryAlreadySet();
        fnftCollectionFactory = IFNFTCollectionFactory(newFactory);
    }

    function setStakingTokenProvider(address newProvider) external onlyOwner {
        if (newProvider == address(0)) revert ZeroAddress();
        stakingTokenProvider = StakingTokenProvider(newProvider);
    }

    function addPoolForVault(uint256 vaultId) external onlyAdmin {
        if (address(fnftCollectionFactory) == address(0)) revert FactoryNotSet();
        if (vaultStakingInfo[vaultId].stakingToken != address(0)) revert PoolAlreadyExists();
        address _rewardToken = fnftCollectionFactory.vault(vaultId);
        address _stakingToken = stakingTokenProvider.stakingTokenForVaultToken(_rewardToken);
        StakingPool memory pool = StakingPool(_stakingToken, _rewardToken);
        vaultStakingInfo[vaultId] = pool;
        address newRewardDistToken = _deployDividendToken(pool);
        emit PoolCreated(vaultId, newRewardDistToken);
    }

    function updatePoolForVaults(uint256[] calldata vaultIds) external {
        uint256 length = vaultIds.length;
        for (uint256 i; i < length; ++i) {
            updatePoolForVault(vaultIds[i]);
        }
    }

    // In case the provider changes, this lets the pool be updated. Anyone can call it.
    function updatePoolForVault(uint256 vaultId) public {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        // Not letting people use this function to create new pools.
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        address _stakingToken = stakingTokenProvider.stakingTokenForVaultToken(pool.rewardToken);
        StakingPool memory newPool = StakingPool(_stakingToken, pool.rewardToken);
        vaultStakingInfo[vaultId] = newPool;

        // If the pool is already deployed, ignore the update.
        address addr = address(_rewardDistributionTokenAddr(newPool));
        if (isContract(addr)) {
            return;
        }
        address newRewardDistToken = _deployDividendToken(newPool);
        emit PoolUpdated(vaultId, newRewardDistToken);
    }

    function receiveRewards(uint256 vaultId, uint256 amount) external onlyAdmin returns (bool) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) {
            // In case the pair is updated, but not yet
            return false;
        }

        TimelockRewardDistributionTokenImpl rewardDistToken = _rewardDistributionTokenAddr(pool);
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

    function deposit(uint256 vaultId, uint256 amount) external {
        onlyOwnerIfPaused(10);
        // Check the pool in case its been updated.
        updatePoolForVault(vaultId);

        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        IERC20Upgradeable(pool.stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        TimelockRewardDistributionTokenImpl xSLPToken = _rewardDistributionTokenAddr(pool);

        // If the user has an existing timelock, check if it is in the future.
        uint256 currentTimelock = xSLPToken.timelockUntil(msg.sender);
        if (currentTimelock > block.timestamp) {
            // Maintain the same timelock if they already have one.
            // We do this instead of patching in the token because
            // the xSLP contracts as currently deployed are not upgradeable.
            xSLPToken.timelockMint(msg.sender, amount, currentTimelock-block.timestamp);
        } else {
            // Timelock for 2 seconds if they don't already have a timelock to prevent flash loans.
            xSLPToken.timelockMint(msg.sender, amount, 2);
        }
    }

    function timelockDepositFor(uint256 vaultId, address account, uint256 amount, uint256 timelockLength) external {
        if (timelockLength >= 2592000) revert TimelockTooLong();
        if (!fnftCollectionFactory.excludedFromFees(msg.sender)) revert NotExcludedFromFees();
        onlyOwnerIfPaused(10);
        // Check the pool in case its been updated.
        updatePoolForVault(vaultId);
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        IERC20Upgradeable(pool.stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        _rewardDistributionTokenAddr(pool).timelockMint(account, amount, timelockLength);
    }

    function exit(uint256 vaultId) external {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        _claimRewards(pool, msg.sender);
        _withdraw(pool, balanceOf(vaultId, msg.sender), msg.sender);
    }

    function emergencyExitAndClaim(address _stakingToken, address _rewardToken) external {
        StakingPool memory pool = StakingPool(_stakingToken, _rewardToken);
        TimelockRewardDistributionTokenImpl dist = _rewardDistributionTokenAddr(pool);
        if (!isContract(address(dist))) revert NotAPool();
        _claimRewards(pool, msg.sender);
        _withdraw(pool, dist.balanceOf(msg.sender), msg.sender);
    }

    function emergencyExit(address _stakingToken, address _rewardToken) external {
        StakingPool memory pool = StakingPool(_stakingToken, _rewardToken);
        TimelockRewardDistributionTokenImpl dist = _rewardDistributionTokenAddr(pool);
        if (!isContract(address(dist))) revert NotAPool();
        _withdraw(pool, dist.balanceOf(msg.sender), msg.sender);
    }

    function emergencyMigrate(uint256 vaultId) external {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        IRewardDistributionToken unusedDist = _unusedRewardDistributionTokenAddr(pool);
        IRewardDistributionToken oldDist = _oldRewardDistributionTokenAddr(pool);

        uint256 unusedDistBal;
        if (isContract(address(unusedDist))) {
            unusedDistBal = unusedDist.balanceOf(msg.sender);
            if (unusedDistBal > 0) {
                unusedDist.burnFrom(msg.sender, unusedDistBal);
            }
        }
        uint256 oldDistBal;
        if (isContract(address(oldDist))) {
            oldDistBal = oldDist.balanceOf(msg.sender);
            if (oldDistBal > 0) {
                oldDist.withdrawReward(msg.sender);
                oldDist.burnFrom(msg.sender, oldDistBal);
            }
        }

        TimelockRewardDistributionTokenImpl newDist = _rewardDistributionTokenAddr(pool);
        if (!isContract(address(newDist))) {
            address deployedDist = _deployDividendToken(pool);
            if (deployedDist != address(newDist)) revert NotDeployingProperDistro();
            emit PoolUpdated(vaultId, deployedDist);
        }
        if (unusedDistBal + oldDistBal == 0) revert NothingToMigrate();
        newDist.mint(msg.sender, unusedDistBal + oldDistBal);
    }

    function withdraw(uint256 vaultId, uint256 amount) external {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        _claimRewards(pool, msg.sender);
        _withdraw(pool, amount, msg.sender);
    }

    function claimRewards(uint256 vaultId) public {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        _claimRewards(pool, msg.sender);
    }

    function claimMultipleRewards(uint256[] calldata vaultIds) external {
        uint256 length = vaultIds.length;
        for (uint256 i; i < length; ++i) {
            claimRewards(vaultIds[i]);
        }
    }

    function newRewardDistributionToken(uint256 vaultId) external view returns (TimelockRewardDistributionTokenImpl) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) {
            return TimelockRewardDistributionTokenImpl(address(0));
        }
        return _rewardDistributionTokenAddr(pool);
    }

   function rewardDistributionToken(uint256 vaultId) external view returns (IRewardDistributionToken) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) {
            return IRewardDistributionToken(address(0));
        }
        return _unusedRewardDistributionTokenAddr(pool);
    }

    function oldRewardDistributionToken(uint256 vaultId) external view returns (address) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) {
            return address(0);
        }
        return address(_oldRewardDistributionTokenAddr(pool));
    }

    function unusedRewardDistributionToken(uint256 vaultId) external view returns (address) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) {
            return address(0);
        }
        return address(_unusedRewardDistributionTokenAddr(pool));
    }

    function rewardDistributionTokenAddr(address stakedToken, address rewardToken) public view returns (address) {
        StakingPool memory pool = StakingPool(stakedToken, rewardToken);
        return address(_rewardDistributionTokenAddr(pool));
    }

    function balanceOf(uint256 vaultId, address addr) public view returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        TimelockRewardDistributionTokenImpl dist = _rewardDistributionTokenAddr(pool);
        if (!isContract(address(dist))) revert NotAPool();
        return dist.balanceOf(addr);
    }

    function oldBalanceOf(uint256 vaultId, address addr) public view returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        IRewardDistributionToken dist = _oldRewardDistributionTokenAddr(pool);
        if (!isContract(address(dist))) revert NotAPool();
        return dist.balanceOf(addr);
    }

    function unusedBalanceOf(uint256 vaultId, address addr) public view returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        IRewardDistributionToken dist = _unusedRewardDistributionTokenAddr(pool);
        if (!isContract(address(dist))) revert NotAPool();
        return dist.balanceOf(addr);
    }

    function lockedUntil(uint256 vaultId, address who) external view returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        TimelockRewardDistributionTokenImpl dist = _rewardDistributionTokenAddr(pool);
        return dist.timelockUntil(who);
    }

    function lockedLPBalance(uint256 vaultId, address who) external view returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        TimelockRewardDistributionTokenImpl dist = _rewardDistributionTokenAddr(pool);
        if(block.timestamp > dist.timelockUntil(who)) {
            return 0;
        }
        return dist.balanceOf(who);
    }

    function _claimRewards(StakingPool memory pool, address account) internal {
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        _rewardDistributionTokenAddr(pool).withdrawReward(account);
    }

    function _withdraw(StakingPool memory pool, uint256 amount, address account) internal {
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        _rewardDistributionTokenAddr(pool).burnFrom(account, amount);
        IERC20Upgradeable(pool.stakingToken).safeTransfer(account, amount);
    }

    function _deployDividendToken(StakingPool memory pool) internal returns (address) {
        // Changed to use new nonces.
        bytes32 salt = keccak256(abi.encodePacked(pool.stakingToken, pool.rewardToken, uint256(2)));
        address rewardDistToken = ClonesUpgradeable.cloneDeterministic(address(newTimelockRewardDistTokenImpl), salt);
        string memory name = stakingTokenProvider.nameForStakingToken(pool.rewardToken);
        TimelockRewardDistributionTokenImpl(rewardDistToken).__TimelockRewardDistributionToken_init(IERC20Upgradeable(pool.rewardToken), name, name);
        return rewardDistToken;
    }

    // Note: this function does not guarantee the token is deployed, we leave that check to elsewhere to save gas.
    function _rewardDistributionTokenAddr(StakingPool memory pool) public view returns (TimelockRewardDistributionTokenImpl) {
        bytes32 salt = keccak256(abi.encodePacked(pool.stakingToken, pool.rewardToken, uint256(2) /* small nonce to change tokens */));
        address tokenAddr = ClonesUpgradeable.predictDeterministicAddress(address(newTimelockRewardDistTokenImpl), salt);
        return TimelockRewardDistributionTokenImpl(tokenAddr);
    }

    // Note: this function does not guarantee the token is deployed, we leave that check to elsewhere to save gas.
    function _oldRewardDistributionTokenAddr(StakingPool memory pool) public view returns (IRewardDistributionToken) {
        bytes32 salt = keccak256(abi.encodePacked(pool.stakingToken, pool.rewardToken, uint256(1)));
        address tokenAddr = ClonesUpgradeable.predictDeterministicAddress(address(rewardDistTokenImpl), salt);
        return IRewardDistributionToken(tokenAddr);
    }

    // Note: this function does not guarantee the token is deployed, we leave that check to elsewhere to save gas.
    function _unusedRewardDistributionTokenAddr(StakingPool memory pool) public view returns (IRewardDistributionToken) {
        bytes32 salt = keccak256(abi.encodePacked(pool.stakingToken, pool.rewardToken));
        address tokenAddr = ClonesUpgradeable.predictDeterministicAddress(address(rewardDistTokenImpl), salt);
        return IRewardDistributionToken(tokenAddr);
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

    function retrieveTokens(uint256 vaultId, uint256 amount, address from, address to) public onlyOwner {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        TimelockRewardDistributionTokenImpl xSlp = _rewardDistributionTokenAddr(pool);
        xSlp.burnFrom(from, amount);
        xSlp.mint(to, amount);
    }
}