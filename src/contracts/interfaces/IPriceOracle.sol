// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
interface IPriceOracle {
    function updatePairInfo(address _pair) external;

    function updatefNFTTWAP(address fNFT) external;

    function consult(
        address _token,
        address _pair,
        uint256 _amountIn
    ) external view returns (uint256 amountOut);

    function getfNFTPriceETH(address _fNFT, uint256 _amountIn) external view returns (uint256 amountOut);
}
