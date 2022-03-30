//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import {IPriceOracle} from "./IPriceOracle.sol";
import {IWETH} from "./IWETH.sol";

interface IFNFTSettings {
    function priceOracle() external returns (IPriceOracle);

    function WETH() external returns (IWETH);

    function maxAuctionLength() external returns (uint256);

    function minAuctionLength() external returns (uint256);

    function maxCuratorFee() external returns (uint256);

    function governanceFee() external returns (uint256);

    function minBidIncrease() external returns (uint256);

    function minVotePercentage() external returns (uint256);

    function maxReserveFactor() external returns (uint256);

    function minReserveFactor() external returns (uint256);

    function feeReceiver() external returns (address payable);
}
