// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Pausable is OwnableUpgradeable {

    function __Pausable_init() internal initializer {
        __Ownable_init();
    }

    event SetIsGuardian(address addr, bool isGuardian);
    event SetPaused(uint256 lockId, bool paused);

    mapping(address => bool) public isGuardian;
    mapping(uint256 => bool) public isPaused;
    // 0 : createVault
    // 1 : mint
    // 2 : redeem
    // 3 : swap
    // 4 : flashloan

    error Paused();
    error Unauthorized();

    function onlyOwnerIfPaused(uint256 lockId) public view virtual {
        if (isPaused[lockId] && msg.sender != owner()) revert Paused();
    }

    function pause(uint256 lockId) public virtual {
        if (!isGuardian[msg.sender]) revert Unauthorized();
        isPaused[lockId] = true;
        emit SetPaused(lockId, true);
    }

    function setIsGuardian(address _address, bool _isGuardian) public virtual onlyOwner {
        isGuardian[_address] = _isGuardian;
        emit SetIsGuardian(_address, _isGuardian);
    }

    function unpause(uint256 lockId)
        public
        virtual
        onlyOwner
    {
        isPaused[lockId] = false;
        emit SetPaused(lockId, false);
    }

}
