//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./libraries/PriceOracleLibrary.sol";
import "./libraries/UQ112x112.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/math/FixedPoint.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

contract PriceOracle is IPriceOracle, Ownable {
    using FixedPoint for *;

    /**
    1. Store cumulative prices for each pair in the pool
    2. Update to calculate twap and update for each pair
     */
    uint256 public constant PERIOD = 10 minutes;

    // Map of pair address to PairInfo struct, which contains cumulative price, last block timestamps, and etc.
    mapping(address => PairInfo) private getTwap;

    address public immutable WETH;
    address public immutable FACTORY;

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

    constructor(address _factory, address _weth) {
        WETH = _weth;
        FACTORY = _factory;
    }

    function addPairInfo(address token0, address token1) external onlyOwner {
        // Get predetermined pair address.
        address pairAddress = UniswapV2Library.pairFor(FACTORY, token0, token1);
        PairInfo storage pairInfo = getTwap[pairAddress];
        require(pairInfo.exists == false, "Pair already exists.");

        // Get pair information for the given pair address.
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        // Ensure that there's liquidity in the pair.
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, "No reserved");

        // Initialize pairInfo for the
        pairInfo.token0 = pair.token0();
        pairInfo.token1 = pair.token1();
        pairInfo.price0CumulativeLast = pair.price0CumulativeLast(); // fetch the current accumulated price value (token1 / token0)
        pairInfo.price1CumulativeLast = pair.price1CumulativeLast(); // fetch the current accumulated price value (token0 / token1)
        pairInfo.blockTimestampLast = blockTimestampLast;
        pairInfo.exists = true;
    }

    function updatePairInfo(address _pair) external {
        _updatePairInfo(_pair);
    }

    function updatefNFTTWAP(address fNFT) external {
        address pair = UniswapV2Library.pairFor(FACTORY, WETH, fNFT);
        _updatePairInfo(pair);
    }

    function consult(
        address _token,
        address _pair,
        uint256 _amountIn
    ) external view returns (uint256 amountOut) {
        PairInfo memory pairInfo = getTwap[_pair];
        require(pairInfo.exists == true, "Pair does not exist.");
        if (_token == pairInfo.token0) {
            amountOut = pairInfo.price0Average.mul(_amountIn).decode144();
        } else {
            require(_token == pairInfo.token1, "Invalid token.");
            amountOut = pairInfo.price1Average.mul(_amountIn).decode144();
        }
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function getfNFTPriceETH(address _fNFT, uint256 _amountIn) external view returns (uint256 amountOut) {
        address pair = UniswapV2Library.pairFor(FACTORY, _fNFT, WETH);
        PairInfo memory pairInfo = getTwap[pair];
        require(pairInfo.exists == true, "PairInfo does not exist");
        require(pairInfo.totalUpdates > 10, "Pair has not been updated enough");

        if (_fNFT == pairInfo.token0) {
            amountOut = pairInfo.price0Average.mul(_amountIn).decode144();
        } else {
            require(_fNFT == pairInfo.token1, "Invalid token");
            amountOut = pairInfo.price1Average.mul(_amountIn).decode144();
        }
    }

    function _updatePairInfo(address _pair) internal {
        PairInfo storage pairInfo = getTwap[_pair];

        // we want an update to silently skip because it's updated from the token contract itself
        if (pairInfo.exists) {
            // Get cumulative prices for each token pairs and block timestampe in the pool.
            (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = PriceOracleLibrary
                .currentCumulativePrices(_pair);
            uint32 timeElapsed = blockTimestamp - pairInfo.blockTimestampLast;

            if (timeElapsed >= PERIOD) {
                // Overflow is desired, casting never truncates.
                // Cumulative price is in (uq112x112 price * seconds) uits so we simply wrap it after division by the time elapsed.
                FixedPoint.uq112x112 memory price0Average = FixedPoint.uq112x112(
                    uint224((price0Cumulative - pairInfo.price0CumulativeLast) / timeElapsed)
                );
                FixedPoint.uq112x112 memory price1Average = FixedPoint.uq112x112(
                    uint224((price1Cumulative - pairInfo.price1CumulativeLast) / timeElapsed)
                );
                pairInfo.price0Average = price0Average;
                pairInfo.price1Average = price1Average;
                pairInfo.price0CumulativeLast = price0Cumulative;
                pairInfo.price1CumulativeLast = price1Cumulative;
                pairInfo.blockTimestampLast = blockTimestamp;
                pairInfo.totalUpdates++;
            }
        }
    }
}
