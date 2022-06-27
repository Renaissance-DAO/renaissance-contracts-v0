// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {PriceOracle, IPriceOracle, PairInfo} from "../contracts/PriceOracle.sol";
import {FNFTSingleFactory} from "../contracts/FNFTSingleFactory.sol";
import {FNFTSingle} from "../contracts/FNFTSingle.sol";
import {IUniswapV2Pair} from "../contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../contracts/interfaces/IUniswapV2Factory.sol";
import {IFNFTSingle} from "../contracts/interfaces/IFNFTSingle.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {CheatCodes, SetupEnvironment, User, Curator, UserNoETH, PairWithFNFTAndWETH} from "./utils/utils.sol";


// Test FNFTSingle reserve price logic with PriceOracle to verify whether if it returns the correct price based
// on different conditions.
contract FNFTWithPriceOracleTest is DSTest, ERC721Holder, SetupEnvironment {
    IPriceOracle public priceOracle;
    IUniswapV2Factory public pairFactory;
    FNFTSingleFactory public fnftSingleFactory;
    MockNFT public token;
    FNFTSingle public fnftSingle;

    User public user1;
    User public user2;
    User public user3;


    PairWithFNFTAndWETH public pair;

    Curator public curator;

    function setUp() public {
        // Set up fnftSingle environment.

        setupEnvironment(1000 ether);
        (   ,
            ,
            ,
            pairFactory,
            priceOracle,
            ,
            ,
            fnftSingleFactory,
            ,
        ) = setupContracts();
        fnftSingle = setupFNFTSingle(address(fnftSingleFactory), 100 ether);

        // Initialize mock fnftSingle-WETH pair with empty reserves.
        pair = new PairWithFNFTAndWETH(address(pairFactory), address(fnftSingle), address(weth), vm);

        // create a curator account
        curator = new Curator(address(fnftSingle));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fnftSingle));
        user2 = new User(address(fnftSingle));
        user3 = new User(address(fnftSingle));

        payable(address(user1)).transfer(10 ether);
        payable(address(user2)).transfer(10 ether);
        payable(address(user3)).transfer(10 ether);
    }

    function testGetAuctionPrice_whenVotingBelowQuorumAndLiquidityBelowThreshold_returnInitialReserve() public {
        /**
        SETUP
         */
        // Transfer fnftSingle to user to reduce the voting tokens and move below quorum.
        // Transfer is required since voting quroum is set at 100% during mint.
        uint256 tokenAmount = fnftSingle.totalSupply() - ((fnftSingleFactory.minVotePercentage() + 1000) * fnftSingle.totalSupply() / 10000);
        fnftSingle.transfer(address(user1), tokenAmount);

        // Transfer remaining of minted fnftSingle to other user to seting the voting tokens to 0.
        fnftSingle.transfer(address(user2), fnftSingle.balanceOf(address(this)));

        /**
        ACTION
         */
        uint256 auctionPrice = fnftSingle.getAuctionPrice();

        /**
        VERIFY
         */
        // verify that the fnftSingle votes are below quorum.
        assertTrue(fnftSingle.votingTokens() * 10000 <= fnftSingleFactory.minVotePercentage() * fnftSingle.totalSupply());

        // verify that the WETH reserves * 2 is lower than the liquidity threshold.
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 <= fnftSingleFactory.liquidityThreshold());

        // verify that the auction price is equal to initial reserve of fnftSingle.
        assertEq(auctionPrice, fnftSingle.initialReserve());
    }

    function testGetAuctionPrice_whenVotingAboveQuorumAndLiquidityBelowThreshold_returnUserReservePrice() public {
        /**
        SETUP
         */
        // Transfer fnftSingle to user so that the user holds more than the minium voting percentage.
        fnftSingle.transfer(address(user1), (fnftSingleFactory.minVotePercentage() + 1000) * fnftSingle.totalSupply() / 10000);

        // Transfer remaining of minted fnftSingle to other user to seting the voting tokens to 0.
        fnftSingle.transfer(address(user2), fnftSingle.balanceOf(address(this)));

        // Mock the next call as user and update reserve(user) price.
        uint userPrice = _deriveOptimumReservePrice(fnftSingle.userReservePrice(address(user1)), fnftSingleFactory.minReserveFactor(), fnftSingleFactory.maxReserveFactor());
        vm.prank(address(user1));
        fnftSingle.updateUserPrice(userPrice);

        /**
        ACTION
         */
        uint256 auctionPrice = fnftSingle.getAuctionPrice();

        /**
        VERIFY
         */
        // verify that the fnftSingle votes are above quorum.
        assertTrue(fnftSingle.votingTokens() * 10000 > fnftSingleFactory.minVotePercentage() * fnftSingle.totalSupply());

        // verify that the WETH reserves * 2 is lower than the liquidity threshold.
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 <= fnftSingleFactory.liquidityThreshold());

        // verify that the auction price is equal to user price of fnftSingle.
        assertEq(auctionPrice, userPrice);
    }

    function testGetAuctionPrice_whenVotingBelowQuorumAndLiquidityAboveThreshold_compareTWAPAndInitialReserve() public {
        /**
        SETUP
         */
        // Transfer half of fnftSingle total supply and total weth supply to Pair to create liquidity.
        pair.receiveToken(fnftSingle.totalSupply() / 2, weth.totalSupply());

        // Update TWAP for fnftSingle in WETH minimum required number of times to retrieve TWAP from price oracle.
        _updatePriceOracleMinimumTimes(address(priceOracle), address(pair.uPair()));

        // Transfer fnftSingle to user so that the user holds less than the minimum voting percentage.
        fnftSingle.transfer(address(user1), fnftSingleFactory.minVotePercentage() * fnftSingle.totalSupply() / 10000 - 1 ether);

        // Transfer the remaining fnftSingle to other user to reduce the initial quorum set to 100%.
        fnftSingle.transfer(address(user2), fnftSingle.balanceOf(address(this)));

        // Mock the next call as user and update user reserve price.
        uint userPrice = _deriveOptimumReservePrice(fnftSingle.userReservePrice(address(user1)),
                                                    fnftSingleFactory.minReserveFactor(),
                                                    fnftSingleFactory.maxReserveFactor());
        vm.prank(address(user1));
        fnftSingle.updateUserPrice(userPrice);

        /**
        ACTION
         */
        uint256 auctionPrice = fnftSingle.getAuctionPrice();

        /**
        VERIFY
         */
        // Verify that the quorum has not been reached.
        assertTrue(fnftSingle.votingTokens() * 10000 < fnftSingleFactory.minVotePercentage() * fnftSingle.totalSupply());

        // Verify that the WETH reserves * 2 is higher than the liquidity threshold.
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 > fnftSingleFactory.liquidityThreshold());

        // Verify that the auction price returns the compared price between TWAP and initial reserve.
        uint256 twapPrice = priceOracle.getFNFTPriceETH(address(fnftSingle), fnftSingle.totalSupply());
        uint256 initialReservePrice = fnftSingle.initialReserve();
        assertEq(auctionPrice, twapPrice > initialReservePrice ? twapPrice : initialReservePrice);
    }

    function testGetAuctionPrice_whenVotingAboveQuorumAndLiquidityAboveThreshold_compareTWAPAndUserReservePrice() public {
        /**
        SETUP
         */
        // Distribute fnftSingle amongst users(fnftSingle holders) and liquidity pair.
        uint256 pairFNFTAmount = fnftSingle.totalSupply() / 2;
        uint256 userFNFTAmount = fnftSingle.totalSupply() / 2;

        pair.receiveToken(pairFNFTAmount, fnftSingleFactory.liquidityThreshold() + 1 ether);
        fnftSingle.transfer(address(user1), userFNFTAmount);

        // // Update TWAP for fnftSingle in WETH minimum required number of times to retrieve TWAP from price oracle.
        _updatePriceOracleMinimumTimes(address(priceOracle), address(pair.uPair()));

        // Update user reserve price that is greater than twap price.
        uint256 userPrice = _deriveOptimumReservePrice(fnftSingle.userReservePrice(address(user1)), fnftSingleFactory.minReserveFactor(), fnftSingleFactory.maxReserveFactor());
        vm.prank(address(user1));
        fnftSingle.updateUserPrice(userPrice);

        /**
        ACTION
         */
        uint256 auctionPrice = fnftSingle.getAuctionPrice();

        /**
        VERIFY
        */
        // verify that voting is above quorum and liquidity is above threshold.
        assertTrue(fnftSingle.votingTokens() * 10000 > fnftSingleFactory.minVotePercentage() * fnftSingle.totalSupply());
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 > fnftSingleFactory.liquidityThreshold());

        // verify that the auction price selects the maximum price between twap and user reserve price.
        uint256 reservePrice = fnftSingle.reservePrice();
        uint256 twapPrice = priceOracle.getFNFTPriceETH(address(fnftSingle), fnftSingle.totalSupply());
        assertEq(auctionPrice, reservePrice >= twapPrice ? reservePrice : twapPrice);
    }

    function testBuyItNow() public {
        /**
        SETUP
         */
        // Setup environment where weth supply is more than the buy now price.
        uint256 FNFTAmount = 10 ether;
        uint256 wethAmount = fnftSingle.buyItNowPrice();

        setupEnvironment(wethAmount);
        (   ,
            ,
            ,
            pairFactory,
            priceOracle,
            ,
            ,
            fnftSingleFactory,
            ,
        ) = setupContracts();
        fnftSingle = setupFNFTSingle(address(fnftSingleFactory), FNFTAmount);

        // Transfer ETH to user to pay for NFT.
        weth.transfer(address(user1), weth.totalSupply());

        /**
        ACTION
         */
        // Mock the next call as the user and call to purchase the NFT.
        vm.startPrank(address(user1));
        fnftSingle.buyItNow{value: fnftSingle.buyItNowPrice()}();
        vm.stopPrank();

        /**
        VERIFY
         */
        // verify that the user holds 1 NFT token after the purchase.
        assertEq(IERC721(fnftSingle.token()).balanceOf(address(user1)), 1);
        // verify that the fnftSingle contract holds the buy it now price.
        assertEq(weth.balanceOf(address(fnftSingle)), fnftSingle.buyItNowPrice());
    }

    function testUpdateUserPriceWhenNoVotingTokensAndPriceTooHigh() public {
        /**
        SETUP
         */
        // Transfer all of fnftSingle to user to give all of voting power.
        fnftSingle.transfer(address(user1), fnftSingle.totalSupply());

        /**
        ACTION
         */
        // Mock the next call as the user and update the user price which is set higher than the maxium reserve price relative to intial reserve price,
        // since the total voting token is set to 0.
        uint256 userPrice = (fnftSingle.initialReserve() * fnftSingleFactory.maxReserveFactor() + 1 ether) / 10000;
        vm.startPrank(address(user1));
        vm.expectRevert(IFNFTSingle.PriceTooHigh.selector);
        fnftSingle.updateUserPrice(userPrice);
    }

    function testUpdateUserPriceWhenNoVotingTokensAndPriceTooLow() public {
        /**
        SETUP
         */
        // Transfer all of fnftSingle to user to give all of voting power.
        fnftSingle.transfer(address(user1), fnftSingle.totalSupply());

        /**
        ACTION
         */
        // Mock the next call as the user and update the user price which is set lower than the minimum reserve price relative to intial reserve price,
        // since the total voting token is set to 0.
        uint256 userPrice = (fnftSingle.initialReserve() * fnftSingleFactory.minReserveFactor() - 1 ether) / 10000;
        vm.startPrank(address(user1));
        vm.expectRevert(IFNFTSingle.PriceTooLow.selector);
        fnftSingle.updateUserPrice(userPrice);
    }

    /**
    Derive optimum reserve price by calulating the average between minReserveFactor
    and maxReserveFactory and add to current fnftSingle reserve price.
     */
    function _deriveOptimumReservePrice(uint256 _currentUserPrice, uint256 _minReserveFactor, uint256 _maxReserveFactor) internal pure returns (uint256) {
        uint256 averageReserveFactor = (_minReserveFactor + _maxReserveFactor) / 2;
        _currentUserPrice = _currentUserPrice == 0 ? 1 ether : _currentUserPrice;
        return _currentUserPrice + (_currentUserPrice * averageReserveFactor / 10000);
    }

    /**
    Update pair info in PriceOracle minimum number of times that is required to get fnftSingle price in ETH.
     */
    function _updatePriceOracleMinimumTimes(address _priceOracle, address _pair) internal {
        PairInfo memory pairInfo = IPriceOracle(_priceOracle).getPairInfo(_pair);
        uint blockTimestampLast = pairInfo.blockTimestampLast;

        // Move block.timestamp forward and sync uniswap pair and update price oracle.
        // Update price oracle pair 10 times to meet the requirement.
        uint jump = priceOracle.period();
        for (uint i = 0; i < priceOracle.minimumPairInfoUpdate(); i++) {
            blockTimestampLast += jump;
            vm.warp(blockTimestampLast);
            IUniswapV2Pair(_pair).sync();
            priceOracle.updatePairInfo(pairInfo.token0, pairInfo.token1);
        }
    }

    receive() external payable {}
}
