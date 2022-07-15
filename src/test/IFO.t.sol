//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IFOFactory} from "../contracts/IFOFactory.sol";
import {PriceOracle, IPriceOracle} from "../contracts/PriceOracle.sol";
import {FNFTSingleFactory, IFNFTSingleFactory} from "../contracts/FNFTSingleFactory.sol";
import {FNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
import {FNFTSingle, IFNFTSingle} from "../contracts/FNFTSingle.sol";
import {FNFTCollection} from "../contracts/FNFTCollection.sol";
import {IFO, IIFO} from "../contracts/IFO.sol";
import {SimpleMockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {console, CheatCodes, SetupEnvironment, User, Curator, UserNoETH} from "./utils/utils.sol";
import {BeaconProxy} from "../contracts/proxy/BeaconProxy.sol";

/// @author Nibble Market
/// @title Tests for the fnfts
contract IFOTest is DSTest, ERC721Holder, SetupEnvironment {
    FNFTSingleFactory public fnftSingleFactory;
    FNFTCollectionFactory public fnftCollectionFactory;
    IFOFactory public ifoFactory;
    IPriceOracle public priceOracle;
    SimpleMockNFT public nft;
    FNFTSingle public fnftSingle;
    FNFTCollection public fnftCollection;

    User public user1;
    User public user2;
    User public user3;

    Curator public curator;

    function setUp() public {
        setupEnvironment(10 ether);
        (   ,
            ,
            ifoFactory,
            ,
            priceOracle,
            ,
            ,
            fnftSingleFactory,
            fnftCollectionFactory,
        ) = setupContracts();

        //set governance fee to 0
        fnftSingleFactory.setFactoryFees(0, 1000, 0);

        nft = new SimpleMockNFT();

        nft.mint(address(this), 1);

        nft.setApprovalForAll(address(fnftSingleFactory), true);
        fnftSingle = FNFTSingle(
            fnftSingleFactory.createVault(
                address(nft),
                1, // tokenId
                1000e18, //supply: minted to the fractionalizer
                10 ether, // listPrice: the initial reserve price
                0, // the % * 10 fee minted to the fractionalizer anually
                "testName",
                "TEST"
            )
        );
        fnftCollection = setupFNFTCollection(address(fnftCollectionFactory), 5);
        // create a curator account
        curator = new Curator(address(fnftSingle));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fnftSingle));
        user2 = new User(address(fnftSingle));
        user3 = new User(address(fnftSingle));

        payable(address(user1)).transfer(20 ether);
        payable(address(user2)).transfer(20 ether);
        payable(address(user3)).transfer(20 ether);
    }

    /// -------------------------------
    /// -------- INIT FUNCTIONS -------
    /// -------------------------------
    function createValidIFO() private returns(IFO ifo) {
        uint balance = fnftSingle.balanceOf(address(this));
        fnftSingle.approve(address(ifoFactory), balance);
        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            balance, // amountForSale
            0.01 ether, //price per token
            fnftSingle.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );
        ifo = IFO(ifoFactory.ifos(address(fnftSingle)));
    }

    function createValidFNFTCollectionIFO() private returns(IFO ifo) {
        uint balance = fnftCollection.balanceOf(address(this));
        fnftCollection.approve(address(ifoFactory), balance);
        ifoFactory.create(
            address(fnftCollection), // the address of the fractionalized token
            balance, // amountForSale
            0.01 ether, //price per token
            fnftCollection.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );
        ifo = IFO(ifoFactory.ifos(address(fnftCollection)));
    }

    function createValidAllowWhitelistIFO() private returns(IFO ifo) {
        uint balance = fnftSingle.balanceOf(address(this));
        fnftSingle.approve(address(ifoFactory), balance);
        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            balance, // amountForSale
            0.01 ether, //price per token
            fnftSingle.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            true // allow whitelist
        );
        ifo = IFO(ifoFactory.ifos(address(fnftSingle)));
    }

    function createValidIFOWith3EthCap() private returns(IFO ifo) {
        uint256 balance = fnftSingle.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fnftSingle.approve(address(ifoFactory), balance);
        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            balance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );
        ifo = IFO(ifoFactory.ifos(address(fnftSingle)));
    }

    function testPause() public {
        ifoFactory.pause();
        ifoFactory.unpause();
    }

    function testCreateIFO() public {
        IFO ifo = createValidIFO();

        assertEq(fnftSingle.balanceOf(address(ifo)), fnftSingle.totalSupply());
        assertEq(ifo.duration(), ifoFactory.minimumDuration());
    }

    function testCreateFNFTCollectionIFO() public {
        IFO ifo = createValidFNFTCollectionIFO();

        assertEq(
            fnftCollection.balanceOf(address(ifo)),
            4500000000000000000
        );
        assertEq(ifo.duration(), 86400);
    }

    function testCreateIFOZeroAddress() public {
        uint256 balance = fnftSingle.balanceOf(address(this));
        uint256 totalSupply = fnftSingle.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fnftSingle.approve(address(ifoFactory), balance);
        vm.expectRevert(IIFO.ZeroAddress.selector);
        ifoFactory.create(
            address(0), // wrong address
            balance, //amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFONotEnoughSupply() public {
        uint256 balance = fnftSingle.balanceOf(address(this));
        uint256 totalSupply = fnftSingle.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fnftSingle.approve(address(ifoFactory), balance);
        // burn 1
        fnftSingle.transfer(0x000000000000000000000000000000000000dEaD, 1);
        vm.expectRevert(IIFO.NotEnoughSupply.selector);
        ifoFactory.create(
            address(fnftSingle),
            balance, //amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOMarketCapTooHigh() public {
        uint256 balance = fnftSingle.balanceOf(address(this));
        uint256 totalSupply = fnftSingle.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fnftSingle.approve(address(ifoFactory), balance);
        vm.expectRevert(IIFO.InvalidCap.selector);
        ifoFactory.create(
            address(fnftSingle),
            balance, //amountForSale
            0.01 ether, //price per token
            totalSupply + 1, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOMarketCapTooLow() public {
        uint256 balance = fnftSingle.balanceOf(address(this));
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fnftSingle.approve(address(ifoFactory), balance);
        vm.expectRevert(IIFO.InvalidCap.selector);
        ifoFactory.create(
            address(fnftSingle),
            balance, //amountForSale
            0.01 ether, //price per token
            0, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOAmountForSaleTooLow() public {
        uint256 totalSupply = fnftSingle.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fnftSingle.approve(address(ifoFactory), fnftSingle.balanceOf(address(this)));
        vm.expectRevert(IIFO.InvalidAmountForSale.selector);
        ifoFactory.create(
            address(fnftSingle),
            0, // amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOAmountForSaleTooHigh() public {
        uint256 balance = fnftSingle.balanceOf(address(this));
        uint256 totalSupply = fnftSingle.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fnftSingle.approve(address(ifoFactory), balance);
        vm.expectRevert(IIFO.InvalidAmountForSale.selector);
        ifoFactory.create(
            address(fnftSingle),
            balance + 1, //amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOMarketCapHigherThanInitialReserve() public {
        uint256 balance = fnftSingle.balanceOf(address(this));
        uint256 totalSupply = fnftSingle.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fnftSingle.approve(address(ifoFactory), balance);
        vm.expectRevert(IIFO.InvalidReservePrice.selector);
        ifoFactory.create(
            address(fnftSingle),
            balance, //amountForSale
            0.02 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFODurationTooLow() public {
        uint256 balance = fnftSingle.balanceOf(address(this));
        uint256 totalSupply = fnftSingle.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fnftSingle.approve(address(ifoFactory), balance);
        vm.expectRevert(IIFO.InvalidDuration.selector);
        ifoFactory.create(
            address(fnftSingle),
            balance, //amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration - 1, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFODurationTooHigh() public {
        uint256 balance = fnftSingle.balanceOf(address(this));
        uint256 totalSupply = fnftSingle.totalSupply();
        uint256 maximumDuration = ifoFactory.maximumDuration();
        fnftSingle.approve(address(ifoFactory), balance);
        vm.expectRevert(IIFO.InvalidDuration.selector);
        ifoFactory.create(
            address(fnftSingle),
            balance, //amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            maximumDuration + 1, //sale duration
            false // allow whitelist
        );
    }

    function testCannotCreateWhenPaused() public {
        ifoFactory.pause();
        uint256 thisBalance = fnftSingle.balanceOf(address(this));
        vm.expectRevert(bytes("Pausable: paused"));
        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            thisBalance, //amountForSale
            0.01 ether, //price per token
            1e18, // max amount someone can buy
            30 days, //sale duration
            false // allow whitelist
        );
    }

    /// -------------------------------
    /// -------- GOV FUNCTIONS --------
    /// -------------------------------

    function testUpdateFNFTAddress() public {
        fnftSingle.approve(address(this), fnftSingle.balanceOf(address(this)));
        fnftSingle.transferFrom(address(this), address(user1), fnftSingle.balanceOf(address(this)));

        vm.startPrank(address(user1));

        fnftSingle.approve(address(ifoFactory), fnftSingle.balanceOf(address(user1)));

        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            fnftSingle.balanceOf(address(user1)), //amountForSale
            0.01 ether, //price per token
            fnftSingle.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO ifo = IFO(ifoFactory.ifos(address(fnftSingle)));

        vm.stopPrank();

        ifo.updateFNFTAddress(address(user2));

        assertEq(address(ifo.fnft()), address(user2));
    }

    function testUpdateFNFTAddressZeroAddress() public {
        IFO ifo = createValidIFO();

        vm.expectRevert(IIFO.ZeroAddress.selector);
        ifo.updateFNFTAddress(address(0));
    }

    function testUpdateFNFTAddressNotGov() public {
        fnftSingle.approve(address(this), fnftSingle.balanceOf(address(this)));
        fnftSingle.transferFrom(address(this), address(user1), fnftSingle.balanceOf(address(this)));

        vm.startPrank(address(user1));

        fnftSingle.approve(address(ifoFactory), fnftSingle.balanceOf(address(user1)));

        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            fnftSingle.balanceOf(address(user1)), //amountForSale
            0.01 ether, //price per token
            fnftSingle.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO ifo = IFO(ifoFactory.ifos(address(fnftSingle)));

        vm.expectRevert(IIFO.NotGov.selector);
        ifo.updateFNFTAddress(address(user1));

        vm.stopPrank();
    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    function testAddWhitelist() public {
        IFO ifo = createValidAllowWhitelistIFO();

        ifo.addWhitelist(address(user1));
        assertTrue(ifo.whitelisted(address(user1)));
    }

    function testAddWhitelistNotCurator() public {
        IFO ifo = createValidAllowWhitelistIFO();

        vm.startPrank(address(user1));

        vm.expectRevert(IIFO.NotCurator.selector);
        ifo.addWhitelist(address(user1));

        vm.stopPrank();
    }

    function testAddWhitelistWhitelistNotAllowed() public {
        IFO ifo = createValidIFO();

        vm.expectRevert(IIFO.WhitelistingDisallowed.selector);
        ifo.addWhitelist(address(user1));
    }

    function testAddMultipleWhitelist() public {
        IFO ifo = createValidAllowWhitelistIFO();

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(user1);
        whitelists[1] = address(user2);
        whitelists[2] = address(user3);
        ifo.addMultipleWhitelists(whitelists);

        assertTrue(ifo.whitelisted(address(user1)));
        assertTrue(ifo.whitelisted(address(user2)));
        assertTrue(ifo.whitelisted(address(user3)));
    }

    function testAddMultipleWhitelistNotCurator() public {
        IFO ifo = createValidAllowWhitelistIFO();

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(user1);
        whitelists[1] = address(user2);
        whitelists[2] = address(user3);

        vm.startPrank(address(user1));

        vm.expectRevert(IIFO.NotCurator.selector);
        ifo.addMultipleWhitelists(whitelists);

        vm.stopPrank();
    }

    function testAddMultipleWhitelistWhitelistNotAllowed() public {
        IFO ifo = createValidIFO();

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(user1);
        whitelists[1] = address(user2);
        whitelists[2] = address(user3);

        vm.expectRevert(IIFO.WhitelistingDisallowed.selector);
        ifo.addMultipleWhitelists(whitelists);
    }

    function testRemoveWhitelist() public {
        IFO ifo = createValidAllowWhitelistIFO();

        ifo.addWhitelist(address(user1));

        assertTrue(ifo.whitelisted(address(user1)));

        ifo.removeWhitelist(address(user1));

        assertTrue(!ifo.whitelisted(address(user1)));
    }

    function testRemoveWhitelistNotCurator() public {
        IFO ifo = createValidAllowWhitelistIFO();

        ifo.addWhitelist(address(user1));

        assertTrue(ifo.whitelisted(address(user1)));

        vm.startPrank(address(user1));

        vm.expectRevert(IIFO.NotCurator.selector);
        ifo.removeWhitelist(address(user1));

        vm.stopPrank();
    }

    function testStart() public {
        IFO ifo = createValidIFO();

        assertTrue(!ifo.started());

        ifo.start();

        assertTrue(ifo.started());
    }

    function testStartNotCurator() public {
        IFO ifo = createValidIFO();

        assertTrue(!ifo.started());

        vm.startPrank(address(user1));

        vm.expectRevert(IIFO.NotCurator.selector);
        ifo.start();

        vm.stopPrank();
    }

    function testStartAlreadyStarted() public {
        IFO ifo = createValidIFO();

        assertTrue(!ifo.started());

        ifo.start();

        assertTrue(ifo.started());

        vm.expectRevert(IIFO.SaleAlreadyStarted.selector);
        ifo.start();
    }

    function testEnd() public {
        IFO ifo = createValidIFO();

        assertTrue(!ifo.started());

        ifo.start();

        assertTrue(ifo.started());

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        assertTrue(ifo.ended());
    }

    function testFailStartDoesNotHaveFNFT() public {
        fnftSingle.approve(address(ifoFactory), fnftSingle.balanceOf(address(this)));

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFO.__IFO_init.selector,
            address(this),
            address(fnftSingle), // the address of the fractionalized token
            fnftSingle.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fnftSingle.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            true // allow whitelist
        );

        IFO ifo = IFO(address(new BeaconProxy(address(new IFO()), _initializationCalldata)));

        ifo.start();
    }

    function testEndNotCurator() public {
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.startPrank(address(user1));

        vm.expectRevert(IIFO.NotCurator.selector);
        ifo.end();

        vm.stopPrank();
    }

    function testEndWhilePaused() public {
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        ifo.togglePause();

        assertTrue(ifo.paused());

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.expectRevert(IIFO.ContractPaused.selector);
        ifo.end();
    }

    function testEndBeforeStart() public {
        IFO ifo = createValidIFO();

        assertTrue(!ifo.started());

        vm.expectRevert(IIFO.SaleUnstarted.selector);
        ifo.end();
    }

    function testEndBeforeDuration() public {
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration());

        vm.expectRevert(IIFO.DeadlineActive.selector);
        ifo.end();
    }

    function testEndAfterEnd() public {
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        assertTrue(ifo.ended());

        vm.expectRevert(IIFO.SaleAlreadyEnded.selector);
        ifo.end();
    }

    function testEndBeforeMinimumDurationForInfiniteDuration() public {
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        vm.expectRevert(IIFO.DeadlineActive.selector);
        ifo.end();
    }

    function testEndAfterMinimumDurationForInfiniteDuration() public {
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();
    }

    function testTogglePause() public {
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        vm.roll(ifo.startBlock() + 1000);

        assertEq(block.number, ifo.startBlock() + 1000);

        ifo.togglePause();

        assertTrue(ifo.paused());

        assertEq(ifo.duration(), ifoFactory.minimumDuration());

        vm.roll(ifo.pauseBlock() + 1000);

        ifo.togglePause();

        assertTrue(!ifo.paused());

        assertEq(ifo.duration(), ifoFactory.minimumDuration() + 1000);
    }

    function testTogglePauseWhenNotStarted() public {
        IFO ifo = createValidIFO();

        vm.expectRevert(IIFO.SaleUnstarted.selector);
        ifo.togglePause();
    }

    function testTogglePauseAfterEnded() public {
        IFO ifo = createValidIFO();

        ifo.start();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        vm.expectRevert(IIFO.SaleAlreadyEnded.selector);
        ifo.togglePause();
    }

    function testTogglePauseNotCurator() public {
        IFO ifo = createValidIFO();

        ifo.start();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.startPrank(address(user1));

        vm.expectRevert(IIFO.NotCurator.selector);
        ifo.togglePause();

        vm.stopPrank();
    }

    function testWithdrawProfit() public {
        IFO ifo = createValidIFO();
        uint256 originalAccountBalance = address(this).balance;
        uint256 originalUser2Balance = address(user2).balance;

        ifoFactory.setFeeReceiver(payable(address(user1)));
        uint256 govFee = ifoFactory.governanceFee();
        uint256 fee = (govFee * 1 ether) / 10000;
        uint256 profit = 1 ether - fee;

        ifo.start();

        assertTrue(ifo.started());

        ifo.deposit{value: 1 ether}();

        vm.startPrank(address(user2));
        ifo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(ifo.profitRaised(), profit * 2);

        assertEq(address(ifo).balance, profit * 2);

        assertEq(address(this).balance, originalAccountBalance - 1 ether);

        assertEq(address(user2).balance, originalUser2Balance - 1 ether);

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        ifo.adminWithdrawProfit();

        assertEq(ifo.profitRaised(), 0);

        assertEq(address(ifo).balance, 0);

        assertEq(address(user2).balance, originalUser2Balance - 1 ether);

        assertEq(address(this).balance, originalAccountBalance - 1 ether + profit * 2);
    }

    function testWithdrawProfitNotCurator() public {
        IFO ifo = createValidIFO();

        ifoFactory.setFeeReceiver(payable(address(user1)));

        ifo.start();

        assertTrue(ifo.started());

        ifo.deposit{value: 1 ether}();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        vm.startPrank(address(user2));
        vm.expectRevert(IIFO.NotCurator.selector);
        ifo.adminWithdrawProfit();
        vm.stopPrank();
    }

    function testWithdrawProfitAutoEndsAfterDuration() public {
        IFO ifo = createValidIFO();

        ifoFactory.setFeeReceiver(payable(address(user1)));

        ifo.start();

        assertTrue(ifo.started());

        ifo.deposit{value: 1 ether}();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.adminWithdrawProfit();
    }

    function testWithdrawProfitBeforeEnd() public {
        fnftSingle.approve(address(ifoFactory), fnftSingle.balanceOf(address(this)));
        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            fnftSingle.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fnftSingle.totalSupply(), // max amount someone can buy
            0, //sale duration
            false // allow whitelist
        );
        IFO ifo = IFO(ifoFactory.ifos(address(fnftSingle)));

        ifoFactory.setFeeReceiver(payable(address(user1)));

        ifo.start();

        assertTrue(ifo.started());

        ifo.deposit{value: 1 ether}();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.expectRevert(IIFO.SaleActive.selector);
        ifo.adminWithdrawProfit();
    }

    function testWithdrawProfitTwice() public {
        IFO ifo = createValidIFO();

        ifoFactory.setFeeReceiver(payable(address(user1)));

        ifo.start();

        assertTrue(ifo.started());

        ifo.deposit{value: 1 ether}();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.adminWithdrawProfit();

        vm.expectRevert(IIFO.NoProfit.selector);
        ifo.adminWithdrawProfit();
    }

    function testWithdrawFNFT() public {
        uint originalBalance = fnftSingle.balanceOf(address(this));
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        assertEq(fnftSingle.balanceOf(address(this)), 0);

        assertEq(fnftSingle.balanceOf(address(ifo)), originalBalance);

        vm.startPrank(address(user1));
        ifo.deposit{value: 1 ether}();
        vm.stopPrank();

        uint256 withdrawnBalance = originalBalance - (1 ether * 1e18 / 0.01 ether);
        assertEq(fnftSingle.balanceOf(address(ifo)), withdrawnBalance);

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        ifo.adminWithdrawFNFT();

        assertEq(fnftSingle.balanceOf(address(ifo)), 0);

        assertEq(fnftSingle.balanceOf(address(this)), withdrawnBalance);
    }

    function testWithdrawFNFTWhileSaleActive() public {
        uint originalBalance = fnftSingle.balanceOf(address(this));
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        assertEq(fnftSingle.balanceOf(address(this)), 0);

        assertEq(fnftSingle.balanceOf(address(ifo)), originalBalance);

        vm.startPrank(address(user1));
        ifo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fnftSingle.balanceOf(address(ifo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.expectRevert(IIFO.SaleActive.selector);
        ifo.adminWithdrawFNFT();
    }

    function testWithdrawFNFTAutoEndsAfterDuration() public {
        uint originalBalance = fnftSingle.balanceOf(address(this));
        IFO ifo = createValidIFO();

        ifo.start();

        assertTrue(ifo.started());

        assertEq(fnftSingle.balanceOf(address(this)), 0);

        assertEq(fnftSingle.balanceOf(address(ifo)), originalBalance);

        vm.startPrank(address(user1));
        ifo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fnftSingle.balanceOf(address(ifo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.adminWithdrawFNFT();

        assertEq(fnftSingle.balanceOf(address(ifo)), 0);

        assertEq(fnftSingle.balanceOf(address(this)), originalBalance - (1 ether * 1e18 / 0.01 ether));
    }

    function testWithdrawFNFTIfLockedAndRedeemed() public {
        uint originalBalance = fnftSingle.balanceOf(address(this));
        IFO ifo = createValidIFO();
        ifoFactory.setCreatorIFOLock(true);

        ifo.start();

        assertTrue(ifo.started());

        assertEq(fnftSingle.balanceOf(address(this)), 0);

        assertEq(fnftSingle.balanceOf(address(ifo)), originalBalance);

        vm.startPrank(address(user1));
        ifo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fnftSingle.balanceOf(address(ifo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        //start and end the bidding process
        user1.call_start(10 ether);
        assertTrue(fnftSingle.auctionState() == IFNFTSingle.State.Live);
        vm.warp(block.timestamp + 7 days);

        fnftSingle.end();
        assertTrue(fnftSingle.auctionState() == IFNFTSingle.State.Ended);

        ifo.adminWithdrawFNFT();

        assertEq(fnftSingle.balanceOf(address(ifo)), 0);

        assertEq(fnftSingle.balanceOf(address(this)), originalBalance - (1 ether * 1e18 / 0.01 ether));
    }

    function testWithdrawFNFTIfLockedAndNotRedeemed() public {
        uint originalBalance = fnftSingle.balanceOf(address(this));
        IFO ifo = createValidIFO();
        ifoFactory.setCreatorIFOLock(true);
        ifo.start();

        assertTrue(ifo.started());

        assertEq(fnftSingle.balanceOf(address(this)), 0);

        assertEq(fnftSingle.balanceOf(address(ifo)), originalBalance);

        vm.startPrank(address(user1));
        ifo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fnftSingle.balanceOf(address(ifo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        vm.expectRevert(IIFO.FNFTLocked.selector);
        ifo.adminWithdrawFNFT();
    }

    function testApproveUtilityContract() public {
        ifoFactory.setCreatorUtilityContract(address(user2));
        uint originalBalance = fnftSingle.balanceOf(address(this));
        IFO ifo = createValidIFO();

        vm.startPrank(address(user2));
        fnftSingle.transferFrom(address(ifo), address(user2), fnftSingle.balanceOf(address(ifo)));
        vm.stopPrank();

        assertEq(fnftSingle.balanceOf(address(ifo)), 0);
        assertEq(fnftSingle.balanceOf(address(user2)), originalBalance);
    }

    function testFailApproveUtilityContractZeroAddress() public {
        IFO ifo = createValidIFO();

        vm.startPrank(address(user2));
        fnftSingle.transferFrom(address(ifo), address(user2), fnftSingle.balanceOf(address(ifo)));
        vm.stopPrank();
    }

    function testManualApproveUtilityContract() public {
        uint originalBalance = fnftSingle.balanceOf(address(this));
        IFO ifo = createValidIFO();

        ifoFactory.setCreatorUtilityContract(address(user2));

        ifo.approve();

        vm.startPrank(address(user2));
        fnftSingle.transferFrom(address(ifo), address(user2), fnftSingle.balanceOf(address(ifo)));
        vm.stopPrank();

        assertEq(fnftSingle.balanceOf(address(ifo)), 0);
        assertEq(fnftSingle.balanceOf(address(user2)), originalBalance);
    }

    function testManualApproveUtilityContractZeroAddress() public {
        IFO ifo = createValidIFO();

        vm.expectRevert(IIFO.ZeroAddress.selector);
        ifo.approve();
    }

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    function testDeposit() public {
        uint256 originalAccountFNFTBalance = fnftSingle.balanceOf(address(this));
        uint256 price = 0.01 ether;
        IFO ifo = createValidIFOWith3EthCap();
        uint256 originalAccountBalance = address(this).balance;
        uint256 originalUser2Balance = address(user2).balance;
        uint256 originalUser1Balance = address(user1).balance;

        ifoFactory.setFeeReceiver(payable(address(user1)));
        uint256 govFee = ifoFactory.governanceFee();
        uint256 fee = (govFee * 1 ether) / 10000;
        uint256 profit = 1 ether - fee;

        ifo.start();

        //started
        assertTrue(ifo.started());

        //start remaining allocation 3
        assertEq(ifo.getUserRemainingAllocation(address(this)), 3 ether * 1e18 / price, "this remaining allocaiton 3");
        assertEq(ifo.getUserRemainingAllocation(address(user2)), 3 ether * 1e18 / price, "user2 remaining allocaiton 3");

        //fnft balance 0 before deposit
        assertEq(fnftSingle.balanceOf(address(this)), 0, "this fnft balance before deposit");
        assertEq(fnftSingle.balanceOf(address(user2)), 0, "user2 fnft balance before deposit");

        //fnft balance full in ifo contract
        assertEq(fnftSingle.balanceOf(address(ifo)), originalAccountFNFTBalance, "ifo fnft balance before deposit");

        ifo.deposit{value: 1 ether}();

        //fnft balance of ifo contract after this address deposit
        assertEq(fnftSingle.balanceOf(address(ifo)), originalAccountFNFTBalance - (1 ether * 1e18 / price), "ifo fnft balance after this deposit");
        //profitRaised balance of ifo contract after this address deposit
        assertEq(ifo.profitRaised(), profit, "profitRaised balance after this deposit");
        //totalaRaised balance of ifo contract after this address deposit
        assertEq(ifo.totalRaised(), 1 ether, "totalRaised balance after this deposit");
        //this address remaining allocation (3 - 1)
        assertEq(ifo.getUserRemainingAllocation(address(this)), 2 ether * 1e18 / price, "this remaining allocation after deposit");
        //this address got fnft
        assertEq(fnftSingle.balanceOf(address(this)), 1 ether * 1e18 / price, "this address fnft balance after deposit");
        //this balance after deposit
        assertEq(address(this).balance, originalAccountBalance - 1 ether);
        //ifo balance after deposit
        assertEq(address(ifo).balance, profit);
        //user1 balance after deposit
        assertEq(address(user1).balance, originalUser1Balance + fee);

        vm.startPrank(address(user2));
        ifo.deposit{value: 2 ether}();
        vm.stopPrank();

        //fnft balance of ifo contract after user2 address deposit (1 + 2)
        assertEq(fnftSingle.balanceOf(address(ifo)), originalAccountFNFTBalance - (3 ether * 1e18 / price), "ifo fnft balance after user2 deposit");
        //profitRaised balance of ifo contract after user2 address deposit
        assertEq(ifo.profitRaised(), profit * 3, "profitRaised balance after user2 deposit");
        //totalaRaised balance of ifo contract after user2 address deposit
        assertEq(ifo.totalRaised(), 3 ether, "totalRaised balance after user2 deposit");
        //user2 address remaining allocation (3 - 2)
        assertEq(ifo.getUserRemainingAllocation(address(user2)), 1 ether * 1e18 / price, "user2 remaining allocation after deposit");
        //user2 address got fnft
        assertEq(fnftSingle.balanceOf(address(user2)), 2 ether * 1e18 / price, "user2 address fnft balance after deposit");
        //this balance after deposit
        assertEq(address(user2).balance, originalUser2Balance - 2 ether);
        //ifo balance after deposit
        assertEq(address(ifo).balance, profit * 3);
        //user1 balance after deposit
        assertEq(address(user1).balance, originalUser1Balance + fee * 3);
    }

    function testDepositAfterSaleEnded() public {
        IFO ifo = createValidIFOWith3EthCap();

        ifo.start();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        ifo.end();

        vm.expectRevert(IIFO.SaleAlreadyEnded.selector);
        ifo.deposit{value: 1 ether}();
    }

    function testDepositWhilePaused() public {
        IFO ifo = createValidIFOWith3EthCap();

        ifo.start();

        ifo.togglePause();

        vm.expectRevert(IIFO.ContractPaused.selector);
        ifo.deposit{value: 1 ether}();
    }

    function testDepositAfterSaleResumesAfterDeadline() public {
        IFO ifo = createValidIFOWith3EthCap();

        ifo.start();

        ifo.togglePause();

        assertEq(ifo.duration(), ifoFactory.minimumDuration());

        vm.roll(ifo.startBlock() + 1000);

        assertEq(ifo.duration(), ifoFactory.minimumDuration());

        ifo.togglePause();

        assertEq(ifo.duration(), ifoFactory.minimumDuration() + 1000);

        ifo.deposit{value: 1 ether}();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1001);

        ifo.end();
    }

    function testDepositSaleEndAutoAfterDeadline() public {
        IFO ifo = createValidIFO();

        ifo.start();

        vm.roll(ifo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.expectRevert(IIFO.SaleAlreadyEnded.selector);
        ifo.deposit{value: 1 ether}();
    }

    function testDepositBeforeSaleStarted() public {
        IFO ifo = createValidIFO();

        vm.expectRevert(IIFO.SaleUnstarted.selector);
        ifo.deposit{value: 1 ether}();
    }

    function testDepositIfNotWhitelisted() public {
        uint256 originalAccountFNFTBalance = fnftSingle.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fnftSingle.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO ifo = IFO(ifoFactory.ifos(address(fnftSingle)));

        ifo.start();

        vm.expectRevert(IIFO.NotWhitelisted.selector);
        ifo.deposit{value: 1 ether}();
    }

    function testDepositAfterWhitelisted() public {
        uint256 originalAccountFNFTBalance = fnftSingle.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fnftSingle.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fnftSingle), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO ifo = IFO(ifoFactory.ifos(address(fnftSingle)));
        ifo.addWhitelist(address(this));

        ifo.start();

        ifo.deposit{value: 1 ether}();
    }

    function testDepositMoreThanCap() public {
        IFO ifo = createValidIFOWith3EthCap();

        ifo.start();

        vm.expectRevert(IIFO.OverLimit.selector);
        ifo.deposit{value: 3.1 ether}();
    }

    function testDepositMoreThanCapAfterDeposit() public {
        IFO ifo = createValidIFOWith3EthCap();

        ifo.start();

        ifo.deposit{value: 1 ether}();

        vm.expectRevert(IIFO.OverLimit.selector);
        ifo.deposit{value: 2.1 ether}();
    }

    function testDepositMoreThanCapAfterMeetingDeposit() public {
        IFO ifo = createValidIFOWith3EthCap();

        ifo.start();

        ifo.deposit{value: 1 ether}();

        ifo.deposit{value: 2 ether}();

        vm.expectRevert(IIFO.OverLimit.selector);
        ifo.deposit{value: 1 ether}();
    }

    function testGetUserRemainingAllocation() public {
        uint256 price = 0.01 ether;
        IFO ifo = createValidIFOWith3EthCap();

        ifo.start();

        assertEq(ifo.getUserRemainingAllocation(address(this)), 3 ether * 1e18 / price);

        ifo.deposit{value: 1 ether}();

        assertEq(ifo.getUserRemainingAllocation(address(this)), 2 ether * 1e18 / price);

        ifo.deposit{value: 2 ether}();

        assertEq(ifo.getUserRemainingAllocation(address(this)), 0);
    }

    receive() external payable {}
}