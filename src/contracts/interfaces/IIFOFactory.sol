//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIFOFactory {
    function getIFO(address _fnft) external view returns (address);

    function creatorIFOLock() external view returns (bool);

    function minimumDuration() external view returns (uint256);

    function maximumDuration() external view returns (uint256);

    function creatorUtilityContract() external view returns (address);

    function governanceFee() external view returns (uint256);

    function feeReceiver() external view returns (address payable);

    function setFeeReceiver(address payable _receiver) external;
}
