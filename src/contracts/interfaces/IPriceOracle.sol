// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/UQ112x112.sol";
import "../libraries/math/FixedPoint.sol";
import "./IUniswapV2Factory.sol";

interface IPriceOracle {
    // Struct that contains metadata of two token pair that is stored in the liquidity pool.
    // Metadata used to calculated TWAP (Time-weighted average price).
    struct PairInfo {
        address token0;
        address token1;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
        uint216 totalUpdates;
        uint32 blockTimestampLast;
        bool exists;
    }

    function period() external view returns (uint256);

    function minimumPairInfoUpdate() external view returns (uint256);

    function WETH() external view returns (address);

    function factory() external view returns (IUniswapV2Factory);

    function __PriceOracle_init() external;

    function setPeriod(uint256 _period) external;

    function setMinimumPairInfoUpdate(uint256 _minimumPairInfoUpdate) external;

    function getPairAddress(address _token0, address _token1) external view returns (address);

    function getPairInfo(address _token0, address _token1) external view returns (PairInfo memory pairInfo);

    function getPairInfo(address _pair) external view returns (PairInfo memory pairInfo);

    function updatePairInfo(address _token0, address _token1) external;

    function updateFNFTPairInfo(address _fnft) external;

    function createFNFTPair(address _token0) external returns (address);

    function consult(
        address _token,
        address _pair,
        uint256 _amountIn
    ) external view returns (uint256 amountOut);

    function getFNFTPriceETH(address _fnft, uint256 _amountIn) external view returns (uint256 amountOut);

    event PeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event MinimumPairInfoUpdateUpdated(uint256 oldMinimumPairInfoUpdate, uint256 newMinimumPairInfoUpdate);

    error InvalidToken();
    error NotEnoughUpdates();
    error PairInfoAlreadyExists();
    error PairInfoDoesNotExist();
}
