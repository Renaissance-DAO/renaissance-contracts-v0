// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./IWETH.sol";
import "./ILPStaking.sol";
import "./IInventoryStaking.sol";
import "./IVaultManager.sol";
import "./IUniswapV2Router.sol";

interface IStakingZap {
    function WETH() external returns(IWETH);

    function lpStaking() external returns(ILPStaking);

    function inventoryStaking() external returns(IInventoryStaking);

    function vaultManager() external returns(IVaultManager);

    function router() external returns(IUniswapV2Router);

    function lpLockTime() external returns(uint256);

    function inventoryLockTime() external returns(uint256);

    function assignStakingContracts() external;

    function setLPLockTime(uint256 newLPLockTime) external;

    function setInventoryLockTime(uint256 newInventoryLockTime) external;

    function provideInventory721(uint256 vaultId, uint256[] calldata tokenIds) external;

    function provideInventory1155(uint256 vaultId, uint256[] calldata tokenIds, uint256[] calldata amounts) external;

    function addLiquidity721ETH(
        uint256 vaultId,
        uint256[] calldata ids,
        uint256 minWethIn
    ) external payable returns (uint256);

    function addLiquidity721ETHTo(
        uint256 vaultId,
        uint256[] memory ids,
        uint256 minWethIn,
        address to
    ) external payable returns (uint256);

    function addLiquidity1155ETH(
        uint256 vaultId,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        uint256 minEthIn
    ) external payable returns (uint256);

    function addLiquidity1155ETHTo(
        uint256 vaultId,
        uint256[] memory ids,
        uint256[] memory amounts,
        uint256 minEthIn,
        address to
    ) external payable returns (uint256);

    function addLiquidity721(
        uint256 vaultId,
        uint256[] calldata ids,
        uint256 minWethIn,
        uint256 wethIn
    ) external returns (uint256);

    function addLiquidity721To(
        uint256 vaultId,
        uint256[] memory ids,
        uint256 minWethIn,
        uint256 wethIn,
        address to
    ) external returns (uint256);

    function addLiquidity1155(
        uint256 vaultId,
        uint256[] memory ids,
        uint256[] memory amounts,
        uint256 minWethIn,
        uint256 wethIn
    ) external returns (uint256);

    function addLiquidity1155To(
        uint256 vaultId,
        uint256[] memory ids,
        uint256[] memory amounts,
        uint256 minWethIn,
        uint256 wethIn,
        address to
    ) external returns (uint256);

    function rescue(address token) external;

    error LockTooLong();
    error NotZero();
    error NotEqualLength();
    error IncorrectAmount();
    error CallFailed();
    error CallFailedWithMessage(string message);
    error NotOwner();
    error IdenticalAddress();
    error ZeroAddress();
    error OnlyWETH();
    error InvalidDestination();
    error NotExcluded();

    event UserStaked(uint256 vaultId, uint256 count, uint256 lpBalance, uint256 timelockUntil, address sender);
    event InventoryLockTimeUpdated(uint256 oldLockTime, uint256 newLockTime);
    event LPLockTimeUpdated(uint256 oldLockTime, uint256 newLockTime);
}
