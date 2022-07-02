//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Deployer} from "../contracts/proxy/Deployer.sol";
import {MultiProxyController} from "../contracts/proxy/MultiProxyController.sol";
import {IFOFactory} from "../contracts/IFOFactory.sol";
import {IFO} from "../contracts/IFO.sol";
import {FNFTSingleFactory, IFNFTSingleFactory} from "../contracts/FNFTSingleFactory.sol";
import {VaultManager} from "../contracts/VaultManager.sol";
import {PriceOracle, IPriceOracle} from "../contracts/PriceOracle.sol";
import {FNFTSingle} from "../contracts/FNFTSingle.sol";
import {IUniswapV2Factory} from "../contracts/interfaces/IUniswapV2Factory.sol";
import {IWETH} from "../contracts/interfaces/IWETH.sol";
import {IFNFTSingle} from "../contracts/interfaces/IFNFTSingle.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {console, CheatCodes, SetupEnvironment, User, Curator, UserNoETH} from "./utils/utils.sol";
import {ERC20FlashMintUpgradeable} from "../contracts/token/ERC20FlashMintUpgradeable.sol";
import {Pausable} from "../contracts/util/Pausable.sol";
import {FlashBorrower} from "./utils/FlashBorrower.sol";

/// @author Nibble Market
/// @title Tests for the vaults
contract FNFTSingleTest is DSTest, ERC721Holder, SetupEnvironment {
    IFOFactory public ifoFactory;
    IPriceOracle public priceOracle;
    IUniswapV2Factory public pairFactory;
    FNFTSingleFactory public fnftSingleFactory;
    VaultManager public vaultManager;
    MockNFT public token;
    FNFTSingle public fnftSingle;

    User public user1;
    User public user2;
    User public user3;
    UserNoETH public user4;

    Curator public curator;

    function setUp() public {
        setupEnvironment(10 ether);
        (   ,
            ,
            ifoFactory,
            pairFactory,
            priceOracle,
            ,
            vaultManager,
            fnftSingleFactory,
            ,
        ) = setupContracts();
        //set governance fee to 100
        fnftSingleFactory.setFactoryFees(100, 1000, 0, 0);
        fnftSingleFactory.setIsGuardian(address(this), true);
        token = new MockNFT();
        token.mint(address(this), 1);
        token.setApprovalForAll(address(fnftSingleFactory), true);
        // FNFTSingle minted on this test contract address.
        fnftSingle = FNFTSingle(fnftSingleFactory.createVault(
            "testName",
            "TEST",
            address(token),
            1,
            100 ether, // supply
            1 ether, // initialReserve
            500 // fee (5%)
        ));
        // create a curator account
        curator = new Curator(address(fnftSingle));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fnftSingle));
        user2 = new User(address(fnftSingle));
        user3 = new User(address(fnftSingle));
        user4 = new UserNoETH(address(fnftSingle));

        payable(address(user1)).transfer(10 ether);
        payable(address(user2)).transfer(10 ether);
        payable(address(user3)).transfer(10 ether);
        payable(address(user4)).transfer(10 ether);
    }

    function testInitializeFeeTooHigh() public {
        uint256 maxCuratorFee = fnftSingleFactory.maxCuratorFee();
        token.mint(address(this), 2);
        vm.expectRevert(IFNFTSingle.FeeTooHigh.selector);
        fnftSingle = FNFTSingle(fnftSingleFactory.createVault(
            "TheFeeIsTooDamnHigh",
            "HIGH",
            address(token),
            2,
            100 ether, // supply
            1 ether, // list price
            maxCuratorFee + 1
        ));
    }

    function testInitializeZeroAddress() public {
        uint256 maxCuratorFee = fnftSingleFactory.maxCuratorFee();
        token.mint(address(this), 2);
        vm.expectRevert(IFNFTSingle.ZeroAddress.selector);
        fnftSingle = FNFTSingle(fnftSingleFactory.createVault(
            "Doodles",
            "DOODLES",
            address(0),
            2,
            100 ether, // supply
            1 ether, // list price
            maxCuratorFee
        ));
    }

    function testTransferBetweenUsers() public {
        console.log("this balance", fnftSingle.balanceOf(address(this)) / 1e18);
        console.log("this reserve price", fnftSingle.userReservePrice(address(this)) / 1e18);
        console.log("user1 reserve price", fnftSingle.userReservePrice(address(user1)) / 1e18);
        console.log("voting tokens", fnftSingle.votingTokens() / 1e18);
        console.log("actual fnftSingle reserve price", fnftSingle.reservePrice() / 1e18);
        console.log("TRANSFER__________________");

        fnftSingle.transfer(address(user1), 100 ether);
        console.log("voting tokens", fnftSingle.votingTokens() / 1e18);
        console.log("this reserve price", fnftSingle.userReservePrice(address(this)) / 1e18);
        console.log("user1 balance", fnftSingle.balanceOf(address(user1)) / 1e18);
        console.log("user1 reserve price", fnftSingle.userReservePrice(address(user1)) / 1e18);
        console.log("actual fnftSingle reserve price", fnftSingle.reservePrice() / 1e18);
        console.log("TRANSFER__________________");

        user1.call_transfer((address(user2)), 20 ether);
        console.log("voting tokens", fnftSingle.votingTokens() / 1e18);
        console.log("user2 reserve price", fnftSingle.userReservePrice(address(user2)) / 1e18);
        console.log("user2 balance", fnftSingle.balanceOf(address(user2)) / 1e18);
        console.log("user2 reserve price", fnftSingle.userReservePrice(address(user2)) / 1e18);
        console.log("actual fnftSingle reserve price", fnftSingle.reservePrice() / 1e18);
    }

    function testPause() public {
        fnftSingleFactory.pause(0);
        MockNFT temp = new MockNFT();

        temp.mint(address(this), 1);

        temp.setApprovalForAll(address(fnftSingleFactory), true);
        fnftSingleFactory.createVault("testName2", "TEST2", address(temp), 1, 100e18, 1 ether, 500);
    }

    function testFNFTSingleFactoryPausedCannotMint() public {
        fnftSingleFactory.pause(0);

        vm.startPrank(address(user1));
        MockNFT temp = new MockNFT();

        temp.mint(address(this), 1);

        temp.setApprovalForAll(address(fnftSingleFactory), true);
        vm.expectRevert(Pausable.Paused.selector);
        fnftSingleFactory.createVault("testName2", "TEST2", address(temp), 1, 100e18, 1 ether, 500);
        vm.stopPrank();
    }

    /// -------------------------------
    /// -------- GOV FUNCTIONS --------
    /// -------------------------------

    function testToggleVerified() public {
        assertTrue(!fnftSingle.verified());
        fnftSingle.toggleVerified();
        assertTrue(fnftSingle.verified());
        fnftSingle.toggleVerified();
        assertTrue(!fnftSingle.verified());
    }

    event CuratorKicked(address indexed oldCurator, address indexed newCurator);
    event CuratorUpdated(address indexed oldCurator, address indexed newCurator);

    function testKickCurator() public {
        vm.expectEmit(true, true, false, true);
        emit CuratorUpdated(fnftSingle.curator(), address(curator));
        fnftSingle.updateCurator(address(curator));
        assertTrue(fnftSingle.curator() == address(curator));
        vm.expectEmit(true, true, false, true);
        emit CuratorKicked(address(curator), address(this));
        fnftSingle.kickCurator(address(this));
        assertTrue(fnftSingle.curator() == address(this));
    }

    function testKickSameCurator() public {
        fnftSingle.updateCurator(address(curator));
        vm.expectRevert(IFNFTSingle.SameCurator.selector);
        fnftSingle.kickCurator(address(curator));
    }

    function testKickCuratorNotGov() public {
        vm.expectRevert(IFNFTSingle.NotGov.selector);
        curator.call_kickCurator(address(curator));
    }

    function testChangeReserve() public {
        // reserve price here should not change
        fnftSingle.transfer(address(user1), 50e18);
        assertEq(fnftSingle.reservePrice(), 1 ether);
        assertEq(fnftSingle.votingTokens(), 50e18);

        assertEq(fnftSingle.userReservePrice(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(fnftSingle.reservePrice(), 1.5 ether);

        // lets pretend user1 found an exploit to push up their reserve price
        fnftSingle.removeReserve(address(user1));
        assertEq(fnftSingle.userReservePrice(address(user1)), 0);
        assertEq(fnftSingle.reservePrice(), 1 ether);
        assertEq(fnftSingle.votingTokens(), 50e18);
    }

    function testChangeReserveNotGov() public {
        // reserve price here should not change
        fnftSingle.transfer(address(user1), 50e18);
        assertEq(fnftSingle.reservePrice(), 1 ether);
        assertEq(fnftSingle.votingTokens(), 50e18);

        assertEq(fnftSingle.userReservePrice(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(fnftSingle.reservePrice(), 1.5 ether);

        vm.expectRevert(IFNFTSingle.NotGov.selector);
        // user1 is not gov so cannot do anything
        user1.call_remove(address(this));
    }

    function testChangeReserveBelowMinReserveFactor() public {
        assertEq(fnftSingleFactory.minReserveFactor(), 2000);

        //initial reserve is 1,
        //minReserveFactor is 20%

        fnftSingle.transfer(address(user1), 50 ether);

        user1.call_updatePrice(0.2 ether);

        assertEq(fnftSingle.reservePrice(), 0.6 ether);

        fnftSingle.transfer(address(user2), 50 ether);
        // reservePrice is now 0.2 eth because transfering canceled the vote of 1 eth

        vm.expectRevert(IFNFTSingle.PriceTooLow.selector);
        // 0.04 is the minimum since 20% of 0.2 is 0.04. Fail
        user1.call_updatePrice(0.039 ether);
    }

    function testChangeReserveAboveMaxReserveFactor() public {
        assertEq(fnftSingleFactory.maxReserveFactor(), 50000);

        //initial reserve is 1,
        //maxReserveFactor is 500%

        fnftSingle.transfer(address(user1), 50 ether);

        user1.call_updatePrice(5 ether);

        assertEq(fnftSingle.reservePrice(), 3 ether);

        fnftSingle.transfer(address(user2), 50 ether);
        // reservePrice is now 5 eth because transfering canceled the vote of 1 eth

        vm.expectRevert(IFNFTSingle.PriceTooHigh.selector);
        // 25 is the minimum since 500% of 5 is 25. Fail
        user2.call_updatePrice(26 ether);
    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    function testUpdateCurator() public {
        vm.expectEmit(true, true, false, true);
        emit CuratorUpdated(fnftSingle.curator(), address(curator));
        fnftSingle.updateCurator(address(curator));
        assertTrue(fnftSingle.curator() == address(curator));
    }

    function testUpdateSameCurator() public {
        fnftSingle.updateCurator(address(curator));
        vm.prank(address(curator));
        vm.expectRevert(IFNFTSingle.SameCurator.selector);
        fnftSingle.updateCurator(address(curator));
    }

    function testUpdateAuctionLength() public {
        fnftSingle.updateAuctionLength(2 weeks);
        assertTrue(fnftSingle.auctionLength() == 2 weeks);
    }

    function testUpdateAuctionLengthTooShort() public {
        vm.expectRevert(IFNFTSingle.InvalidAuctionLength.selector);
        fnftSingle.updateAuctionLength(0.1 days);
    }

    function testUpdateAuctionLengthTooLong() public {
        vm.expectRevert(IFNFTSingle.InvalidAuctionLength.selector);
        fnftSingle.updateAuctionLength(100 weeks);
    }

    function testUpdateFee() public {
        fnftSingle.updateFee(250);
        assertEq(fnftSingle.curatorFee(), 250);
    }

    function testUpdateFeeCanNotRaise() public {
        vm.expectRevert(IFNFTSingle.CanNotRaise.selector);
        fnftSingle.updateFee(1001);
    }

    function testClaimFees() public {
        // curator fee is 5%
        // gov fee is 1%
        // we should increase total supply by 6%
        vm.warp(block.timestamp + 31536000 seconds);
        fnftSingle.claimCuratorFees();
        assertTrue(fnftSingle.totalSupply() == 105999999999949936000);
    }

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    function testInitialReserve() public {
        assertEq(fnftSingle.reservePrice(), 1 ether);
        assertEq(fnftSingle.initialReserve(), 1 ether);
    }

    function testAuctionPrice() public {
        vaultManager.setPriceOracle(address(0));
        console.log("Quorum requirement: ", fnftSingleFactory.minVotePercentage()); // 25%
        console.log("Min reserve factor: ", fnftSingleFactory.minReserveFactor()); // 20%
        console.log("Max reserve factor: ", fnftSingleFactory.maxReserveFactor()); // 500%

        assertEq(fnftSingle.getQuorum(), 10000, "Quorum 1");
        assertEq(fnftSingle.reservePrice(), 1 ether, "Reserve price 1");
        assertEq(fnftSingle.initialReserve(), 1 ether, "Initial reserve 1");
        assertEq(fnftSingle.getAuctionPrice(), 1 ether, "Auction price 1");

        fnftSingle.transfer(address(user1), 25 ether);
        fnftSingle.transfer(address(user2), 50 ether);

        // below quorum since 2500 is not greater than minVotePercentage of 2500
        assertEq(fnftSingle.getQuorum(), 2500, "Quorum 2");
        assertEq(fnftSingle.reservePrice(), 1 ether, "Reserve price 2");
        assertEq(fnftSingle.initialReserve(), 1 ether, "Initial reserve 2");
        assertEq(fnftSingle.getAuctionPrice(), 1 ether, "Auction price 2");

        user1.call_updatePrice(3 ether);
        // now auction price is 2 eth since this address and user1 have same amounts.
        // (1 + 3) / 2 = 2
        assertEq(fnftSingle.getQuorum(), 5000, "Quorum 3");
        assertEq(fnftSingle.reservePrice(), 2 ether, "Reserve price 3");
        assertEq(fnftSingle.initialReserve(), 1 ether, "Initial reserve 3");
        assertEq(fnftSingle.getAuctionPrice(), 2 ether, "Auction price 3");

        user2.call_updatePrice(1 ether);
        // now auction price is 1.5 eth since user2 holds 50%, and previous was 2 eth
        // (2 + 1) / 2 = 1.5
        assertEq(fnftSingle.getQuorum(), 10000, "Quorum 4");
        assertEq(fnftSingle.reservePrice(), 1.5 ether, "Reserve price 4");
        assertEq(fnftSingle.initialReserve(), 1 ether, "Initial reserve 4");
        assertEq(fnftSingle.getAuctionPrice(), 1.5 ether, "Auction price 4");
    }

    function testReservePriceTransfer() public {
        // reserve price here should not change
        fnftSingle.transfer(address(user1), 50e18);
        assertEq(fnftSingle.reservePrice(), 1 ether);
        assertEq(fnftSingle.votingTokens(), 50e18);

        assertEq(fnftSingle.userReservePrice(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(fnftSingle.reservePrice(), 1.5 ether);

        // now user 1 sends 2/5 their tokens to user 2
        // reserve price is now 1 * 5 + 2 * 3 / 8 = 1.375
        user1.call_transfer(address(user2), 20e18);
        assertEq(fnftSingle.reservePrice(), 1.375 ether);

        // now they are voting the same as user1 was so we go back to 1.5 eth
        user2.call_updatePrice(2 ether);
        assertEq(fnftSingle.reservePrice(), 1.5 ether);

        // send all tokens back to first user
        // their reserve price is 1 ether and they hold all tokens
        user1.call_transfer(address(this), 30e18);
        user2.call_transfer(address(this), 20e18);
        assertEq(fnftSingle.reservePrice(), 1 ether);
    }

    function testBid() public {
        fnftSingle.transfer(address(user1), 25e18);
        user1.call_updatePrice(1 ether);
        fnftSingle.transfer(address(user2), 25e18);
        user2.call_updatePrice(1 ether);
        fnftSingle.transfer(address(user3), 50e18);
        user3.call_updatePrice(1 ether);

        user1.call_start(1.05 ether);

        assertTrue(fnftSingle.auctionState() == IFNFTSingle.State.Live);

        uint256 bal = address(user1).balance;
        user2.call_bid(1.5 ether);
        assertEq(bal + 1.05 ether, address(user1).balance);

        bal = address(user2).balance;
        user1.call_bid(2 ether);
        assertEq(bal + 1.5 ether, address(user2).balance);

        vm.warp(block.timestamp + 7 days);

        fnftSingle.end();

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

        assertTrue(fnftSingle.auctionState() == IFNFTSingle.State.Ended);
    }

    function testRedeem() public {
        fnftSingle.redeem();

        assertTrue(fnftSingle.auctionState() == IFNFTSingle.State.Redeemed);

        assertEq(token.balanceOf(address(this)), 1);
    }

    function testGetWeth() public {
        fnftSingle.transfer(address(user1), 25 * 1e18);
        user1.call_updatePrice(1 ether);
        fnftSingle.transfer(address(user2), 25 * 1e18);
        user2.call_updatePrice(1 ether);
        fnftSingle.transfer(address(user4), 50 * 1e18);
        user4.call_updatePrice(1 ether);

        user4.call_start(1.05 ether);
        user4.setCanReceive(false);
        assertTrue(fnftSingle.auctionState() == IFNFTSingle.State.Live);
        user2.call_bid(1.5 ether);

        assertTrue(address(user4).balance != 1.05 ether);
        assertTrue(IWETH(address(weth)).balanceOf(address(user4)) == 1.05 ether);
    }

    function testListPriceZero() public {
        token.mint(address(this), 2);

        fnftSingle = FNFTSingle(fnftSingleFactory.createVault("testName", "TEST", address(token), 2, 100e18, 0, 500));

        assertEq(fnftSingle.votingTokens(), 0);
    }

    function testFailListPriceZeroNoAuction() public {
        token.mint(address(this), 2);

        fnftSingle = FNFTSingle(fnftSingleFactory.createVault("testName", "TEST", address(token), 2, 100e18, 0, 500));

        User userTemp = new User(address(fnftSingle));

        userTemp.call_start(1.05 ether);
    }

    function testTransfer() public {
        fnftSingle.transfer(address(user1), 25e18);
    }

    function testAuctionEndCurator0() public {
        fnftSingle.updateFee(0);
        fnftSingle.updateCurator(address(0));
        //set governance fee to 0
        fnftSingleFactory.setFactoryFees(0, 1000, 0, 0);
        fnftSingle.transfer(address(user1), 25e18);
        user1.call_updatePrice(1 ether);
        fnftSingle.transfer(address(user2), 25e18);
        user2.call_updatePrice(1 ether);
        fnftSingle.transfer(address(user3), 50e18);
        user3.call_updatePrice(1 ether);

        user1.call_start(1.05 ether);

        assertTrue(fnftSingle.auctionState() == IFNFTSingle.State.Live);

        uint256 bal = address(user1).balance;
        user2.call_bid(1.5 ether);
        assertEq(bal + 1.05 ether, address(user1).balance);

        bal = address(user2).balance;
        user1.call_bid(2 ether);
        assertEq(bal + 1.5 ether, address(user2).balance);

        vm.warp(block.timestamp + 7 days);

        fnftSingle.end();

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

        assertTrue(fnftSingle.auctionState() == IFNFTSingle.State.Ended);
    }

    function testGetQuorum() public {
        fnftSingle.transfer(address(user1), 25 ether);
        user1.call_updatePrice(1 ether);
        fnftSingle.transfer(address(user2), 25 ether);
        user2.call_updatePrice(1 ether);
        fnftSingle.transfer(address(user4), 50 ether);

        assertEq(fnftSingle.getQuorum(), 5000);

        user4.call_updatePrice(1 ether);

        assertEq(fnftSingle.getQuorum(), 10000);
    }

    function testGetQuorumOnIFOLock() public {
        fnftSingle.approve(address(ifoFactory), fnftSingle.balanceOf(address(this)));
        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            fnftSingle.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fnftSingle.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );

        IFO ifo = IFO(ifoFactory.ifos(address(fnftSingle)));
        ifoFactory.setCreatorIFOLock(true);

        ifo.start();

        vm.startPrank(address(user1));
        ifo.deposit{value: 0.1 ether}(); // 10 eth
        vm.stopPrank();

        vm.startPrank(address(user2));
        ifo.deposit{value: 0.3 ether}(); // 30 eth
        vm.stopPrank();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        //60 eth should be locked up in IFO now. 40 eth should be the circulating supply

        user1.call_updatePrice(1 ether);

        assertEq(fnftSingle.getQuorum(), 2500);

        user2.call_updatePrice(1 ether);

        assertEq(fnftSingle.getQuorum(), 10000);

        ifoFactory.setCreatorIFOLock(false);

        assertEq(fnftSingle.getQuorum(), 4000);
    }

    function testSetVaultMetadata() public {
        assertEq(fnftSingle.name(), "testName");
        assertEq(fnftSingle.symbol(), "TEST");
        vm.prank(fnftSingle.curator());
        fnftSingle.setVaultMetadata("Bored Ape", "BAYC");
        assertEq(fnftSingle.name(), "Bored Ape");
        assertEq(fnftSingle.symbol(), "BAYC");
    }

    function testSetVaultMetadataNotCurator() public {
        vm.expectRevert(IFNFTSingle.NotCurator.selector);
        vm.prank(address(user1));
        fnftSingle.setVaultMetadata("Bored Ape", "BAYC");
    }


    // TODO: include fees
    function testFlashLoanGood() public {
        FlashBorrower flashBorrower = new FlashBorrower(address(fnftSingle));

        assertEq(fnftSingle.totalSupply(), 100 ether);
        assertEq(fnftSingle.balanceOf(address(fnftSingle)), 0);

        flashBorrower.goodFlashLoan(1 ether);

        assertEq(fnftSingle.totalSupply(), 100 ether);
        assertEq(fnftSingle.balanceOf(address(fnftSingle)), 0);
        assertEq(fnftSingle.balanceOf(address(flashBorrower)), 0);
        assertEq(fnftSingle.allowance(address(flashBorrower), address(fnftSingle)), 0);
    }

    // TODO: implement
    // function testFlashLoanGoodFeeExcluded() public {
    // }

    // TODO: include fees
    function testFlashLoanBad() public {
        FlashBorrower flashBorrower = new FlashBorrower(address(fnftSingle));

        assertEq(fnftSingle.totalSupply(), 100 ether);
        assertEq(fnftSingle.balanceOf(address(fnftSingle)), 0);

        vm.expectRevert(ERC20FlashMintUpgradeable.FlashLoanNotRepaid.selector);
        flashBorrower.badFlashLoan(1 ether);

        assertEq(fnftSingle.totalSupply(), 100 ether);
        assertEq(fnftSingle.balanceOf(address(flashBorrower)), 0);
        assertEq(fnftSingle.balanceOf(address(fnftSingle)), 0);
        assertEq(fnftSingle.allowance(address(flashBorrower), address(fnftSingle)), 0);
    }

    function testSwapFee() public {
        //set swap fee to 100
        fnftSingleFactory.setFactoryFees(100, 1000, 0, 100);

        uint originalBalance = fnftSingle.balanceOf(address(this));
        uint transferAmount = 1 ether;
        uint swapFeeAmount = 0.01 ether;
        address distributor = vaultManager.feeDistributor();
        address pairAddress = address(fnftSingle.pair());

        fnftSingle.transfer(pairAddress, transferAmount);

        assertEq(fnftSingle.balanceOf(pairAddress), transferAmount - swapFeeAmount);
        assertEq(fnftSingle.balanceOf(address(this)), originalBalance - transferAmount);
        assertEq(fnftSingle.balanceOf(distributor), swapFeeAmount);
    }

    function testExcludeSwapFeeFromFeeExclusion() public {
        //set swap fee to 100
        fnftSingleFactory.setFactoryFees(100, 1000, 0, 100);
        vaultManager.setFeeExclusion(address(this), true);
        assertTrue(vaultManager.excludedFromFees(address(this)));

        uint originalBalance = fnftSingle.balanceOf(address(this));
        uint transferAmount = 1 ether;
        address distributor = vaultManager.feeDistributor();
        address pairAddress = address(fnftSingle.pair());

        fnftSingle.transfer(pairAddress, transferAmount);

        assertEq(fnftSingle.balanceOf(pairAddress), transferAmount);
        assertEq(fnftSingle.balanceOf(address(this)), originalBalance - transferAmount);
        assertEq(fnftSingle.balanceOf(distributor), 0);
    }

    function testExcludeSwapFeeForNormalTransfers() public {
        //set swap fee to 100
        fnftSingleFactory.setFactoryFees(100, 1000, 0, 100);

        uint originalBalance = fnftSingle.balanceOf(address(this));
        uint transferAmount = 1 ether;
        address distributor = vaultManager.feeDistributor();

        fnftSingle.transfer(address(user1), transferAmount);

        assertEq(fnftSingle.balanceOf(address(user1)), transferAmount);
        assertEq(fnftSingle.balanceOf(address(this)), originalBalance - transferAmount);
        assertEq(fnftSingle.balanceOf(distributor), 0);
    }


    receive() external payable {}
}
