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
import "./token/LPStakingXTokenUpgradeable.sol";
import "./util/Pausable.sol";

// Pausing codes for LP staking are:
// 10: Deposit

contract LPStaking is ILPStaking, Pausable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(uint256 => StakingPool) public override vaultStakingInfo;

    IStakingTokenProvider public override stakingTokenProvider;
    LPStakingXTokenUpgradeable public override lpStakingXToken;
    IVaultManager public override vaultManager;

    function __LPStaking__init(address _vaultManager, address _stakingTokenProvider) external override initializer {
        __Ownable_init();
        if (_stakingTokenProvider == address(0)) revert ZeroAddress();
        if (address(lpStakingXToken) != address(0)) revert LPStakingXTokenAlreadySet();
        vaultManager = IVaultManager(_vaultManager);
        stakingTokenProvider = IStakingTokenProvider(_stakingTokenProvider);
        lpStakingXToken = new LPStakingXTokenUpgradeable();
        lpStakingXToken.__LPStakingXToken_init(IERC20Upgradeable(address(0)), "", "");
    }

    modifier onlyAdmin() {
        if (msg.sender != owner() && msg.sender != vaultManager.feeDistributor()) revert Unauthorized();
        _;
    }

    function addPoolForVault(uint256 vaultId) external override onlyAdmin {
        if (address(vaultManager) == address(0)) revert VaultManagerNotSet();
        if (vaultStakingInfo[vaultId].stakingToken != address(0)) revert PoolAlreadyExists();
        address _baseToken = vaultManager.vault(vaultId);
        address _stakingToken = stakingTokenProvider.stakingTokenForVaultToken(_baseToken);
        StakingPool memory pool = StakingPool(_stakingToken, _baseToken);
        vaultStakingInfo[vaultId] = pool;
        address newXToken = _deployDividendToken(pool);
        emit StakingPoolCreated(vaultId, newXToken, _baseToken);
    }

    function deposit(uint256 vaultId, uint256 amount) external override {
        onlyOwnerIfPaused(10);
        // Check the pool in case its been updated.
        updatePoolForVault(vaultId);

        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        IERC20Upgradeable(pool.stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        LPStakingXTokenUpgradeable _xToken = xToken(pool);

        // If the user has an existing timelock, check if it is in the future.
        uint256 currentTimelock = _xToken.timelockUntil(msg.sender);
        if (currentTimelock > block.timestamp) {
            // Maintain the same timelock if they already have one.
            // We do this instead of patching in the token because
            // the reward distribution token contracts as currently deployed are not upgradeable.
            _xToken.timelockMint(msg.sender, amount, currentTimelock-block.timestamp);
        } else {
            // Timelock for 2 seconds if they don't already have a timelock to prevent flash loans.
            _xToken.timelockMint(msg.sender, amount, 2);
        }

        emit LPDeposited(vaultId, amount, address(_xToken), msg.sender);
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

    function emergencyExit(address _stakingToken, address _baseToken) external override {
        StakingPool memory pool = StakingPool(_stakingToken, _baseToken);
        LPStakingXTokenUpgradeable dist = xToken(pool);
        if (!_isContract(address(dist))) revert NotAPool();
        _withdraw(pool, dist.balanceOf(msg.sender), msg.sender);
    }

    function emergencyExitAndClaim(address _stakingToken, address _baseToken) external override {
        StakingPool memory pool = StakingPool(_stakingToken, _baseToken);
        LPStakingXTokenUpgradeable dist = xToken(pool);
        if (!_isContract(address(dist))) revert NotAPool();
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
        LPStakingXTokenUpgradeable _xToken = xToken(pool);
        if(block.timestamp > _xToken.timelockUntil(who)) {
            return 0;
        }
        return _xToken.balanceOf(who);
    }

    function lockedUntil(uint256 vaultId, address who) external view override returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        LPStakingXTokenUpgradeable _xToken = xToken(pool);
        return _xToken.timelockUntil(who);
    }

    function receiveRewards(uint256 vaultId, uint256 amount) external override onlyAdmin returns (bool) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) {
            // In case the pair is updated, but not yet
            return false;
        }

        LPStakingXTokenUpgradeable _xToken = xToken(pool);
        // Don't distribute rewards unless there are people to distribute to.
        // Also added here if the distribution token is not deployed, just forfeit rewards for now.
        if (!_isContract(address(_xToken)) || _xToken.totalSupply() == 0) {
            return false;
        }
        // We "pull" to the dividend tokens so the vault only needs to approve this contract.
        IERC20Upgradeable(pool.baseToken).safeTransferFrom(msg.sender, address(_xToken), amount);
        _xToken.distributeRewards(amount);
        emit FeesReceived(vaultId, amount, address(_xToken));
        return true;
    }

    function xToken(uint256 vaultId) external view override returns (LPStakingXTokenUpgradeable) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        if (pool.stakingToken == address(0)) {
            return LPStakingXTokenUpgradeable(address(0));
        }
        return xToken(pool);
    }

    function setStakingTokenProvider(address _stakingTokenProvider) external override onlyOwner {
        if (_stakingTokenProvider == address(0)) revert ZeroAddress();
        emit StakingTokenProviderUpdated(address(stakingTokenProvider), _stakingTokenProvider);
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
        xToken(pool).timelockMint(account, amount, timelockLength);
    }

    // In case the provider changes, this lets the pool be updated. Anyone can call it.
    function updatePoolForVault(uint256 vaultId) public override {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        // Not letting people use this function to create new pools.
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        address _stakingToken = stakingTokenProvider.stakingTokenForVaultToken(pool.baseToken);
        StakingPool memory newPool = StakingPool(_stakingToken, pool.baseToken);
        vaultStakingInfo[vaultId] = newPool;

        // If the pool is already deployed, ignore the update.
        address addr = address(xToken(newPool));
        if (_isContract(addr)) {
            return;
        }
        address newXToken = _deployDividendToken(newPool);
        emit PoolUpdated(vaultId, newXToken);
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

        emit XTokenWithdrawn(vaultId, amount, address(xToken(pool)), msg.sender);
    }

    function balanceOf(uint256 vaultId, address addr) public view override returns (uint256) {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        LPStakingXTokenUpgradeable _xToken = xToken(pool);
        if (!_isContract(address(_xToken))) revert NotAPool();
        return _xToken.balanceOf(addr);
    }

    function claimRewards(uint256 vaultId) public override {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        _claimRewards(pool, msg.sender);
    }

    // Note: this function does not guarantee the token is deployed, we leave that check to elsewhere to save gas.
    function xToken(StakingPool memory pool) public view override returns (LPStakingXTokenUpgradeable) {
        bytes32 salt = keccak256(abi.encodePacked(pool.stakingToken, pool.baseToken, uint256(2) /* small nonce to change tokens */));
        address tokenAddr = ClonesUpgradeable.predictDeterministicAddress(address(lpStakingXToken), salt);
        return LPStakingXTokenUpgradeable(tokenAddr);
    }

    function xTokenAddr(address stakedToken, address baseToken) public view override returns (address) {
        StakingPool memory pool = StakingPool(stakedToken, baseToken);
        return address(xToken(pool));
    }

    function retrieveTokens(uint256 vaultId, uint256 amount, address from, address to) public override onlyOwner {
        StakingPool memory pool = vaultStakingInfo[vaultId];
        LPStakingXTokenUpgradeable _xToken = xToken(pool);
        _xToken.burnFrom(from, amount);
        _xToken.mint(to, amount);
    }

    function _claimRewards(StakingPool memory pool, address account) internal {
        if (pool.stakingToken == address(0)) revert PoolDoesNotExist();
        xToken(pool).withdrawReward(account);
    }

    function _deployDividendToken(StakingPool memory pool) internal returns (address) {
        // Changed to use new nonces.
        bytes32 salt = keccak256(abi.encodePacked(pool.stakingToken, pool.baseToken, uint256(2)));
        address _xToken = ClonesUpgradeable.cloneDeterministic(address(lpStakingXToken), salt);
        string memory name = stakingTokenProvider.nameForStakingToken(pool.baseToken);
        LPStakingXTokenUpgradeable(_xToken).__LPStakingXToken_init(IERC20Upgradeable(pool.baseToken), name, name);
        return _xToken;
    }

    function _isContract(address account) internal view returns (bool) {
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
        xToken(pool).burnFrom(account, amount);
        IERC20Upgradeable(pool.stakingToken).safeTransfer(account, amount);
    }
}