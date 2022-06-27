pragma solidity ^0.8.0;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IUniswapV2Pair} from "../../contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../../contracts/interfaces/IUniswapV2Factory.sol";
import {UniswapV2Library} from "../../contracts/libraries/UniswapV2Library.sol";
import {IFNFTSingle} from "../../contracts/interfaces/IFNFTSingle.sol";
import {IWETH} from "../../contracts/interfaces/IWETH.sol";
import {MockERC20Upgradeable} from "../../contracts/mocks/ERC20.sol";
import {WETH} from "../../contracts/mocks/WETH.sol";
import {CheatCodes} from "./cheatcodes.sol";

contract Pair {
    IUniswapV2Pair public uPair;
    IUniswapV2Factory public uFactory;
    IERC20Upgradeable public token0;
    IERC20Upgradeable public token1;
    CheatCodes public vm;

    constructor(address _uniswapFactory, address _token0, address _token1, CheatCodes _vm) {
        address pairAddress = IUniswapV2Factory(_uniswapFactory).createPair(_token0, _token1);
        uFactory = IUniswapV2Factory(_uniswapFactory);
        uPair = IUniswapV2Pair(pairAddress);
        token0 = IERC20Upgradeable(_token0);
        token1 = IERC20Upgradeable(_token1);
        vm = _vm;
    }

    // Transfer ERC20 tokens and weth tokens to pair and sync reserves.
    function receiveToken(uint256 _token0Amount, uint256 _token1Amount) public {
        // Prank next call as the token owner.
        vm.startPrank(msg.sender);
        token0.approve(address(msg.sender), _token0Amount);
        token0.transfer(address(uPair), _token0Amount);

        token1.approve(address(msg.sender), _token1Amount);
        token1.transfer(address(uPair), _token1Amount);
        vm.stopPrank();

        uPair.sync();
    }

    // Sync uniswap pair to get the most updated cumulative price and last block.timestamp.
    function sync() public {
        uPair.sync();
    }

    // Get token reserves from uniswap.
    function getReserves() public view returns (uint256 reserve0, uint256 reserve1) {
        (reserve0, reserve1) = UniswapV2Library.getReserves(address(uFactory), address(token0), address(token1));
    }
}

contract PairWithWETH {
    IUniswapV2Pair public uPair;
    IUniswapV2Factory public uFactory;
    IERC20Upgradeable public token;
    IWETH public weth;
    CheatCodes public vm;

    constructor(address _uniswapFactory, address _token, address _weth, CheatCodes _vm) {
        address pairAddress = IUniswapV2Factory(_uniswapFactory).createPair(_token, _weth);
        uFactory = IUniswapV2Factory(_uniswapFactory);
        uPair = IUniswapV2Pair(pairAddress);
        token = IERC20Upgradeable(_token);
        weth = IWETH(_weth);
        vm = _vm;
    }

    // Transfer ERC20 tokens and weth tokens to pair and sync reserves.
    function receiveToken(uint256 _tokenAmount, uint256 _wethAmount) public {
        // Prank next call as the token owner.
        vm.startPrank(msg.sender);
        token.approve(address(msg.sender), _tokenAmount);
        token.transfer(address(uPair), _tokenAmount);

        weth.approve(address(msg.sender), _wethAmount);
        weth.transfer(address(uPair), _wethAmount);
        vm.stopPrank();

        uPair.sync();
    }

    // Sync uniswap pair to get the most updated cumulative price and last block.timestamp.
    function sync() public {
        uPair.sync();
    }

    // Get token reserves from uniswap.
    function getReserves() public view returns (uint256 reserve0, uint256 reserve1) {
        (reserve0, reserve1) = UniswapV2Library.getReserves(address(uFactory), address(token), address(weth));
    }
}

contract PairWithFNFTAndWETH{
    IUniswapV2Pair public uPair;
    IUniswapV2Factory public uFactory;
    IFNFTSingle public fnftSingle;
    IWETH public weth;
    CheatCodes public vm;

    constructor(address _uniswapFactory, address _fnft, address _weth, CheatCodes _vm) {
        address pairAddress = IUniswapV2Factory(_uniswapFactory).getPair(_fnft, _weth);
        uFactory = IUniswapV2Factory(_uniswapFactory);
        uPair = IUniswapV2Pair(pairAddress);
        fnftSingle = IFNFTSingle(_fnft);
        weth = IWETH(_weth);
        vm = _vm;
    }

    // Transfer fNFT and weth tokens to pair and sync reserves.
    function receiveToken(uint256 _fnftAmount, uint256 _wethAmount) public {
        // Prank next fnftSingle calls as the fnftSingle owner.
        vm.startPrank(msg.sender);
        IERC20Upgradeable(address(fnftSingle)).approve(address(msg.sender), _fnftAmount);
        IERC20Upgradeable(address(fnftSingle)).transfer(address(uPair), _fnftAmount);

        weth.approve(address(msg.sender), _wethAmount);
        weth.transfer(address(uPair), _wethAmount);
        vm.stopPrank();

        uPair.sync();
    }

    // Sync uniswap pair to get the most updated cumulative price and last block.timestamp.
    function sync() public {
        uPair.sync();
    }

    // Get token reserves from uniswap.
    function getReserves() public view returns (uint256 reserve0, uint256 reserve1) {
        (reserve0, reserve1) = UniswapV2Library.getReserves(address(uFactory), address(fnftSingle), address(weth));
    }
}
