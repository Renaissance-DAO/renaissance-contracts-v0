//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./libraries/PriceOracleLibrary.sol";
import "./libraries/UQ112x112.sol";
import "./libraries/math/FixedPoint.sol";
import "./interfaces/IUniswapV2Factory.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

/**
    1. Store cumulative prices for each pair in the pool
    2. Update to calculate twap and update for each pair
*/
contract PriceOracle is IPriceOracle, OwnableUpgradeable {
    using FixedPoint for *;

    uint256 public override period;
    uint256 public override minimumPairInfoUpdate;

    // Map of pair address to PairInfo struct, which contains cumulative price, last block timestamps, and etc.
    mapping(address => PairInfo) private _getTwap;

    address public immutable override WETH;
    IUniswapV2Factory public immutable override FACTORY;

    constructor(address _factory, address _weth) {
        WETH = _weth;
        FACTORY = IUniswapV2Factory(_factory);
    }

    function __PriceOracle_init() external override initializer {
        __Ownable_init();

        period = 10 minutes;
        minimumPairInfoUpdate = 10;
    }

    // Set minimum period to wait for the next pair info update.
    function setPeriod(uint256 _newPeriod) external override onlyOwner {
        emit UpdatePeriod(period, _newPeriod);
        period = _newPeriod;
    }

    // Set minimum pair info info update required to get fNFT-WETH TWAP price.
    function setMinimumPairInfoUpdate(uint256 _newMinimumPairInfoUpdate) external override onlyOwner {
        emit UpdateMinimumPairInfoUpdate(minimumPairInfoUpdate, _newMinimumPairInfoUpdate);
        minimumPairInfoUpdate = _newMinimumPairInfoUpdate;
    }

    // Get pair address from factory. Returns address(0) if not found.
    function getPairAddress(address _token0, address _token1) external view override returns (address) {
        return _getPairAddress(_token0, _token1);
    }

    // Get pair info, which includes cumulative prices, last block timestamp, price average, and etc.
    function getPairInfo(address _token0, address _token1) external view override returns (PairInfo memory pairInfo) {
        address pairAddress = _getPairAddress(_token0, _token1);
        pairInfo = _getTwap[pairAddress];
    }

    // Get pair info with uniswap v2 pair address.
    function getPairInfo(address _pair) external view override returns (PairInfo memory pairInfo) {
        pairInfo = _getTwap[_pair];
    }

    // Update pair info.
    function updatePairInfo(address _token0, address _token1) external override {
        _updatePairInfo(_token0, _token1);
    }

    // Update fNFT-WETH pair info.
    function updateFNFTPairInfo(address _FNFT) external override {
        _updatePairInfo(_FNFT, WETH);
    }

    function createFNFTPair(address _token0) external override returns (address) {
        return _createPairAddress(_token0, WETH);
    }

    // Get TWAP price of a token.
    function consult(
        address _token,
        address _pair,
        uint256 _amountIn
    ) external view override returns (uint256 amountOut) {
        PairInfo memory pairInfo = _getTwap[_pair];
        if (!pairInfo.exists) revert PairInfoDoesNotExist();

        amountOut = _calculatePrice(_token, _amountIn, pairInfo);
    }

    // Get fNFT TWAP Price in ETH/WETH.
    // note this will always return 0 before update has been called successfully for the first time.
    function getFNFTPriceETH(address _FNFT, uint256 _amountIn) external view override returns (uint256 amountOut) {
        address pair = _getPairAddress(_FNFT, WETH);
        PairInfo memory pairInfo = _getTwap[pair];
        if (!pairInfo.exists) revert PairInfoDoesNotExist();
        if (pairInfo.totalUpdates < minimumPairInfoUpdate) revert NotEnoughUpdates();

        amountOut = _calculatePrice(_FNFT, _amountIn, pairInfo);
    }

    // Calculate token twap price based on pair info and the amount in.
    function _calculatePrice(address _token, uint256 _amountIn, PairInfo memory _pairInfo) internal pure returns (uint256 amountOut) {
        if (_token == _pairInfo.token0) {
            amountOut = _pairInfo.price0Average.mul(_amountIn).decode144();
        } else {
            if (_token != _pairInfo.token1) revert InvalidToken();
            amountOut = _pairInfo.price1Average.mul(_amountIn).decode144();
        }
    }

    // Update pair info of two token pair.
    function _updatePairInfo(address _token0, address _token1) internal {
        // Get predetermined pair address.
        address pairAddress = _getPairAddress(_token0, _token1);
        // Update or add pair info if the pair has been created from factory.
        if (pairAddress != address(0)){
            PairInfo storage pairInfo = _getTwap[pairAddress];
            // we want an update to silently skip because it's updated from the token contract itself
            if (pairInfo.exists) {
                // Get cumulative prices for each token pairs and block timestampe in the pool.
                (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = PriceOracleLibrary
                    .currentCumulativePrices(pairAddress);
                if (price0Cumulative != 0 && price1Cumulative != 0) {
                    uint32 timeElapsed = blockTimestamp - pairInfo.blockTimestampLast;
                    if (timeElapsed >= period) {
                        // Overflow is desired, casting never truncates.
                        // Cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by the time elapsed.
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
                        ++pairInfo.totalUpdates;
                    }
                }
            } else {
                _addPairInfo(_token0, _token1);
            }
        }
    }

    // Add pair info to price oracle.
    function _addPairInfo(address _token0, address _token1) internal {
        // Get predetermined pair address.
        address pairAddress = _getPairAddress(_token0, _token1);
        PairInfo storage pairInfo = _getTwap[pairAddress];
        if (pairInfo.exists) revert PairInfoAlreadyExists();

        // Get pair information for the given pair address.
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        // Get last block timestamp from reserves.
        (, , uint32 blockTimestampLast) = pair.getReserves();

        // Initialize pairInfo for the two tokens.
        pairInfo.token0 = pair.token0();
        pairInfo.token1 = pair.token1();
        pairInfo.price0CumulativeLast = pair.price0CumulativeLast(); // fetch the current accumulated price value (token1 / token0)
        pairInfo.price1CumulativeLast = pair.price1CumulativeLast(); // fetch the current accumulated price value (token0 / token1)
        pairInfo.blockTimestampLast = blockTimestampLast;
        pairInfo.exists = true;
    }

    // Get pair address from uniswap pair factory.
    function _getPairAddress(address _token0, address _token1) internal view returns (address) {
        return FACTORY.getPair(_token0, _token1);
    }

    // Create pair address from uniswap pair factory.
    function _createPairAddress(address _token0, address _token1) internal returns (address) {
        return FACTORY.createPair(_token0, _token1);
    }
}
