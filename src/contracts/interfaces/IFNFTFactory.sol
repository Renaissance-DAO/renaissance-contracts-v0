//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IPriceOracle} from "./IPriceOracle.sol";
import {IWETH} from "./IWETH.sol";

interface IFNFTFactory {
    function priceOracle() external view returns (address);

    function ifoFactory() external view returns (address);

    function WETH() external view returns (address);

    function maxAuctionLength() external view returns (uint256);

    function minAuctionLength() external view returns (uint256);

    function maxCuratorFee() external view returns (uint256);

    function governanceFee() external view returns (uint256);

    function minBidIncrease() external view returns (uint256);

    function minVotePercentage() external view returns (uint256);

    function maxReserveFactor() external view returns (uint256);

    function minReserveFactor() external view returns (uint256);

    function liquidityThreshold() external view returns (uint256);

    function instantBuyMultiplier() external view returns (uint256);

    function feeReceiver() external view returns (address payable);

    function setFeeReceiver(address payable _receiver) external;
}
