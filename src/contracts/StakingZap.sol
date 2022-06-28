// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/IStakingZap.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ILPStaking.sol";
import "./interfaces/IInventoryStaking.sol";
import "./interfaces/IFNFTCollection.sol";
import "./interfaces/IVaultManager.sol";
import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IUniswapV2Router.sol";

contract StakingZap is IStakingZap, Ownable, ReentrancyGuard, ERC721HolderUpgradeable, ERC1155HolderUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IWETH public immutable override WETH;
  ILPStaking public override lpStaking;
  IInventoryStaking public override inventoryStaking;
  IVaultManager public immutable override vaultManager;
  IUniswapV2Router public immutable override router;

  uint256 public override lpLockTime = 48 hours;
  uint256 public override inventoryLockTime = 7 days;
  uint256 constant BASE = 1e18;

  constructor(address _vaultManager, address _router) Ownable() ReentrancyGuard() {
    vaultManager = IVaultManager(_vaultManager);
    router = IUniswapV2Router(_router);
    WETH = IWETH(IUniswapV2Router(_router).WETH());
    IERC20Upgradeable(address(IUniswapV2Router(_router).WETH())).safeApprove(_router, type(uint256).max);
  }

  function assignStakingContracts() public override {
    if (address(lpStaking) != address(0) && address(inventoryStaking) != address(0)) revert NotZero();
    IFeeDistributor feeDistributor = IFeeDistributor(IVaultManager(vaultManager).feeDistributor());
    lpStaking = ILPStaking(feeDistributor.lpStaking());
    inventoryStaking = IInventoryStaking(feeDistributor.inventoryStaking());
  }

  function setLPLockTime(uint256 newLPLockTime) external override onlyOwner {
    if (newLPLockTime > 7 days) revert LockTooLong();
    emit LPLockTimeUpdated(lpLockTime, newLPLockTime);
    lpLockTime = newLPLockTime;
  }

  function setInventoryLockTime(uint256 newInventoryLockTime) external override onlyOwner {
    if (newInventoryLockTime > 14 days) revert LockTooLong();
    emit InventoryLockTimeUpdated(inventoryLockTime, newInventoryLockTime);
    inventoryLockTime = newInventoryLockTime;
  }

  function provideInventory721(uint256 vaultId, uint256[] calldata tokenIds) external override {
    uint256 count = tokenIds.length;
    IFNFTCollection vault = IFNFTCollection(vaultManager.vault(vaultId));
    inventoryStaking.timelockMintFor(vaultId, count*BASE, msg.sender, inventoryLockTime);
    address xToken = inventoryStaking.vaultXToken(vaultId);
    uint256 oldBal = IERC20Upgradeable(address(vault)).balanceOf(xToken);
    uint256[] memory amounts = new uint256[](0);
    address assetAddress = vault.assetAddress();
    uint256 length = tokenIds.length;
    for (uint256 i; i < length;) {
      transferFromERC721(assetAddress, tokenIds[i], address(vault));
      approveERC721(assetAddress, address(vault), tokenIds[i]);
      unchecked {
        ++i;
      }
    }
    vault.mintTo(tokenIds, amounts, address(xToken));
    uint256 newBal = IERC20Upgradeable(vault).balanceOf(xToken);
    if (newBal != oldBal + count*BASE) revert IncorrectAmount();
  }

  function provideInventory1155(uint256 vaultId, uint256[] calldata tokenIds, uint256[] calldata amounts) external override {
    uint256 length = tokenIds.length;
    if (length != amounts.length) revert NotEqualLength();
    uint256 count;
    for (uint256 i; i < length;) {
      count += amounts[i];
      unchecked {
        ++i;
      }
    }
    IFNFTCollection vault = IFNFTCollection(vaultManager.vault(vaultId));
    inventoryStaking.timelockMintFor(vaultId, count*BASE, msg.sender, inventoryLockTime);
    address xToken = inventoryStaking.vaultXToken(vaultId);
    uint256 oldBal = IERC20Upgradeable(vault).balanceOf(address(xToken));
    IERC1155Upgradeable nft = IERC1155Upgradeable(vault.assetAddress());
    nft.safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, "");
    nft.setApprovalForAll(address(vault), true);
    vault.mintTo(tokenIds, amounts, address(xToken));
    uint256 newBal = IERC20Upgradeable(vault).balanceOf(address(xToken));
    if (newBal != oldBal + count*BASE) revert IncorrectAmount();
  }

  function addLiquidity721ETH(
    uint256 vaultId,
    uint256[] calldata ids,
    uint256 minWethIn
  ) external payable override returns (uint256) {
    return addLiquidity721ETHTo(vaultId, ids, minWethIn, msg.sender);
  }

  function addLiquidity721ETHTo(
    uint256 vaultId,
    uint256[] memory ids,
    uint256 minWethIn,
    address to
  ) public payable override nonReentrant returns (uint256) {
    if (to == address(0) || to == address(this)) revert InvalidDestination();
    WETH.deposit{value: msg.value}();
    (, uint256 amountEth, uint256 liquidity) = _addLiquidity721WETH(vaultId, ids, minWethIn, msg.value, to);

    // Return extras.
    uint256 remaining = msg.value - amountEth;
    if (remaining != 0) {
      WETH.withdraw(remaining);
      (bool success, ) = payable(to).call{value: remaining}("");
      if (!success) revert CallFailed();
    }

    return liquidity;
  }

  function addLiquidity1155ETH(
    uint256 vaultId,
    uint256[] calldata ids,
    uint256[] calldata amounts,
    uint256 minEthIn
  ) external payable override returns (uint256) {
    return addLiquidity1155ETHTo(vaultId, ids, amounts, minEthIn, msg.sender);
  }

  function addLiquidity1155ETHTo(
    uint256 vaultId,
    uint256[] memory ids,
    uint256[] memory amounts,
    uint256 minEthIn,
    address to
  ) public payable override nonReentrant returns (uint256) {
    if (to == address(0) || to == address(this)) revert InvalidDestination();
    WETH.deposit{value: msg.value}();
    // Finish this.
    (, uint256 amountEth, uint256 liquidity) = _addLiquidity1155WETH(vaultId, ids, amounts, minEthIn, msg.value, to);

    // Return extras.
    uint256 remaining = msg.value - amountEth;
    if (remaining != 0) {
      WETH.withdraw(remaining);
      (bool success, ) = payable(to).call{value: remaining}("");
      if (!success) revert CallFailed();
    }

    return liquidity;
  }

  function addLiquidity721(
    uint256 vaultId,
    uint256[] calldata ids,
    uint256 minWethIn,
    uint256 wethIn
  ) external override returns (uint256) {
    return addLiquidity721To(vaultId, ids, minWethIn, wethIn, msg.sender);
  }

  function addLiquidity721To(
    uint256 vaultId,
    uint256[] memory ids,
    uint256 minWethIn,
    uint256 wethIn,
    address to
  ) public override nonReentrant returns (uint256) {
    if (to == address(0) || to == address(this)) revert InvalidDestination();
    IERC20Upgradeable(address(WETH)).safeTransferFrom(msg.sender, address(this), wethIn);
    (, uint256 amountEth, uint256 liquidity) = _addLiquidity721WETH(vaultId, ids, minWethIn, wethIn, to);

    // Return extras.
    uint256 remaining = wethIn-amountEth;
    if (remaining != 0) {
      WETH.transfer(to, remaining);
    }

    return liquidity;
  }

  function addLiquidity1155(
    uint256 vaultId,
    uint256[] memory ids,
    uint256[] memory amounts,
    uint256 minWethIn,
    uint256 wethIn
  ) public override returns (uint256) {
    return addLiquidity1155To(vaultId, ids, amounts, minWethIn, wethIn, msg.sender);
  }

  function addLiquidity1155To(
    uint256 vaultId,
    uint256[] memory ids,
    uint256[] memory amounts,
    uint256 minWethIn,
    uint256 wethIn,
    address to
  ) public override nonReentrant returns (uint256) {
    if (to == address(0) || to == address(this)) revert InvalidDestination();
    IERC20Upgradeable(address(WETH)).safeTransferFrom(msg.sender, address(this), wethIn);
    (, uint256 amountEth, uint256 liquidity) = _addLiquidity1155WETH(vaultId, ids, amounts, minWethIn, wethIn, to);

    // Return extras.
    uint256 remaining = wethIn-amountEth;
    if (remaining != 0) {
      WETH.transfer(to, remaining);
    }

    return liquidity;
  }

  function _addLiquidity721WETH(
    uint256 vaultId,
    uint256[] memory ids,
    uint256 minWethIn,
    uint256 wethIn,
    address to
  ) internal returns (uint256, uint256, uint256) {
    if (!vaultManager.excludedFromFees(address(this))) revert NotExcluded();
    address vault = vaultManager.vault(vaultId);

    address assetAddress = IFNFTCollection(vault).assetAddress();
    uint256 length = ids.length;
    for (uint256 i; i < length; i++) {
      transferFromERC721(assetAddress, ids[i], vault);
      approveERC721(assetAddress, vault, ids[i]);
    }
    uint256[] memory emptyIds;
    IFNFTCollection(vault).mint(ids, emptyIds);
    uint256 balance = length * BASE; // We should not be experiencing fees.

    return _addLiquidityAndLock(vaultId, vault, balance, minWethIn, wethIn, to);
  }

  function _addLiquidity1155WETH(
    uint256 vaultId,
    uint256[] memory ids,
    uint256[] memory amounts,
    uint256 minWethIn,
    uint256 wethIn,
    address to
  ) internal returns (uint256, uint256, uint256) {
    if (!vaultManager.excludedFromFees(address(this))) revert NotExcluded();
    address vault = vaultManager.vault(vaultId);

    address assetAddress = IFNFTCollection(vault).assetAddress();
    IERC1155Upgradeable(assetAddress).safeBatchTransferFrom(msg.sender, address(this), ids, amounts, "");
    IERC1155Upgradeable(assetAddress).setApprovalForAll(vault, true);

    uint256 count = IFNFTCollection(vault).mint(ids, amounts);
    uint256 balance = (count * BASE); // We should not be experiencing fees.

    return _addLiquidityAndLock(vaultId, vault, balance, minWethIn, wethIn, to);
  }

  function _addLiquidityAndLock(
    uint256 vaultId,
    address vault,
    uint256 minTokenIn,
    uint256 minWethIn,
    uint256 wethIn,
    address to
  ) internal returns (uint256, uint256, uint256) {
    // Provide liquidity.
    IERC20Upgradeable(vault).safeApprove(address(router), minTokenIn);
    (uint256 amountToken, uint256 amountEth, uint256 liquidity) = router.addLiquidity(
      address(vault),
      address(WETH),
      minTokenIn,
      wethIn,
      minTokenIn,
      minWethIn,
      address(this),
      block.timestamp
    );

    // Stake in LP rewards contract
    address lpToken = pairFor(vault, address(WETH));
    IERC20Upgradeable(lpToken).safeApprove(address(lpStaking), liquidity);
    lpStaking.timelockDepositFor(vaultId, to, liquidity, lpLockTime);

    uint256 remaining = minTokenIn-amountToken;
    if (remaining != 0) {
      IERC20Upgradeable(vault).safeTransfer(to, remaining);
    }

    uint256 lockEndTime = block.timestamp + lpLockTime;
    emit UserStaked(vaultId, minTokenIn, liquidity, lockEndTime, to);
    return (amountToken, amountEth, liquidity);
  }

    // function removeLiquidity(
    //     address tokenA,
    //     address tokenB,
    //     uint256 liquidity,
    //     uint256 amountAMin,
    //     uint256 amountBMin,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256 amountA, uint256 amountB);
    // function removeLiquidityETH(
    //     address token,
    //     uint256 liquidity,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256 amountToken, uint256 amountETH);
  function _removeLiquidityAndLock(
    uint256 vaultId,
    address vault,
    uint256 minTokenIn,
    uint256 minWethIn,
    uint256 wethIn,
    address to
  ) internal returns (uint256, uint256, uint256) {
    // Provide liquidity.
    IERC20Upgradeable(vault).safeApprove(address(router), minTokenIn);
    (uint256 amountToken, uint256 amountEth, uint256 liquidity) = router.addLiquidity(
      address(vault),
      address(WETH),
      minTokenIn,
      wethIn,
      minTokenIn,
      minWethIn,
      address(this),
      block.timestamp
    );

    // Stake in LP rewards contract
    address lpToken = pairFor(vault, address(WETH));
    IERC20Upgradeable(lpToken).safeApprove(address(lpStaking), liquidity);
    lpStaking.timelockDepositFor(vaultId, to, liquidity, lpLockTime);

    uint256 remaining = minTokenIn-amountToken;
    if (remaining != 0) {
      IERC20Upgradeable(vault).safeTransfer(to, remaining);
    }

    uint256 lockEndTime = block.timestamp + lpLockTime;
    emit UserStaked(vaultId, minTokenIn, liquidity, lockEndTime, to);
    return (amountToken, amountEth, liquidity);
  }

  function transferFromERC721(address assetAddr, uint256 tokenId, address to) internal virtual {
    address kitties = 0x06012c8cf97BEaD5deAe237070F9587f8E7A266d;
    address punks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    bytes memory data;
    if (assetAddr == kitties) {
        // Cryptokitties.
        data = abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, to, tokenId);
    } else if (assetAddr == punks) {
        // CryptoPunks.
        // Fix here for frontrun attack. Added in v1.0.2.
        bytes memory punkIndexToAddress = abi.encodeWithSignature("punkIndexToAddress(uint256)", tokenId);
        (bool checkSuccess, bytes memory result) = address(assetAddr).staticcall(punkIndexToAddress);
        (address nftOwner) = abi.decode(result, (address));
        if (!checkSuccess || nftOwner != msg.sender) revert NotOwner();
        data = abi.encodeWithSignature("buyPunk(uint256)", tokenId);
    } else {
        // Default.
        // We push to the vault to avoid an unneeded transfer.
        data = abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", msg.sender, to, tokenId);
    }
    (bool success, bytes memory resultData) = address(assetAddr).call(data);
    if (!success) revert CallFailedWithMessage(string(resultData));
  }

  function approveERC721(address assetAddr, address to, uint256 tokenId) internal virtual {
    address kitties = 0x06012c8cf97BEaD5deAe237070F9587f8E7A266d;
    address punks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    bytes memory data;
    if (assetAddr == kitties) {
        // Cryptokitties.
        // data = abi.encodeWithSignature("approve(address,uint256)", to, tokenId);
        // No longer needed to approve with pushing.
        return;
    } else if (assetAddr == punks) {
        // CryptoPunks.
        data = abi.encodeWithSignature("offerPunkForSaleToAddress(uint256,uint256,address)", tokenId, 0, to);
    } else {
      // No longer needed to approve with pushing.
      return;
    }
    (bool success, bytes memory resultData) = address(assetAddr).call(data);
    if (!success) revert CallFailedWithMessage(string(resultData));
  }

  // calculates the CREATE2 address for a pair without making any external calls
  function pairFor(address tokenA, address tokenB) internal view returns (address pair) {
    (address token0, address token1) = sortTokens(tokenA, tokenB);
    pair = address(uint160(uint256(keccak256(abi.encodePacked(
      hex'ff',
      router.factory(),
      keccak256(abi.encodePacked(token0, token1)),
      hex'754e1d90e536e4c1df81b7f030f47b4ca80c87120e145c294f098c83a6cb5ace' // init code hash
    )))));
  }

  // returns sorted token addresses, used to handle return values from pairs sorted in this order
  function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
    if (tokenA == tokenB) revert IdenticalAddress();
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    if (token0 == address(0)) revert ZeroAddress();
  }

  receive() external payable {
    if (msg.sender != address(WETH)) revert OnlyWETH();
  }

  function rescue(address token) external override onlyOwner {
    if (token == address(0)) {
      (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
      if (!success) revert CallFailed();
    } else {
      IERC20Upgradeable(token).safeTransfer(msg.sender, IERC20Upgradeable(token).balanceOf(address(this)));
    }
  }
}