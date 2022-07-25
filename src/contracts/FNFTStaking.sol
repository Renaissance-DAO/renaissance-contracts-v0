// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

import "./interfaces/IVaultManager.sol";
import "./interfaces/IFNFTCollection.sol";
import "./interfaces/IFNFTStaking.sol";
import "./util/Pausable.sol";
import "./proxy/BeaconUpgradeable.sol";
import "./proxy/Create2BeaconProxy.sol";
import "./token/FNFTStakingXTokenUpgradeable.sol";
import "./interfaces/ITimelockExcludeList.sol";

// Author: 0xKiwi.

// Pausing codes for inventory staking are:
// 10: Deposit

contract FNFTStaking is IFNFTStaking, Pausable, BeaconUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Small locktime to prevent flash deposits.
    uint256 internal constant DEFAULT_LOCKTIME = 2;
    bytes internal constant BEACON_CODE = type(Create2BeaconProxy).creationCode;

    IVaultManager public override vaultManager;
    ITimelockExcludeList public override timelockExcludeList;

    uint256 public override inventoryLockTimeErc20;

    function __FNFTStaking_init(address _vaultManager) external virtual override initializer {
        __Ownable_init();
        vaultManager = IVaultManager(_vaultManager);
        address xTokenImpl = address(new FNFTStakingXTokenUpgradeable());
        __BeaconUpgradeable__init(xTokenImpl);
    }

    modifier onlyAdmin() {
        if (msg.sender != owner() && msg.sender != vaultManager.feeDistributor()) revert Unauthorized();
        _;
    }

    function balanceOf(uint256 vaultId, address who) external view override returns (uint256) {
        FNFTStakingXTokenUpgradeable xToken = FNFTStakingXTokenUpgradeable(vaultXToken(vaultId));
        return xToken.balanceOf(who);
    }

    // Enter staking. Staking, get minted shares and
    // locks base tokens and mints xTokens.
    function deposit(uint256 vaultId, uint256 _amount) external virtual override {
        onlyOwnerIfPaused(10);

        uint256 timelockTime = isAddressTimelockExcluded(msg.sender, vaultId) ? 0 : inventoryLockTimeErc20;

        (IERC20Upgradeable baseToken, FNFTStakingXTokenUpgradeable xToken, uint256 xTokensMinted) = _timelockMintFor(vaultId, msg.sender, _amount, timelockTime);
        // Lock the base token in the xtoken contract
        baseToken.safeTransferFrom(msg.sender, address(xToken), _amount);
        emit BaseTokenDeposited(vaultId, _amount, xTokensMinted, timelockTime, msg.sender);
    }

    function isAddressTimelockExcluded(address addr, uint256 vaultId) public view override returns (bool) {
        if (address(timelockExcludeList) == address(0)) {
            return false;
        } else {
            return timelockExcludeList.isExcluded(addr, vaultId);
        }
    }

    function receiveRewards(uint256 vaultId, uint256 amount) external virtual override onlyAdmin returns (bool) {
        address baseToken = vaultManager.vault(vaultId);
        address deployedXToken = xTokenAddr(address(baseToken));

        // Don't distribute rewards unless there are people to distribute to.
        // Also added here if the distribution token is not deployed, just forfeit rewards for now.
        if (!_isContract(deployedXToken) || FNFTStakingXTokenUpgradeable(deployedXToken).totalSupply() == 0) {
            return false;
        }
        // We "pull" to the dividend tokens so the fee distributor only needs to approve this contract.
        IERC20Upgradeable(baseToken).safeTransferFrom(msg.sender, deployedXToken, amount);
        emit FeesReceived(vaultId, amount, deployedXToken);
        return true;
    }

    function setInventoryLockTimeErc20(uint256 _inventoryLockTimeErc20) external override onlyOwner {
        if (_inventoryLockTimeErc20 > 14 days) revert LockTooLong();
        emit InventoryLockTimeErc20Updated(inventoryLockTimeErc20, _inventoryLockTimeErc20);
        inventoryLockTimeErc20 = _inventoryLockTimeErc20;
    }

    // TODO: timelock exclude list is not yet implemented
    function setTimelockExcludeList(address _timelockExcludeList) external override onlyOwner {
        emit TimelockExcludeListUpdated(address(timelockExcludeList), _timelockExcludeList);
        timelockExcludeList = ITimelockExcludeList(_timelockExcludeList);
    }

    function timelockMintFor(uint256 vaultId, uint256 amount, address to, uint256 timelockLength) external virtual override returns (uint256) {
        onlyOwnerIfPaused(10);
        if (msg.sender != vaultManager.zapContract()) revert NotZapContract();
        // important for math that staking zap is excluded from fees
        if (!vaultManager.excludedFromFees(msg.sender)) revert NotExcludedFromFees();

        (, , uint256 xTokensMinted) = _timelockMintFor(vaultId, to, amount, timelockLength);
        emit BaseTokenDeposited(vaultId, amount, xTokensMinted, timelockLength, to);
        return xTokensMinted;
    }

    function timelockUntil(uint256 vaultId, address who) external view override returns (uint256) {
        FNFTStakingXTokenUpgradeable xToken = FNFTStakingXTokenUpgradeable(vaultXToken(vaultId));
        return xToken.timelockUntil(who);
    }

    // Leave the bar. Claim back your tokens.
    // Unlocks the staked + gained tokens and burns xTokens.
    function withdraw(uint256 vaultId, uint256 _share) external virtual override {
        IERC20Upgradeable baseToken = IERC20Upgradeable(vaultManager.vault(vaultId));
        FNFTStakingXTokenUpgradeable xToken = FNFTStakingXTokenUpgradeable(xTokenAddr(address(baseToken)));

        uint256 baseTokensRedeemed = xToken.burnXTokens(msg.sender, _share);
        emit XTokenWithdrawn(vaultId, baseTokensRedeemed, _share, msg.sender);
    }

   function xTokenShareValue(uint256 vaultId) external view virtual override returns (uint256) {
        IERC20Upgradeable baseToken = IERC20Upgradeable(vaultManager.vault(vaultId));
        FNFTStakingXTokenUpgradeable xToken = FNFTStakingXTokenUpgradeable(xTokenAddr(address(baseToken)));
        if (!_isContract(address(xToken))) revert XTokenNotDeployed();

        uint256 multiplier = 10 ** 18;
        return xToken.totalSupply() > 0
            ? multiplier * baseToken.balanceOf(address(xToken)) / xToken.totalSupply()
            : multiplier;
    }

    function deployXTokenForVault(uint256 vaultId) public virtual override {
        address baseToken = vaultManager.vault(vaultId);
        address deployedXToken = xTokenAddr(address(baseToken));

        if (_isContract(deployedXToken)) {
            return;
        }

        address xToken = _deployXToken(baseToken);
        emit StakingPoolCreated(vaultId, xToken, baseToken);
    }

    function vaultXToken(uint256 vaultId) public view virtual override returns (address) {
        address baseToken = vaultManager.vault(vaultId);
        address xToken = xTokenAddr(baseToken);
        if (!_isContract(xToken)) revert XTokenNotDeployed();
        return xToken;
    }

    // Note: this function does not guarantee the token is deployed, we leave that check to elsewhere to save gas.
    function xTokenAddr(address baseToken) public view virtual override returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(baseToken));
        address tokenAddr = Create2.computeAddress(salt, keccak256(type(Create2BeaconProxy).creationCode));
        return tokenAddr;
    }

    function _deployXToken(address baseToken) internal returns (address) {
        string memory symbol = IERC20Metadata(baseToken).symbol();
        symbol = string(abi.encodePacked("x", symbol));
        bytes32 salt = keccak256(abi.encodePacked(baseToken));
        address deployedXToken = Create2.deploy(0, salt, BEACON_CODE);
        FNFTStakingXTokenUpgradeable(deployedXToken).__FNFTStakingXToken_init(baseToken, symbol, symbol);
        return deployedXToken;
    }

    function _isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size != 0;
    }

    function _timelockMintFor(uint256 vaultId, address account, uint256 _amount, uint256 timelockLength) internal returns (IERC20Upgradeable, FNFTStakingXTokenUpgradeable, uint256) {
        deployXTokenForVault(vaultId);
        IERC20Upgradeable baseToken = IERC20Upgradeable(vaultManager.vault(vaultId));
        FNFTStakingXTokenUpgradeable xToken = FNFTStakingXTokenUpgradeable((xTokenAddr(address(baseToken))));

        uint256 xTokensMinted = xToken.mintXTokens(account, _amount, timelockLength);
        return (baseToken, xToken, xTokensMinted);
    }
}
