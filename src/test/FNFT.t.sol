//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {FNFTSettings} from "../contracts/FNFTSettings.sol";
import {PriceOracle, IPriceOracle} from "../contracts/PriceOracle.sol";
import {FNFTFactory, ERC721Holder} from "../contracts/FNFTFactory.sol";
import {FNFT} from "../contracts/FNFT.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {console, CheatCodes, SetupEnvironment, User, Curator, UserNoETH} from "./utils/utils.sol";


/// @author Nibble Market
/// @title Tests for the vaults
contract FNFTTest is DSTest, ERC721Holder {
    CheatCodes public vm;

    WETH public weth;
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
        (vm, weth, , priceOracle) = SetupEnvironment.setup();

        settings = new FNFTSettings(address(weth), address(priceOracle));

        settings.setGovernanceFee(10);

        factory = new FNFTFactory(address(settings));

        token = new MockNFT();

        token.mint(address(this), 1);

        token.setApprovalForAll(address(factory), true);
        factory.mint("testName", "TEST", address(token), 1, 100 ether, 1 ether, 50);

        fNFT = FNFT(factory.fnfts(0));

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

    function testTransferBetweenUsers() public {
        console.log("this balance", fNFT.balanceOf(address(this)) / 1e18);
        console.log("this reserve price", fNFT.userReservePrice(address(this)) / 1e18);
        console.log("user1 reserve price", fNFT.userReservePrice(address(user1)) / 1e18);
        console.log("voting tokens", fNFT.votingTokens() / 1e18);
        console.log("actual fNFT reserve price", fNFT.reservePrice() / 1e18);
        console.log("TRANSFER__________________");

        fNFT.transfer(address(user1), 100 ether);
        console.log("voting tokens", fNFT.votingTokens() / 1e18);
        console.log("this reserve price", fNFT.userReservePrice(address(this)) / 1e18);
        console.log("user1 balance", fNFT.balanceOf(address(user1)) / 1e18);
        console.log("user1 reserve price", fNFT.userReservePrice(address(user1)) / 1e18);
        console.log("actual fNFT reserve price", fNFT.reservePrice() / 1e18);
        console.log("TRANSFER__________________");

        user1.call_transfer((address(user2)), 20 ether);
        console.log("voting tokens", fNFT.votingTokens() / 1e18);
        console.log("user2 reserve price", fNFT.userReservePrice(address(user2)) / 1e18);
        console.log("user2 balance", fNFT.balanceOf(address(user2)) / 1e18);
        console.log("user2 reserve price", fNFT.userReservePrice(address(user2)) / 1e18);
        console.log("actual fNFT reserve price", fNFT.reservePrice() / 1e18);
    }

    function testPause() public {
        factory.pause();
        factory.unpause();
        MockNFT temp = new MockNFT();

        temp.mint(address(this), 1);

        temp.setApprovalForAll(address(factory), true);
        factory.mint("testName2", "TEST2", address(temp), 1, 100e18, 1 ether, 50);
    }

    function testFail_pause() public {
        factory.pause();
        MockNFT temp = new MockNFT();

        temp.mint(address(this), 1);

        temp.setApprovalForAll(address(factory), true);
        factory.mint("testName2", "TEST2", address(temp), 1, 100e18, 1 ether, 50);
    }

    /// -------------------------------
    /// -------- GOV FUNCTIONS --------
    /// -------------------------------

    function testKickCurator() public {
        fNFT.updateCurator(address(curator));
        assertTrue(fNFT.curator() == address(curator));
        fNFT.kickCurator(address(this));
        assertTrue(fNFT.curator() == address(this));
    }

    function testFail_kickCurator() public {
        curator.call_kickCurator(address(curator));
    }

    function testChangeReserve() public {
        // reserve price here should not change
        fNFT.transfer(address(user1), 50e18);
        assertEq(fNFT.reservePrice(), 1 ether);
        assertEq(fNFT.votingTokens(), 50e18);

        assertEq(fNFT.userReservePrice(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(fNFT.reservePrice(), 1.5 ether);

        // lets pretend user1 found an exploit to push up their reserve price
        fNFT.removeReserve(address(user1));
        assertEq(fNFT.userReservePrice(address(user1)), 0);
        assertEq(fNFT.reservePrice(), 1 ether);
        assertEq(fNFT.votingTokens(), 50e18);
    }

    function testFail_ChangeReserve() public {
        // reserve price here should not change
        fNFT.transfer(address(user1), 50e18);
        assertEq(fNFT.reservePrice(), 1 ether);
        assertEq(fNFT.votingTokens(), 50e18);

        assertEq(fNFT.userReservePrice(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(fNFT.reservePrice(), 1.5 ether);

        // user1 is not gov so cannot do anything
        user1.call_remove(address(this));
    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    function testupdateCurator() public {
        fNFT.updateCurator(address(curator));
        assertTrue(fNFT.curator() == address(curator));
    }

    function testFail_updateCurator() public {
        curator.call_updateCurator(address(curator));
    }

    function testupdateAuctionLength() public {
        fNFT.updateAuctionLength(2 weeks);
        assertTrue(fNFT.auctionLength() == 2 weeks);
    }

    function testFail_updateAuctionLength() public {
        fNFT.updateAuctionLength(0.1 days);
    }

    function testFail_updateAuctionLength2() public {
        fNFT.updateAuctionLength(100 weeks);
    }

    function testupdateFee() public {
        fNFT.updateFee(25);
        assertEq(fNFT.fee(), 25);
    }

    function testFail_updateFee() public {
        fNFT.updateFee(101);
    }

    function testclaimFees() public {
        // curator fee is 5%
        // gov fee is 1%
        // we should increase total supply by 6%
        vm.warp(block.timestamp + 31536000 seconds);
        fNFT.claimFees();
        assertTrue(fNFT.totalSupply() >= 105999999999900000000 && fNFT.totalSupply() < 106000000000000000000);
    }

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    function testInitialReserve() public {
        assertEq(fNFT.reservePrice(), 1 ether);
    }

    function testReservePriceTransfer() public {
        // reserve price here should not change
        fNFT.transfer(address(user1), 50e18);
        assertEq(fNFT.reservePrice(), 1 ether);
        assertEq(fNFT.votingTokens(), 50e18);

        assertEq(fNFT.userReservePrice(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(fNFT.reservePrice(), 1.5 ether);

        // now user 1 sends 2/5 their tokens to user 2
        // reserve price is now 1 * 5 + 2 * 3 / 8 = 1.375
        user1.call_transfer(address(user2), 20e18);
        assertEq(fNFT.reservePrice(), 1.375 ether);

        // now they are voting the same as user1 was so we go back to 1.5 eth
        user2.call_updatePrice(2 ether);
        assertEq(fNFT.reservePrice(), 1.5 ether);

        // send all tokens back to first user
        // their reserve price is 1 ether and they hold all tokens
        user1.call_transfer(address(this), 30e18);
        user2.call_transfer(address(this), 20e18);
        assertEq(fNFT.reservePrice(), 1 ether);
    }

    function testBid() public {
        fNFT.transfer(address(user1), 25e18);
        user1.call_updatePrice(1 ether);
        fNFT.transfer(address(user2), 25e18);
        user2.call_updatePrice(1 ether);
        fNFT.transfer(address(user3), 50e18);
        user3.call_updatePrice(1 ether);

        user1.call_start(1.05 ether);

        assertTrue(fNFT.auctionState() == FNFT.State.live);

        uint256 bal = address(user1).balance;
        user2.call_bid(1.5 ether);
        assertEq(bal + 1.05 ether, address(user1).balance);

        bal = address(user2).balance;
        user1.call_bid(2 ether);
        assertEq(bal + 1.5 ether, address(user2).balance);

        vm.warp(block.timestamp + 7 days);

        fNFT.end();

        assertEq(token.balanceOf(address(user1)), 1);

        // auction has ended. Now lets get all token holders their WETH since they are contracts
        // user1 gets 1/4 of 2 ETH or 0.5 ETH
        // user2 gets 1/4 of 2 ETH or 0.5 ETH
        // this gets 1/2 of 2 ETH or 1 ETH
        uint256 user1Bal = address(user1).balance;
        uint256 user2Bal = address(user2).balance;
        uint256 user3Bal = address(user3).balance;

        user1.call_cash();
        uint256 wethBal = address(user1).balance;
        assertEq(user1Bal + 499425318811235702, wethBal);

        user2.call_cash();
        wethBal = address(user2).balance;
        assertEq(user2Bal + 499425318811235702, wethBal);

        user3.call_cash();
        wethBal = address(user3).balance;
        assertEq(user3Bal + 998850637622471404, wethBal);

        assertTrue(fNFT.auctionState() == FNFT.State.ended);
    }

    function testRedeem() public {
        fNFT.redeem();

        assertTrue(fNFT.auctionState() == FNFT.State.redeemed);

        assertEq(token.balanceOf(address(this)), 1);
    }

    function testCannotGetEth() public {
        fNFT.transfer(address(user1), 25 * 1e18);
        user1.call_updatePrice(1 ether);
        fNFT.transfer(address(user2), 25 * 1e18);
        user2.call_updatePrice(1 ether);
        fNFT.transfer(address(user4), 50 * 1e18);
        user4.call_updatePrice(1 ether);

        user4.call_start(1.05 ether);
        user4.setCanReceive(false);
        assertTrue(fNFT.auctionState() == FNFT.State.live);
        vm.expectRevert(bytes(""));
        user2.call_bid(1.5 ether);
    }

    function testFail_notEnoughVoting() public {
        // now only 24% of tokens are voting so we fail
        fNFT.transfer(address(user1), 76e18);

        user1.call_start(1.05 ether);
    }

    function testListPriceZero() public {
        token.mint(address(this), 2);

        factory.mint("testName", "TEST", address(token), 2, 100e18, 0, 50);

        fNFT = FNFT(factory.fnfts(1));

        assertEq(fNFT.votingTokens(), 0);
    }

    function testFail_listPriceZeroNoAuction() public {
        token.mint(address(this), 2);

        factory.mint("testName", "TEST", address(token), 2, 100e18, 0, 50);

        fNFT = FNFT(factory.fnfts(1));

        User userTemp = new User(address(fNFT));

        userTemp.call_start(1.05 ether);
    }

    function testTransfer() public {
        fNFT.transfer(address(user1), 25e18);
    }

    function testAuctionEndCurator0() public {
        fNFT.updateFee(0);
        fNFT.updateCurator(address(0));
        settings.setGovernanceFee(0);
        fNFT.transfer(address(user1), 25e18);
        user1.call_updatePrice(1 ether);
        fNFT.transfer(address(user2), 25e18);
        user2.call_updatePrice(1 ether);
        fNFT.transfer(address(user3), 50e18);
        user3.call_updatePrice(1 ether);

        user1.call_start(1.05 ether);

        assertTrue(fNFT.auctionState() == FNFT.State.live);

        uint256 bal = address(user1).balance;
        user2.call_bid(1.5 ether);
        assertEq(bal + 1.05 ether, address(user1).balance);

        bal = address(user2).balance;
        user1.call_bid(2 ether);
        assertEq(bal + 1.5 ether, address(user2).balance);

        vm.warp(block.timestamp + 7 days);

        fNFT.end();

        assertEq(token.balanceOf(address(user1)), 1);

        // auction has ended. Now lets get all token holders their WETH since they are contracts
        // user1 gets 1/4 of 2 ETH or 0.5 ETH
        // user2 gets 1/4 of 2 ETH or 0.5 ETH
        // this gets 1/2 of 2 ETH or 1 ETH
        uint256 user1Bal = address(user1).balance;
        uint256 user2Bal = address(user2).balance;
        uint256 user3Bal = address(user3).balance;

        user1.call_cash();
        uint256 wethBal = address(user1).balance;
        assertEq(user1Bal + 0.5 ether, wethBal);

        user2.call_cash();
        wethBal = address(user2).balance;
        assertEq(user2Bal + 0.5 ether, wethBal);

        user3.call_cash();
        wethBal = address(user3).balance;
        assertEq(user3Bal + 1 ether, wethBal);

        assertTrue(fNFT.auctionState() == FNFT.State.ended);
    }

    receive() external payable {}
}
