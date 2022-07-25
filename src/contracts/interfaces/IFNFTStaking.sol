// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./IVaultManager.sol";
import "./ITimelockExcludeList.sol";


interface IFNFTStaking {
    function vaultManager() external view returns (IVaultManager);

    function inventoryLockTimeErc20() external view returns (uint256);

    function timelockExcludeList() external view returns (ITimelockExcludeList);

    function __FNFTStaking_init(address _vaultManager) external;

    function setTimelockExcludeList(address _timelockExcludeList) external;

    function setInventoryLockTimeErc20(uint256 _inventoryLockTimeErc20) external;

    function isAddressTimelockExcluded(address addr, uint256 vaultId) external returns (bool);

    function deployXTokenForVault(uint256 vaultId) external;

    function receiveRewards(uint256 vaultId, uint256 amount) external returns (bool);

    function deposit(uint256 vaultId, uint256 _amount) external;

    function timelockMintFor(uint256 vaultId, uint256 amount, address to, uint256 timelockLength) external returns (uint256);

    function withdraw(uint256 vaultId, uint256 _share) external;

    function xTokenShareValue(uint256 vaultId) external returns (uint256);

    function timelockUntil(uint256 vaultId, address who) external returns (uint256);

    function balanceOf(uint256 vaultId, address who) external returns (uint256);

    function xTokenAddr(address baseToken) external returns (address);

    function vaultXToken(uint256 vaultId) external view returns (address);

    event StakingPoolCreated(uint256 vaultId, address xToken, address baseToken);
    event FeesReceived(uint256 vaultId, uint256 amount, address xToken);
    event BaseTokenDeposited(uint256 vaultId, uint256 baseTokenAmount, uint256 amount, uint256 timelockUntil, address sender);
    event XTokenWithdrawn(uint256 vaultId, uint256 baseTokenAmount, uint256 amount, address sender);

    event InventoryLockTimeErc20Updated(uint256 oldInventoryLockTimeErc20, uint256 newInventoryLockTimeErc20);
    event TimelockExcludeListUpdated(address oldTimelockExcludeList, address newTimelockExcludeList);

    error LockTooLong();
    error NotExcludedFromFees();
    error NotZapContract();
    error XTokenNotDeployed();

}