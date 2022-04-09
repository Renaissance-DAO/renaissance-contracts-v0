//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "ds-test/test.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {FNFTSettings} from "../../contracts/FNFTSettings.sol";
import {PriceOracle, IPriceOracle} from "../../contracts/PriceOracle.sol";
import {FNFTFactory} from "../../contracts/FNFTFactory.sol";
import {FNFT} from "../../contracts/FNFT.sol";
import {MockNFT} from "../../contracts/mocks/NFT.sol";
import {WETH} from "../../contracts/mocks/WETH.sol";
import {UniswapV2Factory} from "../../contracts/libraries/uniswap-v2/UniswapV2Factory.sol";
import {UniswapV2Router} from "../../contracts/libraries/uniswap-v2/UniswapV2Router.sol";
import {UniswapV2Library} from "../../contracts/libraries/UniswapV2Library.sol";
import {IUniswapV2Pair} from "../../contracts/interfaces/IUniswapV2Pair.sol";
import {console, CheatCodes, SetupEnvironment, User, Curator, UserNoETH} from "../utils/utils.sol";

contract FNFTIntegrationTest is DSTest, ERC721Holder {
    CheatCodes public vm;

    UniswapV2Factory public trisolarisFactory = UniswapV2Factory(0xc66F594268041dB60507F00703b152492fb176E7); //on aurora
    WETH public weth = WETH(0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB); //on aurora
    UniswapV2Router public router = UniswapV2Router(payable(0x2CB45Edb4517d5947aFdE3BEAbF95A582506858B));

    IPriceOracle public priceOracle;

    FNFTFactory public factory;
    FNFTSettings public settings;
    MockNFT public token;
    FNFT public fNFT;

    User public user1;
    User public user2;
    User public user3;

    UserNoETH public user4;

    Curator public curator;

    function setUp() public {
        vm = SetupEnvironment.setupVM();

        priceOracle = SetupEnvironment.setupPriceOracle(address(weth), address(trisolarisFactory));

        settings = new FNFTSettings(address(weth), address(priceOracle));

        settings.setGovernanceFee(10);

        factory = new FNFTFactory(address(settings));

        token = new MockNFT();

        token.mint(address(this), 1);

        token.setApprovalForAll(address(factory), true);

        fNFT = FNFT(factory.mint("testName", "TEST", address(token), 1, 100 ether, 1 ether, 50));

        // create a curator account
        curator = new Curator(address(factory));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fNFT));
        user2 = new User(address(fNFT));
        user3 = new User(address(fNFT));
        user4 = new UserNoETH(address(fNFT));

        payable(address(user1)).transfer(10 ether);
        payable(address(user2)).transfer(10 ether);
        payable(address(user3)).transfer(10 ether);
        payable(address(user4)).transfer(10 ether);
    }

    function testSetupLP() public {
        uint256 fNFTToProvide = 50e18;
        uint256 ethToProvide = 50 ether;
        fNFT.approve(address(router), fNFTToProvide);
        console.log("fnft address", address(fNFT));
        console.log("router address", address(fNFT));

        //providing 50 ether and 50 fNFT giving an implied value of 1 eth per fNFT token
        router.addLiquidityETH{value: ethToProvide}(
            address(fNFT),
            fNFTToProvide, //amountTokenDesired,
            0, //amountTokenMin, (doesn't matter on init)
            0, //amountETHMin, (doesn't matter on init)
            address(this), //to,
            block.timestamp //deadline
        );
        address pair = trisolarisFactory.getPair(address(weth), address(fNFT));

    }
}
