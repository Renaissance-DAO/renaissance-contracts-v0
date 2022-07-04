// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPausable {
    function isPaused(uint256 pauseId) external view returns (bool);
}