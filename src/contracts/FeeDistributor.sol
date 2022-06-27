// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./interfaces/ILPStaking.sol";
import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IInventoryStaking.sol";
import "./interfaces/IVaultManager.sol";
import "./util/Pausable.sol";

contract FeeDistributor is IFeeDistributor, ReentrancyGuardUpgradeable, Pausable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  bool public distributionPaused;

  address public override vaultManager;
  address public override lpStaking;
  address public override treasury;

  // Total allocation points per vault.
  uint256 public override allocTotal;
  FeeReceiver[] public feeReceivers;

  address public override inventoryStaking;

  event UpdateTreasuryAddress(address newTreasury);
  event UpdateLPStakingAddress(address newLPStaking);
  event UpdateInventoryStakingAddress(address newInventoryStaking);
  event UpdateVaultManager(address vaultManager);
  event PauseDistribution(bool paused);

  event AddFeeReceiver(address receiver, uint256 allocPoint);
  event UpdateFeeReceiverAlloc(address receiver, uint256 allocPoint);
  event UpdateFeeReceiverAddress(address oldReceiver, address newReceiver);
  event RemoveFeeReceiver(address receiver);

  error CallerIsNotVaultManager();
  error VaultManagerIsImmutable();
  error OutOfBounds();
  error ZeroAddress();

  function __FeeDistributor_init(address _vaultManager, address _lpStaking, address _treasury) public override initializer {
    __Pausable_init();
    setTreasuryAddress(_treasury);
    setLPStakingAddress(_lpStaking);
    setVaultManager(_vaultManager);

    _addReceiver(0.8 ether, lpStaking, true);
  }

  function distribute(uint256 vaultId) external override virtual nonReentrant {
    if (vaultManager == address(0)) revert ZeroAddress();
    address _vault = IVaultManager(vaultManager).vault(vaultId);

    uint256 tokenBalance = IERC20Upgradeable(_vault).balanceOf(address(this));

    if (distributionPaused || allocTotal == 0) {
      IERC20Upgradeable(_vault).safeTransfer(treasury, tokenBalance);
      return;
    }

    uint256 length = feeReceivers.length;
    uint256 leftover;
    for (uint256 i; i < length; ++i) {
      FeeReceiver memory _feeReceiver = feeReceivers[i];
      uint256 amountToSend = leftover + ((tokenBalance * _feeReceiver.allocPoint) / allocTotal);
      uint256 currentTokenBalance = IERC20Upgradeable(_vault).balanceOf(address(this));
      amountToSend = amountToSend > currentTokenBalance ? currentTokenBalance : amountToSend;
      bool complete = _sendForReceiver(_feeReceiver, vaultId, _vault, amountToSend);
      if (!complete) {
        uint256 remaining = IERC20Upgradeable(_vault).allowance(address(this), _feeReceiver.receiver);
        IERC20Upgradeable(_vault).safeApprove(_feeReceiver.receiver, 0);
        leftover = remaining;
      } else {
        leftover = 0;
      }
    }

    if (leftover != 0) {
      uint256 currentTokenBalance = IERC20Upgradeable(_vault).balanceOf(address(this));
      IERC20Upgradeable(_vault).safeTransfer(treasury, currentTokenBalance);
    }
  }

  function addReceiver(uint256 _allocPoint, address _receiver, bool _isContract) external override virtual onlyOwner  {
    _addReceiver(_allocPoint, _receiver, _isContract);
  }

  function initializeVaultReceivers(uint256 _vaultId) external override {
    if (msg.sender != vaultManager) revert CallerIsNotVaultManager();
    ILPStaking(lpStaking).addPoolForVault(_vaultId);
    if (inventoryStaking != address(0))
      IInventoryStaking(inventoryStaking).deployXTokenForVault(_vaultId);
  }

  function changeReceiverAlloc(uint256 _receiverIdx, uint256 _allocPoint) public override virtual onlyOwner {
    if(_receiverIdx >= feeReceivers.length) revert OutOfBounds();
    FeeReceiver storage feeReceiver = feeReceivers[_receiverIdx];
    allocTotal -= feeReceiver.allocPoint;
    feeReceiver.allocPoint = _allocPoint;
    allocTotal += _allocPoint;
    emit UpdateFeeReceiverAlloc(feeReceiver.receiver, _allocPoint);
  }

  function changeReceiverAddress(uint256 _receiverIdx, address _address, bool _isContract) public override virtual onlyOwner {
    FeeReceiver storage feeReceiver = feeReceivers[_receiverIdx];
    address oldReceiver = feeReceiver.receiver;
    feeReceiver.receiver = _address;
    feeReceiver.isContract = _isContract;
    emit UpdateFeeReceiverAddress(oldReceiver, _address);
  }

  function removeReceiver(uint256 _receiverIdx) external override virtual onlyOwner {
    uint256 arrLength = feeReceivers.length;
    if (_receiverIdx >= arrLength) revert OutOfBounds();
    emit RemoveFeeReceiver(feeReceivers[_receiverIdx].receiver);
    allocTotal -= feeReceivers[_receiverIdx].allocPoint;
    // Copy the last element to what is being removed and remove the last element.
    feeReceivers[_receiverIdx] = feeReceivers[arrLength-1];
    feeReceivers.pop();
  }

  function setTreasuryAddress(address _treasury) public override onlyOwner {
    if (_treasury == address(0)) revert ZeroAddress();
    treasury = _treasury;
    emit UpdateTreasuryAddress(_treasury);
  }

  function setLPStakingAddress(address _lpStaking) public override onlyOwner {
    if (_lpStaking == address(0)) revert ZeroAddress();
    lpStaking = _lpStaking;
    emit UpdateLPStakingAddress(_lpStaking);
  }

  function setInventoryStakingAddress(address _inventoryStaking) public override onlyOwner {
    inventoryStaking = _inventoryStaking;
    emit UpdateInventoryStakingAddress(_inventoryStaking);
  }

  function setVaultManager(address _vaultManager) public override onlyOwner {
    if (address(vaultManager) != address(0)) revert VaultManagerIsImmutable();
    vaultManager = _vaultManager;
    emit UpdateVaultManager(_vaultManager);
  }

  function pauseFeeDistribution(bool _pause) external onlyOwner {
    distributionPaused = _pause;
    emit PauseDistribution(_pause);
  }

  function rescueTokens(address _address) external override onlyOwner {
    uint256 balance = IERC20Upgradeable(_address).balanceOf(address(this));
    IERC20Upgradeable(_address).safeTransfer(msg.sender, balance);
  }

  function _addReceiver(uint256 _allocPoint, address _receiver, bool _isContract) internal virtual {
    FeeReceiver memory _feeReceiver = FeeReceiver(_allocPoint, _receiver, _isContract);
    feeReceivers.push(_feeReceiver);
    allocTotal += _allocPoint;
    emit AddFeeReceiver(_receiver, _allocPoint);
  }

  function _sendForReceiver(FeeReceiver memory _receiver, uint256 _vaultId, address _vault, uint256 amountToSend) internal virtual returns (bool) {
    if (_receiver.isContract) {
      IERC20Upgradeable(_vault).safeIncreaseAllowance(_receiver.receiver, amountToSend);

      bytes memory payload = abi.encodeWithSelector(ILPStaking.receiveRewards.selector, _vaultId, amountToSend);
      (bool success, ) = address(_receiver.receiver).call(payload);

      // If the allowance has not been spent, it means we can pass it forward to next.
      return success && IERC20Upgradeable(_vault).allowance(address(this), _receiver.receiver) == 0;
    } else {
      IERC20Upgradeable(_vault).safeTransfer(_receiver.receiver, amountToSend);
      return true;
    }
  }
}