// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {FNFTFactory} from "../contracts/FNFTFactory.sol";
import {PriceOracle, IPriceOracle, PairInfo} from "../contracts/PriceOracle.sol";
import {FNFTFactory} from "../contracts/FNFTFactory.sol";
import {FNFT} from "../contracts/FNFT.sol";
import {IUniswapV2Pair} from "../contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../contracts/interfaces/IUniswapV2Factory.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {CheatCodes, SetupEnvironment, User, Curator, UserNoETH, PairWithFNFTAndWETH} from "./utils/utils.sol";


// Test FNFT reserve price logic with PriceOracle to verify whether if it returns the correct price based
// on different conditions.
contract FNFTWithPriceOracleTest is DSTest, ERC721Holder, SetupEnvironment {
    IPriceOracle public priceOracle;
    IUniswapV2Factory public pairFactory;
    FNFTFactory public fnftFactory;
    MockNFT public token;
    FNFT public fnft;

    User public user1;
    User public user2;
    User public user3;


    PairWithFNFTAndWETH public pair;

    Curator public curator;

    function setUp() public {
        // Set up fnft environment.

        setupEnvironment(1000 ether);
        (pairFactory, priceOracle, , fnftFactory, fnft) = setupContracts(100 ether);

        // Initialize mock fnft-WETH pair with empty reserves.
        pair = new PairWithFNFTAndWETH(address(pairFactory), address(fnft), address(weth), vm);

        // create a curator account
        curator = new Curator(address(fnft));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fnft));
        user2 = new User(address(fnft));
        user3 = new User(address(fnft));

        payable(address(user1)).transfer(10 ether);
        payable(address(user2)).transfer(10 ether);
        payable(address(user3)).transfer(10 ether);
    }

    function testGetAuctionPrice_whenVotingBelowQuorumAndLiquidityBelowThreshold_returnInitialReserve() public {
        /**
        SETUP
         */
        // Transfer fnft to user to reduce the voting tokens and move below quorum.
        // Transfer is required since voting quroum is set at 100% during mint.
        uint256 tokenAmount = fnft.totalSupply() - ((fnftFactory.minVotePercentage() + 1000) * fnft.totalSupply() / 10000);
        fnft.transfer(address(user1), tokenAmount);

        // Transfer remaining of minted fnft to other user to seting the voting tokens to 0.
        fnft.transfer(address(user2), fnft.balanceOf(address(this)));

        /**
        ACTION
         */
        uint256 auctionPrice = fnft.getAuctionPrice();

        /**
        VERIFY
         */
        // verify that the fnft votes are below quorum.
        assertTrue(fnft.votingTokens() * 10000 <= fnftFactory.minVotePercentage() * fnft.totalSupply());

        // verify that the WETH reserves * 2 is lower than the liquidity threshold.
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 <= fnftFactory.liquidityThreshold());

        // verify that the auction price is equal to initial reserve of fnft.
        assertEq(auctionPrice, fnft.initialReserve());
    }

    function testGetAuctionPrice_whenVotingAboveQuorumAndLiquidityBelowThreshold_returnUserReservePrice() public {
        /**
        SETUP
         */
        // Transfer fnft to user so that the user holds more than the minium voting percentage.
        fnft.transfer(address(user1), (fnftFactory.minVotePercentage() + 1000) * fnft.totalSupply() / 10000);

        // Transfer remaining of minted fnft to other user to seting the voting tokens to 0.
        fnft.transfer(address(user2), fnft.balanceOf(address(this)));

        // Mock the next call as user and update reserve(user) price.
        uint userPrice = _deriveOptimumReservePrice(fnft.userReservePrice(address(user1)), fnftFactory.minReserveFactor(), fnftFactory.maxReserveFactor());
        vm.prank(address(user1));
        fnft.updateUserPrice(userPrice);

        /**
        ACTION
         */
        uint256 auctionPrice = fnft.getAuctionPrice();

        /**
        VERIFY
         */
        // verify that the fnft votes are above quorum.
        assertTrue(fnft.votingTokens() * 10000 > fnftFactory.minVotePercentage() * fnft.totalSupply());

        // verify that the WETH reserves * 2 is lower than the liquidity threshold.
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 <= fnftFactory.liquidityThreshold());

        // verify that the auction price is equal to user price of fnft.
        assertEq(auctionPrice, userPrice);
    }

    function testGetAuctionPrice_whenVotingBelowQuorumAndLiquidityAboveThreshold_compareTWAPAndInitialReserve() public {
        /**
        SETUP
         */
        // Transfer half of fnft total supply and total weth supply to Pair to create liquidity.
        pair.receiveToken(fnft.totalSupply() / 2, weth.totalSupply());

        // Update TWAP for fnft in WETH minimum required number of times to retrieve TWAP from price oracle.
        _updatePriceOracleMinimumTimes(address(priceOracle), address(pair.uPair()));

        // Transfer fnft to user so that the user holds less than the minimum voting percentage.
        fnft.transfer(address(user1), fnftFactory.minVotePercentage() * fnft.totalSupply() / 10000 - 1 ether);

        // Transfer the remaining fnft to other user to reduce the initial quorum set to 100%.
        fnft.transfer(address(user2), fnft.balanceOf(address(this)));

        // Mock the next call as user and update user reserve price.
        uint userPrice = _deriveOptimumReservePrice(fnft.userReservePrice(address(user1)),
                                                    fnftFactory.minReserveFactor(),
                                                    fnftFactory.maxReserveFactor());
        vm.prank(address(user1));
        fnft.updateUserPrice(userPrice);

        /**
        ACTION
         */
        uint256 auctionPrice = fnft.getAuctionPrice();

        /**
        VERIFY
         */
        // Verify that the quorum has not been reached.
        assertTrue(fnft.votingTokens() * 10000 < fnftFactory.minVotePercentage() * fnft.totalSupply());

        // Verify that the WETH reserves * 2 is higher than the liquidity threshold.
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 > fnftFactory.liquidityThreshold());

        // Verify that the auction price returns the compared price between TWAP and initial reserve.
        uint256 twapPrice = priceOracle.getFNFTPriceETH(address(fnft), fnft.totalSupply());
        uint256 initialReservePrice = fnft.initialReserve();
        assertEq(auctionPrice, twapPrice > initialReservePrice ? twapPrice : initialReservePrice);
    }

    function testGetAuctionPrice_whenVotingAboveQuorumAndLiquidityAboveThreshold_compareTWAPAndUserReservePrice() public {
        /**
        SETUP
         */
        // Distribute fnft amongst users(fnft holders) and liquidity pair.
        uint256 pairFNFTAmount = fnft.totalSupply() / 2;
        uint256 userFNFTAmount = fnft.totalSupply() / 2;

        pair.receiveToken(pairFNFTAmount, fnftFactory.liquidityThreshold() + 1 ether);
        fnft.transfer(address(user1), userFNFTAmount);

        // // Update TWAP for fnft in WETH minimum required number of times to retrieve TWAP from price oracle.
        _updatePriceOracleMinimumTimes(address(priceOracle), address(pair.uPair()));

        // Update user reserve price that is greater than twap price.
        uint256 userPrice = _deriveOptimumReservePrice(fnft.userReservePrice(address(user1)), fnftFactory.minReserveFactor(), fnftFactory.maxReserveFactor());
        vm.prank(address(user1));
        fnft.updateUserPrice(userPrice);

        /**
        ACTION
         */
        uint256 auctionPrice = fnft.getAuctionPrice();

        /**
        VERIFY
        */
        // verify that voting is above quorum and liquidity is above threshold.
        assertTrue(fnft.votingTokens() * 10000 > fnftFactory.minVotePercentage() * fnft.totalSupply());
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 > fnftFactory.liquidityThreshold());

        // verify that the auction price selects the maximum price between twap and user reserve price.
        uint256 reservePrice = fnft.reservePrice();
        uint256 twapPrice = priceOracle.getFNFTPriceETH(address(fnft), fnft.totalSupply());
        assertEq(auctionPrice, reservePrice >= twapPrice ? reservePrice : twapPrice);
    }

    function testBuyItNow() public {
        /**
        SETUP
         */
        // Setup environment where weth supply is more than the buy now price.
        uint256 fNFTAmount = 10 ether;
        uint256 wethAmount = fnft.buyItNowPrice();

        setupEnvironment(wethAmount);
        (pairFactory, priceOracle, , fnftFactory, fnft) = setupContracts(fNFTAmount);

        // Transfer ETH to user to pay for NFT.
        weth.transfer(address(user1), weth.totalSupply());

        /**
        ACTION
         */
        // Mock the next call as the user and call to purchase the NFT.
        vm.startPrank(address(user1));
        fnft.buyItNow{value: fnft.buyItNowPrice()}();
        vm.stopPrank();

        /**
        VERIFY
         */
        // verify that the user holds 1 NFT token after the purchase.
        assertEq(IERC721(fnft.token()).balanceOf(address(user1)), 1);
        // verify that the fnft contract holds the buy it now price.
        assertEq(weth.balanceOf(address(fnft)), fnft.buyItNowPrice());
    }

    function testUpdateUserPriceWhenNoVotingTokensAndPriceTooHigh() public {
        /**
        SETUP
         */
        // Transfer all of fnft to user to give all of voting power.
        fnft.transfer(address(user1), fnft.totalSupply());

        /**
        ACTION
         */
        // Mock the next call as the user and update the user price which is set higher than the maxium reserve price relative to intial reserve price,
        // since the total voting token is set to 0.
        uint256 userPrice = (fnft.initialReserve() * fnftFactory.maxReserveFactor() + 1 ether) / 10000;
        vm.startPrank(address(user1));
        vm.expectRevert(FNFT.PriceTooHigh.selector);
        fnft.updateUserPrice(userPrice);
    }

    function testUpdateUserPriceWhenNoVotingTokensAndPriceTooLow() public {
        /**
        SETUP
         */
        // Transfer all of fnft to user to give all of voting power.
        fnft.transfer(address(user1), fnft.totalSupply());

        /**
        ACTION
         */
        // Mock the next call as the user and update the user price which is set lower than the minimum reserve price relative to intial reserve price,
        // since the total voting token is set to 0.
        uint256 userPrice = (fnft.initialReserve() * fnftFactory.minReserveFactor() - 1 ether) / 10000;
        vm.startPrank(address(user1));
        vm.expectRevert(FNFT.PriceTooLow.selector);
        fnft.updateUserPrice(userPrice);
    }

    /**
    Derive optimum reserve price by calulating the average between minReserveFactor
    and maxReserveFactory and add to current fnft reserve price.
     */
    function _deriveOptimumReservePrice(uint256 _currentUserPrice, uint256 _minReserveFactor, uint256 _maxReserveFactor) internal pure returns (uint256) {
        uint256 averageReserveFactor = (_minReserveFactor + _maxReserveFactor) / 2;
        _currentUserPrice = _currentUserPrice == 0 ? 1 ether : _currentUserPrice;
        return _currentUserPrice + (_currentUserPrice * averageReserveFactor / 10000);
    }

    /**
    Update pair info in PriceOracle minimum number of times that is required to get fnft price in ETH.
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
