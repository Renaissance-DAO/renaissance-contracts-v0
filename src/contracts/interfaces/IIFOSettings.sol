//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IIFOSettings {
    function creatorIFOLock() external returns (bool);

    function minimumDuration() external returns (uint256);

    function maximumDuration() external returns (uint256);

    function creatorUtilityContract() external returns (address);
}
