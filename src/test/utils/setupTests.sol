// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "ds-test/test.sol";
import {CheatCodes} from "./cheatcodes.sol";
import {WETH} from "../../contracts/mocks/WETH.sol";
import {PriceOracle} from "../../contracts/PriceOracle.sol";
import {UniswapV2Factory} from "../../contracts/libraries/uniswap-v2/UniswapV2Factory.sol";

library SetupEnvironment {
    function setupWETH(uint256 amountToMint) public returns (WETH weth) {
        weth = new WETH(amountToMint, "Wrapped Ether", 18, "WETH");
    }

    function setupV2Factory() public returns (UniswapV2Factory v2Factory) {
        v2Factory = new UniswapV2Factory(address(this));
    }

    function setupPriceOracle(address v2Factory, address weth) public returns (PriceOracle priceOracle) {
        priceOracle = new PriceOracle(v2Factory, weth);
    }

    function setup()
        public
        returns (
            CheatCodes vm,
            WETH weth,
            UniswapV2Factory v2Factory,
            PriceOracle priceOracle
        )
    {
        vm = CheatCodes(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        weth = setupWETH(10 ether);
        v2Factory = setupV2Factory();
        priceOracle = setupPriceOracle(address(v2Factory), address(weth));
    }
}
