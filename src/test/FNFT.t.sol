//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Deployer} from "../contracts/proxy/Deployer.sol";
import {MultiProxyController} from "../contracts/proxy/MultiProxyController.sol";
import {IFOFactory} from "../contracts/IFOFactory.sol";
import {IFO} from "../contracts/IFO.sol";
import {FNFTFactory} from "../contracts/FNFTFactory.sol";
import {PriceOracle, IPriceOracle} from "../contracts/PriceOracle.sol";
import {FNFT} from "../contracts/FNFT.sol";
import {IUniswapV2Factory} from "../contracts/interfaces/IUniswapV2Factory.sol";
import {IWETH} from "../contracts/interfaces/IWETH.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {console, CheatCodes, SetupEnvironment, User, Curator, UserNoETH, PairWithFNFTAndWETH} from "./utils/utils.sol";
import {ERC20FlashMintUpgradeable} from "../contracts/token/ERC20FlashMintUpgradeable.sol";
import {FlashBorrower} from "./utils/FlashBorrower.sol";

/// @author Nibble Market
/// @title Tests for the vaults
contract FNFTTest is DSTest, ERC721Holder, SetupEnvironment {
    IFOFactory public ifoFactory;
    IPriceOracle public priceOracle;
    IUniswapV2Factory public pairFactory;
    FNFTFactory public fnftFactory;
    MockNFT public token;
    FNFT public fnft;

    User public user1;
    User public user2;
    User public user3;
    UserNoETH public user4;

    PairWithFNFTAndWETH public pair;

    Curator public curator;

    function setUp() public {
        setupEnvironment(10 ether);
        (pairFactory, priceOracle, ifoFactory, fnftFactory, ) = setupContracts(10 ether);

        fnftFactory.setFee(FNFTFactory.FeeType.GovernanceFee, 100);

        token = new MockNFT();

        token.mint(address(this), 1);

        token.setApprovalForAll(address(fnftFactory), true);

        // FNFT minted on this test contract address.
        fnft = FNFT(fnftFactory.mint(
            "testName",
            "TEST",
            address(token),
            1,
            100 ether, // supply
            1 ether, // initialReserve
            500 // fee (5%)
        ));

        // create a curator account
        curator = new Curator(address(fnft));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fnft));
        user2 = new User(address(fnft));
        user3 = new User(address(fnft));
        user4 = new UserNoETH(address(fnft));

        payable(address(user1)).transfer(10 ether);
        payable(address(user2)).transfer(10 ether);
        payable(address(user3)).transfer(10 ether);
        payable(address(user4)).transfer(10 ether);
    }

    function test_InitializeFeeTooHigh() public {
        uint256 maxCuratorFee = fnftFactory.maxCuratorFee();
        token.mint(address(this), 2);
        vm.expectRevert(FNFT.FeeTooHigh.selector);
        fnft = FNFT(fnftFactory.mint(
            "TheFeeIsTooDamnHigh",
            "HIGH",
            address(token),
            2,
            100 ether, // supply
            1 ether, // list price
            maxCuratorFee + 1
        ));
    }

    function testTransferBetweenUsers() public {
        console.log("this balance", fnft.balanceOf(address(this)) / 1e18);
        console.log("this reserve price", fnft.userReservePrice(address(this)) / 1e18);
        console.log("user1 reserve price", fnft.userReservePrice(address(user1)) / 1e18);
        console.log("voting tokens", fnft.votingTokens() / 1e18);
        console.log("actual fnft reserve price", fnft.reservePrice() / 1e18);
        console.log("TRANSFER__________________");

        fnft.transfer(address(user1), 100 ether);
        console.log("voting tokens", fnft.votingTokens() / 1e18);
        console.log("this reserve price", fnft.userReservePrice(address(this)) / 1e18);
        console.log("user1 balance", fnft.balanceOf(address(user1)) / 1e18);
        console.log("user1 reserve price", fnft.userReservePrice(address(user1)) / 1e18);
        console.log("actual fnft reserve price", fnft.reservePrice() / 1e18);
        console.log("TRANSFER__________________");

        user1.call_transfer((address(user2)), 20 ether);
        console.log("voting tokens", fnft.votingTokens() / 1e18);
        console.log("user2 reserve price", fnft.userReservePrice(address(user2)) / 1e18);
        console.log("user2 balance", fnft.balanceOf(address(user2)) / 1e18);
        console.log("user2 reserve price", fnft.userReservePrice(address(user2)) / 1e18);
        console.log("actual fnft reserve price", fnft.reservePrice() / 1e18);
    }

    function testPause() public {
        fnftFactory.togglePaused();
        fnftFactory.togglePaused();
        MockNFT temp = new MockNFT();

        temp.mint(address(this), 1);

        temp.setApprovalForAll(address(fnftFactory), true);
        fnftFactory.mint("testName2", "TEST2", address(temp), 1, 100e18, 1 ether, 500);
    }

    function testFnftFactoryPausedCannotMint() public {
        fnftFactory.togglePaused();
        MockNFT temp = new MockNFT();

        temp.mint(address(this), 1);

        temp.setApprovalForAll(address(fnftFactory), true);
        vm.expectRevert("Pausable: paused");
        fnftFactory.mint("testName2", "TEST2", address(temp), 1, 100e18, 1 ether, 500);
    }

    /// -------------------------------
    /// -------- GOV FUNCTIONS --------
    /// -------------------------------

    function testToggleVerified() public {
        assertTrue(!fnft.verified());
        fnft.toggleVerified();
        assertTrue(fnft.verified());
        fnft.toggleVerified();
        assertTrue(!fnft.verified());
    }

    event KickCurator(address indexed oldCurator, address indexed newCurator);
    event UpdateCurator(address indexed oldCurator, address indexed newCurator);

    function testKickCurator() public {
        vm.expectEmit(true, true, false, true);
        emit UpdateCurator(fnft.curator(), address(curator));
        fnft.updateCurator(address(curator));
        assertTrue(fnft.curator() == address(curator));
        vm.expectEmit(true, true, false, true);
        emit KickCurator(address(curator), address(this));
        fnft.kickCurator(address(this));
        assertTrue(fnft.curator() == address(this));
    }

    function testKickSameCurator() public {
        fnft.updateCurator(address(curator));
        vm.expectRevert(FNFT.SameCurator.selector);
        fnft.kickCurator(address(curator));
    }

    function testKickCuratorNotGov() public {
        vm.expectRevert(FNFT.NotGov.selector);
        curator.call_kickCurator(address(curator));
    }

    function testChangeReserve() public {
        // reserve price here should not change
        fnft.transfer(address(user1), 50e18);
        assertEq(fnft.reservePrice(), 1 ether);
        assertEq(fnft.votingTokens(), 50e18);

        assertEq(fnft.userReservePrice(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(fnft.reservePrice(), 1.5 ether);

        // lets pretend user1 found an exploit to push up their reserve price
        fnft.removeReserve(address(user1));
        assertEq(fnft.userReservePrice(address(user1)), 0);
        assertEq(fnft.reservePrice(), 1 ether);
        assertEq(fnft.votingTokens(), 50e18);
    }

    function testChangeReserveNotGov() public {
        // reserve price here should not change
        fnft.transfer(address(user1), 50e18);
        assertEq(fnft.reservePrice(), 1 ether);
        assertEq(fnft.votingTokens(), 50e18);

        assertEq(fnft.userReservePrice(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(fnft.reservePrice(), 1.5 ether);

        vm.expectRevert(FNFT.NotGov.selector);
        // user1 is not gov so cannot do anything
        user1.call_remove(address(this));
    }

    function testChangeReserveBelowMinReserveFactor() public {
        assertEq(fnftFactory.minReserveFactor(), 2000);

        //initial reserve is 1,
        //minReserveFactor is 20%

        fnft.transfer(address(user1), 50 ether);

        user1.call_updatePrice(0.2 ether);

        assertEq(fnft.reservePrice(), 0.6 ether);

        fnft.transfer(address(user2), 50 ether);
        // reservePrice is now 0.2 eth because transfering canceled the vote of 1 eth

        vm.expectRevert(FNFT.PriceTooLow.selector);
        // 0.04 is the minimum since 20% of 0.2 is 0.04. Fail
        user1.call_updatePrice(0.039 ether);
    }

    function testChangeReserveAboveMaxReserveFactor() public {
        assertEq(fnftFactory.maxReserveFactor(), 50000);

        //initial reserve is 1,
        //maxReserveFactor is 500%

        fnft.transfer(address(user1), 50 ether);

        user1.call_updatePrice(5 ether);

        assertEq(fnft.reservePrice(), 3 ether);

        fnft.transfer(address(user2), 50 ether);
        // reservePrice is now 5 eth because transfering canceled the vote of 1 eth

        vm.expectRevert(FNFT.PriceTooHigh.selector);
        // 25 is the minimum since 500% of 5 is 25. Fail
        user2.call_updatePrice(26 ether);
    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    function testUpdateCurator() public {
        vm.expectEmit(true, true, false, true);
        emit UpdateCurator(fnft.curator(), address(curator));
        fnft.updateCurator(address(curator));
        assertTrue(fnft.curator() == address(curator));
    }

    function testUpdateSameCurator() public {
        fnft.updateCurator(address(curator));
        vm.prank(address(curator));
        vm.expectRevert(FNFT.SameCurator.selector);
        fnft.updateCurator(address(curator));
    }

    function testUpdateAuctionLength() public {
        fnft.updateAuctionLength(2 weeks);
        assertTrue(fnft.auctionLength() == 2 weeks);
    }

    function testUpdateAuctionLengthTooShort() public {
        vm.expectRevert(FNFT.InvalidAuctionLength.selector);
        fnft.updateAuctionLength(0.1 days);
    }

    function testUpdateAuctionLengthTooLong() public {
        vm.expectRevert(FNFT.InvalidAuctionLength.selector);
        fnft.updateAuctionLength(100 weeks);
    }

    function testUpdateFee() public {
        fnft.updateFee(250);
        assertEq(fnft.fee(), 250);
    }

    function testUpdateFeeCanNotRaise() public {
        vm.expectRevert(FNFT.CanNotRaise.selector);
        fnft.updateFee(1001);
    }

    function testClaimFees() public {
        // curator fee is 5%
        // gov fee is 1%
        // we should increase total supply by 6%
        vm.warp(block.timestamp + 31536000 seconds);
        fnft.claimFees();
        assertTrue(fnft.totalSupply() == 105999999999949936000);
    }

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    function testInitialReserve() public {
        assertEq(fnft.reservePrice(), 1 ether);
        assertEq(fnft.initialReserve(), 1 ether);
    }

    function testAuctionPrice() public {
        fnftFactory.setPriceOracle(address(0));
        console.log("Quorum requirement: ", fnftFactory.minVotePercentage()); // 25%
        console.log("Min reserve factor: ", fnftFactory.minReserveFactor()); // 20%
        console.log("Max reserve factor: ", fnftFactory.maxReserveFactor()); // 500%

        assertEq(fnft.getQuorum(), 10000, "Quorum 1");
        assertEq(fnft.reservePrice(), 1 ether, "Reserve price 1");
        assertEq(fnft.initialReserve(), 1 ether, "Initial reserve 1");
        assertEq(fnft.getAuctionPrice(), 1 ether, "Auction price 1");

        fnft.transfer(address(user1), 25 ether);
        fnft.transfer(address(user2), 50 ether);

        // below quorum since 2500 is not greater than minVotePercentage of 2500
        assertEq(fnft.getQuorum(), 2500, "Quorum 2");
        assertEq(fnft.reservePrice(), 1 ether, "Reserve price 2");
        assertEq(fnft.initialReserve(), 1 ether, "Initial reserve 2");
        assertEq(fnft.getAuctionPrice(), 1 ether, "Auction price 2");

        user1.call_updatePrice(3 ether);
        // now auction price is 2 eth since this address and user1 have same amounts.
        // (1 + 3) / 2 = 2
        assertEq(fnft.getQuorum(), 5000, "Quorum 3");
        assertEq(fnft.reservePrice(), 2 ether, "Reserve price 3");
        assertEq(fnft.initialReserve(), 1 ether, "Initial reserve 3");
        assertEq(fnft.getAuctionPrice(), 2 ether, "Auction price 3");

        user2.call_updatePrice(1 ether);
        // now auction price is 1.5 eth since user2 holds 50%, and previous was 2 eth
        // (2 + 1) / 2 = 1.5
        assertEq(fnft.getQuorum(), 10000, "Quorum 4");
        assertEq(fnft.reservePrice(), 1.5 ether, "Reserve price 4");
        assertEq(fnft.initialReserve(), 1 ether, "Initial reserve 4");
        assertEq(fnft.getAuctionPrice(), 1.5 ether, "Auction price 4");
    }

    function testReservePriceTransfer() public {
        // reserve price here should not change
        fnft.transfer(address(user1), 50e18);
        assertEq(fnft.reservePrice(), 1 ether);
        assertEq(fnft.votingTokens(), 50e18);

        assertEq(fnft.userReservePrice(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(fnft.reservePrice(), 1.5 ether);

        // now user 1 sends 2/5 their tokens to user 2
        // reserve price is now 1 * 5 + 2 * 3 / 8 = 1.375
        user1.call_transfer(address(user2), 20e18);
        assertEq(fnft.reservePrice(), 1.375 ether);

        // now they are voting the same as user1 was so we go back to 1.5 eth
        user2.call_updatePrice(2 ether);
        assertEq(fnft.reservePrice(), 1.5 ether);

        // send all tokens back to first user
        // their reserve price is 1 ether and they hold all tokens
        user1.call_transfer(address(this), 30e18);
        user2.call_transfer(address(this), 20e18);
        assertEq(fnft.reservePrice(), 1 ether);
    }

    function testBid() public {
        fnft.transfer(address(user1), 25e18);
        user1.call_updatePrice(1 ether);
        fnft.transfer(address(user2), 25e18);
        user2.call_updatePrice(1 ether);
        fnft.transfer(address(user3), 50e18);
        user3.call_updatePrice(1 ether);

        user1.call_start(1.05 ether);

        assertTrue(fnft.auctionState() == FNFT.State.Live);

        uint256 bal = address(user1).balance;
        user2.call_bid(1.5 ether);
        assertEq(bal + 1.05 ether, address(user1).balance);

        bal = address(user2).balance;
        user1.call_bid(2 ether);
        assertEq(bal + 1.5 ether, address(user2).balance);

        vm.warp(block.timestamp + 7 days);

        fnft.end();

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

        assertTrue(fnft.auctionState() == FNFT.State.Ended);
    }

    function testRedeem() public {
        fnft.redeem();

        assertTrue(fnft.auctionState() == FNFT.State.Redeemed);

        assertEq(token.balanceOf(address(this)), 1);
    }

    function testGetWeth() public {
        fnft.transfer(address(user1), 25 * 1e18);
        user1.call_updatePrice(1 ether);
        fnft.transfer(address(user2), 25 * 1e18);
        user2.call_updatePrice(1 ether);
        fnft.transfer(address(user4), 50 * 1e18);
        user4.call_updatePrice(1 ether);

        user4.call_start(1.05 ether);
        user4.setCanReceive(false);
        assertTrue(fnft.auctionState() == FNFT.State.Live);
        user2.call_bid(1.5 ether);

        assertTrue(address(user4).balance != 1.05 ether);
        assertTrue(IWETH(address(weth)).balanceOf(address(user4)) == 1.05 ether);
    }

    function testListPriceZero() public {
        token.mint(address(this), 2);

        fnft = FNFT(fnftFactory.mint("testName", "TEST", address(token), 2, 100e18, 0, 500));

        assertEq(fnft.votingTokens(), 0);
    }

    function testFail_listPriceZeroNoAuction() public {
        token.mint(address(this), 2);

        fnft = FNFT(fnftFactory.mint("testName", "TEST", address(token), 2, 100e18, 0, 500));

        User userTemp = new User(address(fnft));

        userTemp.call_start(1.05 ether);
    }

    function testTransfer() public {
        fnft.transfer(address(user1), 25e18);
    }

    function testAuctionEndCurator0() public {
        fnft.updateFee(0);
        fnft.updateCurator(address(0));
        fnftFactory.setFee(FNFTFactory.FeeType.GovernanceFee, 0);
        fnft.transfer(address(user1), 25e18);
        user1.call_updatePrice(1 ether);
        fnft.transfer(address(user2), 25e18);
        user2.call_updatePrice(1 ether);
        fnft.transfer(address(user3), 50e18);
        user3.call_updatePrice(1 ether);

        user1.call_start(1.05 ether);

        assertTrue(fnft.auctionState() == FNFT.State.Live);

        uint256 bal = address(user1).balance;
        user2.call_bid(1.5 ether);
        assertEq(bal + 1.05 ether, address(user1).balance);

        bal = address(user2).balance;
        user1.call_bid(2 ether);
        assertEq(bal + 1.5 ether, address(user2).balance);

        vm.warp(block.timestamp + 7 days);

        fnft.end();

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

        assertTrue(fnft.auctionState() == FNFT.State.Ended);
    }

    function testGetQuorum() public {
        fnft.transfer(address(user1), 25 ether);
        user1.call_updatePrice(1 ether);
        fnft.transfer(address(user2), 25 ether);
        user2.call_updatePrice(1 ether);
        fnft.transfer(address(user4), 50 ether);

        assertEq(fnft.getQuorum(), 5000);

        user4.call_updatePrice(1 ether);

        assertEq(fnft.getQuorum(), 10000);
    }

    function testGetQuorumOnIFOLock() public {
        fnft.approve(address(ifoFactory), fnft.balanceOf(address(this)));
        ifoFactory.create(
            address(fnft), // the address of the fractionalized token
            fnft.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fnft.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );

        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fnft)));
        ifoFactory.setCreatorIFOLock(true);

        fNFTIfo.start();

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 0.1 ether}(); // 10 eth
        vm.stopPrank();

        vm.startPrank(address(user2));
        fNFTIfo.deposit{value: 0.3 ether}(); // 30 eth
        vm.stopPrank();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        //60 eth should be locked up in IFO now. 40 eth should be the circulating supply

        user1.call_updatePrice(1 ether);

        assertEq(fnft.getQuorum(), 2500);

        user2.call_updatePrice(1 ether);

        assertEq(fnft.getQuorum(), 10000);

        ifoFactory.setCreatorIFOLock(false);

        assertEq(fnft.getQuorum(), 4000);
    }

    function testSetVaultMetadata() public {
        assertEq(fnft.name(), "testName");
        assertEq(fnft.symbol(), "TEST");
        vm.prank(fnft.curator());
        fnft.setVaultMetadata("Bored Ape", "BAYC");
        assertEq(fnft.name(), "Bored Ape");
        assertEq(fnft.symbol(), "BAYC");
    }

    function testSetVaultMetadataNotCurator() public {
        vm.expectRevert(FNFT.NotCurator.selector);
        vm.prank(address(user1));
        fnft.setVaultMetadata("Bored Ape", "BAYC");
    }


    // TODO: include fees
    function testFlashLoanGood() public {
        FlashBorrower flashBorrower = new FlashBorrower(address(fnft));

        assertEq(fnft.totalSupply(), 100 ether);
        assertEq(fnft.balanceOf(address(fnft)), 0);

        flashBorrower.goodFlashLoan(1 ether);

        assertEq(fnft.totalSupply(), 100 ether);
        assertEq(fnft.balanceOf(address(fnft)), 0);
        assertEq(fnft.balanceOf(address(flashBorrower)), 0);
        assertEq(fnft.allowance(address(flashBorrower), address(fnft)), 0);
    }

    // TODO: implement
    // function testFlashLoanGoodFeeExcluded() public {
    // }

    // TODO: include fees
    function testFlashLoanBad() public {
        FlashBorrower flashBorrower = new FlashBorrower(address(fnft));

        assertEq(fnft.totalSupply(), 100 ether);
        assertEq(fnft.balanceOf(address(fnft)), 0);

        vm.expectRevert(ERC20FlashMintUpgradeable.FlashLoanNotRepaid.selector);
        flashBorrower.badFlashLoan(1 ether);

        assertEq(fnft.totalSupply(), 100 ether);
        assertEq(fnft.balanceOf(address(flashBorrower)), 0);
        assertEq(fnft.balanceOf(address(fnft)), 0);
        assertEq(fnft.allowance(address(flashBorrower), address(fnft)), 0);
    }

    receive() external payable {}
}
