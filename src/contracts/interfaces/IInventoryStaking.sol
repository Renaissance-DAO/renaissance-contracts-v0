// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./IVaultManager.sol";
import "./ITimelockExcludeList.sol";


interface IInventoryStaking {
    function vaultManager() external view returns (IVaultManager);

    function inventoryLockTimeErc20() external view returns (uint256);

    function timelockExcludeList() external view returns (ITimelockExcludeList);

    function __InventoryStaking_init(address _vaultManager) external;

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

    event XTokenCreated(uint256 vaultId, address baseToken, address xToken);
    event BaseTokenDeposited(uint256 vaultId, uint256 baseTokenAmount, uint256 xTokenAmount, uint256 timelockUntil, address sender);
    event BaseTokenWithdrawn(uint256 vaultId, uint256 baseTokenAmount, uint256 xTokenAmount, address sender);
    event FeesReceived(uint256 vaultId, uint256 amount);

    error LockTooLong();
    error NotZapContract();
    error NotExcludedFromFees();
    error XTokenNotDeployed();

}