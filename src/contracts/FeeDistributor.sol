// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./interfaces/IFNFTStaking.sol";
import "./interfaces/IFeeDistributor.sol";
import "./interfaces/ILPStaking.sol";
import "./interfaces/IVaultManager.sol";
import "./util/Pausable.sol";

contract FeeDistributor is IFeeDistributor, ReentrancyGuardUpgradeable, Pausable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  FeeReceiver[] public override feeReceivers;

  IFNFTStaking public override fnftStaking;
  ILPStaking public override lpStaking;
  IVaultManager public override vaultManager;
  address public override treasury;

  // Total allocation points per vault.
  uint256 public override allocTotal;
  bool public override distributionPaused;

  function __FeeDistributor_init(address _vaultManager, address _lpStaking, address _treasury) external override initializer {
    __Pausable_init();

    vaultManager = IVaultManager(_vaultManager);

    setTreasuryAddress(_treasury);
    setLPStakingAddress(_lpStaking);

    _addReceiver(0.8 ether, _lpStaking, true);
  }

  function addReceiver(uint256 _allocPoint, address _receiver, bool _isContract) external override virtual onlyOwner  {
    _addReceiver(_allocPoint, _receiver, _isContract);
  }

  function distribute(uint256 vaultId) external override virtual nonReentrant {
    IVaultManager _vaultManager = vaultManager;
    if (address(_vaultManager) == address(0)) revert ZeroAddress();
    address _vault = _vaultManager.vault(vaultId);

    uint256 tokenBalance = IERC20Upgradeable(_vault).balanceOf(address(this));

    if (distributionPaused || allocTotal == 0) {
      IERC20Upgradeable(_vault).safeTransfer(treasury, tokenBalance);
      return;
    }

    uint256 length = feeReceivers.length;
    uint256 leftover;
    for (uint256 i; i < length;) {
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
      unchecked {
        ++i;
      }
    }

    if (leftover != 0) {
      uint256 currentTokenBalance = IERC20Upgradeable(_vault).balanceOf(address(this));
      IERC20Upgradeable(_vault).safeTransfer(treasury, currentTokenBalance);
    }
  }

  function initializeVaultReceivers(uint256 _vaultId) external override {
    if (msg.sender != address(vaultManager)) revert NotVaultManager();
    lpStaking.addPoolForVault(_vaultId);
    IFNFTStaking _inventoryStaking = fnftStaking;
    if (address(_inventoryStaking) != address(0))
      _inventoryStaking.deployXTokenForVault(_vaultId);
  }

  function pauseFeeDistribution(bool _pause) external override onlyOwner {
    distributionPaused = _pause;
    emit DistributionPaused(_pause);
  }

  function removeReceiver(uint256 _receiverIdx) external override virtual onlyOwner {
    uint256 arrLength = feeReceivers.length;
    if (_receiverIdx >= arrLength) revert OutOfBounds();
    emit FeeReceiverRemoved(feeReceivers[_receiverIdx].receiver);
    allocTotal -= feeReceivers[_receiverIdx].allocPoint;
    // Copy the last element to what is being removed and remove the last element.
    feeReceivers[_receiverIdx] = feeReceivers[arrLength-1];
    feeReceivers.pop();
  }

  function rescueTokens(address _address) external override onlyOwner {
    uint256 balance = IERC20Upgradeable(_address).balanceOf(address(this));
    IERC20Upgradeable(_address).safeTransfer(msg.sender, balance);
  }

  function changeReceiverAddress(uint256 _receiverIdx, address _address, bool _isContract) public override virtual onlyOwner {
    FeeReceiver storage feeReceiver = feeReceivers[_receiverIdx];
    address oldReceiver = feeReceiver.receiver;
    feeReceiver.receiver = _address;
    feeReceiver.isContract = _isContract;
    emit FeeReceiverAddressUpdated(oldReceiver, _address);
  }

  function changeReceiverAlloc(uint256 _receiverIdx, uint256 _allocPoint) public override virtual onlyOwner {
    if(_receiverIdx >= feeReceivers.length) revert OutOfBounds();
    FeeReceiver storage feeReceiver = feeReceivers[_receiverIdx];
    allocTotal -= feeReceiver.allocPoint;
    feeReceiver.allocPoint = _allocPoint;
    allocTotal += _allocPoint;
    emit FeeReceiverAllocUpdated(feeReceiver.receiver, _allocPoint);
  }

  function setFNFTStakingAddress(address _inventoryStaking) public override onlyOwner {
    fnftStaking = IFNFTStaking(_inventoryStaking);
    emit FNFTStakingAddressUpdated(_inventoryStaking);
  }

  function setLPStakingAddress(address _lpStaking) public override onlyOwner {
    if (_lpStaking == address(0)) revert ZeroAddress();
    lpStaking = ILPStaking(_lpStaking);
    emit LPStakingAddressUpdated(_lpStaking);
  }

  function setTreasuryAddress(address _treasury) public override onlyOwner {
    if (_treasury == address(0)) revert ZeroAddress();
    treasury = _treasury;
    emit TreasuryAddressUpdated(_treasury);
  }

  function _addReceiver(uint256 _allocPoint, address _receiver, bool _isContract) internal virtual {
    FeeReceiver memory _feeReceiver = FeeReceiver(_allocPoint, _receiver, _isContract);
    feeReceivers.push(_feeReceiver);
    allocTotal += _allocPoint;
    emit FeeReceiverAdded(_receiver, _allocPoint);
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