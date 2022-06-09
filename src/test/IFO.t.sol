//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IFOFactory} from "../contracts/IFOFactory.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";
import {PriceOracle} from "../contracts/PriceOracle.sol";
import {FNFTFactory} from "../contracts/FNFTFactory.sol";
import {FNFT} from "../contracts/FNFT.sol";
import {IFO} from "../contracts/IFO.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {console, CheatCodes, SetupEnvironment, User, Curator, UserNoETH} from "./utils/utils.sol";
import {BeaconProxy} from "../contracts/proxy/BeaconProxy.sol";

/// @author Nibble Market
/// @title Tests for the fnfts
contract IFOTest is DSTest, ERC721Holder, SetupEnvironment {
    FNFTFactory public fnftFactory;
    IFOFactory public ifoFactory;
    IPriceOracle public priceOracle;
    MockNFT public nft;
    FNFT public fractionalizedNFT;

    User public user1;
    User public user2;
    User public user3;

    Curator public curator;

    function setUp() public {
        setupEnvironment(10 ether);
        (, priceOracle, ifoFactory, fnftFactory, ) = setupContracts(10 ether);

        fnftFactory.setFee(FNFTFactory.FeeType.GovernanceFee, 0);

        nft = new MockNFT();

        nft.mint(address(this), 1);

        nft.setApprovalForAll(address(fnftFactory), true);
        fractionalizedNFT = FNFT(
            fnftFactory.mint(
                "testName",
                "TEST",
                address(nft),
                1, // tokenId
                1000e18, //supply: minted to the fractionalizer
                10 ether, // listPrice: the initial reserve price
                0 // the % * 10 fee minted to the fractionalizer anually
            )
        );

        // create a curator account
        curator = new Curator(address(fractionalizedNFT));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fractionalizedNFT));
        user2 = new User(address(fractionalizedNFT));
        user3 = new User(address(fractionalizedNFT));

        payable(address(user1)).transfer(20 ether);
        payable(address(user2)).transfer(20 ether);
        payable(address(user3)).transfer(20 ether);
    }

    /// -------------------------------
    /// -------- INIT FUNCTIONS -------
    /// -------------------------------
    function createValidIFO() private returns(IFO fNFTIfo) {
        uint balance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), balance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            balance, // amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );
        fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));
    }

    function createValidAllowWhitelistIFO() private returns(IFO fNFTIfo) {
        uint balance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), balance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            balance, // amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            true // allow whitelist
        );
        fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));
    }

    function createValidIFOWith3EthCap() private returns(IFO fNFTIfo) {
        uint256 balance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), balance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            balance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );
        fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));
    }

    function testPause() public {
        ifoFactory.pause();
        ifoFactory.unpause();
    }

    function testCreateIFO() public {
        IFO fNFTIfo = createValidIFO();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), fractionalizedNFT.totalSupply());
        assertEq(fNFTIfo.duration(), ifoFactory.minimumDuration());
    }

    function testCreateIFOInvalidAddress() public {
        uint256 balance = fractionalizedNFT.balanceOf(address(this));
        uint256 totalSupply = fractionalizedNFT.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fractionalizedNFT.approve(address(ifoFactory), balance);
        vm.expectRevert(IFO.InvalidAddress.selector);
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
        uint256 balance = fractionalizedNFT.balanceOf(address(this));
        uint256 totalSupply = fractionalizedNFT.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fractionalizedNFT.approve(address(ifoFactory), balance);
        // burn 1
        fractionalizedNFT.transfer(0x000000000000000000000000000000000000dEaD, 1);
        vm.expectRevert(IFO.NotEnoughSupply.selector);
        ifoFactory.create(
            address(fractionalizedNFT),
            balance, //amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOMarketCapTooHigh() public {
        uint256 balance = fractionalizedNFT.balanceOf(address(this));
        uint256 totalSupply = fractionalizedNFT.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fractionalizedNFT.approve(address(ifoFactory), balance);
        vm.expectRevert(IFO.InvalidCap.selector);
        ifoFactory.create(
            address(fractionalizedNFT),
            balance, //amountForSale
            0.01 ether, //price per token
            totalSupply + 1, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOMarketCapTooLow() public {
        uint256 balance = fractionalizedNFT.balanceOf(address(this));
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fractionalizedNFT.approve(address(ifoFactory), balance);
        vm.expectRevert(IFO.InvalidCap.selector);
        ifoFactory.create(
            address(fractionalizedNFT),
            balance, //amountForSale
            0.01 ether, //price per token
            0, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOAmountForSaleTooLow() public {
        uint256 totalSupply = fractionalizedNFT.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));
        vm.expectRevert(IFO.InvalidAmountForSale.selector);
        ifoFactory.create(
            address(fractionalizedNFT),
            0, // amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOAmountForSaleTooHigh() public {
        uint256 balance = fractionalizedNFT.balanceOf(address(this));
        uint256 totalSupply = fractionalizedNFT.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fractionalizedNFT.approve(address(ifoFactory), balance);
        vm.expectRevert(IFO.InvalidAmountForSale.selector);
        ifoFactory.create(
            address(fractionalizedNFT),
            balance + 1, //amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFOMarketCapHigherThanInitialReserve() public {
        uint256 balance = fractionalizedNFT.balanceOf(address(this));
        uint256 totalSupply = fractionalizedNFT.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fractionalizedNFT.approve(address(ifoFactory), balance);
        vm.expectRevert(IFO.InvalidReservePrice.selector);
        ifoFactory.create(
            address(fractionalizedNFT),
            balance, //amountForSale
            0.02 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFODurationTooLow() public {
        uint256 balance = fractionalizedNFT.balanceOf(address(this));
        uint256 totalSupply = fractionalizedNFT.totalSupply();
        uint256 minimumDuration = ifoFactory.minimumDuration();
        fractionalizedNFT.approve(address(ifoFactory), balance);
        vm.expectRevert(IFO.InvalidDuration.selector);
        ifoFactory.create(
            address(fractionalizedNFT),
            balance, //amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            minimumDuration - 1, //sale duration
            false // allow whitelist
        );
    }

    function testCreateIFODurationTooHigh() public {
        uint256 balance = fractionalizedNFT.balanceOf(address(this));
        uint256 totalSupply = fractionalizedNFT.totalSupply();
        uint256 maximumDuration = ifoFactory.maximumDuration();
        fractionalizedNFT.approve(address(ifoFactory), balance);
        vm.expectRevert(IFO.InvalidDuration.selector);
        ifoFactory.create(
            address(fractionalizedNFT),
            balance, //amountForSale
            0.01 ether, //price per token
            totalSupply, // max amount someone can buy
            maximumDuration + 1, //sale duration
            false // allow whitelist
        );
    }

    function testCannotCreateWhenPaused() public {
        ifoFactory.pause();
        uint256 thisBalance = fractionalizedNFT.balanceOf(address(this));
        vm.expectRevert(bytes("Pausable: paused"));
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
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
        fractionalizedNFT.approve(address(this), fractionalizedNFT.balanceOf(address(this)));
        fractionalizedNFT.transferFrom(address(this), address(user1), fractionalizedNFT.balanceOf(address(this)));

        vm.startPrank(address(user1));

        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(user1)));

        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(user1)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        vm.stopPrank();

        fNFTIfo.updateFNFTAddress(address(user2));

        assertEq(address(fNFTIfo.fnft()), address(user2));
    }

    function testUpdateFNFTAddresZeroAddress() public {
        IFO fNFTIfo = createValidIFO();

        vm.expectRevert(IFO.InvalidAddress.selector);
        fNFTIfo.updateFNFTAddress(address(0));
    }

    function testUpdateFNFTAddressNotGov() public {
        fractionalizedNFT.approve(address(this), fractionalizedNFT.balanceOf(address(this)));
        fractionalizedNFT.transferFrom(address(this), address(user1), fractionalizedNFT.balanceOf(address(this)));

        vm.startPrank(address(user1));

        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(user1)));

        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(user1)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        vm.expectRevert(IFO.NotGov.selector);
        fNFTIfo.updateFNFTAddress(address(user1));

        vm.stopPrank();
    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    function testAddWhitelist() public {
        IFO fNFTIfo = createValidAllowWhitelistIFO();

        fNFTIfo.addWhitelist(address(user1));
        assertTrue(fNFTIfo.whitelisted(address(user1)));
    }

    function testAddWhitelistNotCurator() public {
        IFO fNFTIfo = createValidAllowWhitelistIFO();

        vm.startPrank(address(user1));

        vm.expectRevert(IFO.NotCurator.selector);
        fNFTIfo.addWhitelist(address(user1));

        vm.stopPrank();
    }

    function testAddWhitelistWhitelistNotAllowed() public {
        IFO fNFTIfo = createValidIFO();

        vm.expectRevert(IFO.WhitelistingDisallowed.selector);
        fNFTIfo.addWhitelist(address(user1));
    }

    function testAddMultipleWhitelist() public {
        IFO fNFTIfo = createValidAllowWhitelistIFO();

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(user1);
        whitelists[1] = address(user2);
        whitelists[2] = address(user3);
        fNFTIfo.addMultipleWhitelists(whitelists);

        assertTrue(fNFTIfo.whitelisted(address(user1)));
        assertTrue(fNFTIfo.whitelisted(address(user2)));
        assertTrue(fNFTIfo.whitelisted(address(user3)));
    }

    function testAddMultipleWhitelistNotCurator() public {
        IFO fNFTIfo = createValidAllowWhitelistIFO();

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(user1);
        whitelists[1] = address(user2);
        whitelists[2] = address(user3);

        vm.startPrank(address(user1));

        vm.expectRevert(IFO.NotCurator.selector);
        fNFTIfo.addMultipleWhitelists(whitelists);

        vm.stopPrank();
    }

    function testAddMultipleWhitelistWhitelistNotAllowed() public {
        IFO fNFTIfo = createValidIFO();

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(user1);
        whitelists[1] = address(user2);
        whitelists[2] = address(user3);

        vm.expectRevert(IFO.WhitelistingDisallowed.selector);
        fNFTIfo.addMultipleWhitelists(whitelists);
    }

    function testRemoveWhitelist() public {
        IFO fNFTIfo = createValidAllowWhitelistIFO();

        fNFTIfo.addWhitelist(address(user1));

        assertTrue(fNFTIfo.whitelisted(address(user1)));

        fNFTIfo.removeWhitelist(address(user1));

        assertTrue(!fNFTIfo.whitelisted(address(user1)));
    }

    function testRemoveWhitelistNotCurator() public {
        IFO fNFTIfo = createValidAllowWhitelistIFO();

        fNFTIfo.addWhitelist(address(user1));

        assertTrue(fNFTIfo.whitelisted(address(user1)));

        vm.startPrank(address(user1));

        vm.expectRevert(IFO.NotCurator.selector);
        fNFTIfo.removeWhitelist(address(user1));

        vm.stopPrank();
    }

    function testStart() public {
        IFO fNFTIfo = createValidIFO();

        assertTrue(!fNFTIfo.started());

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());
    }

    function testStartNotCurator() public {
        IFO fNFTIfo = createValidIFO();

        assertTrue(!fNFTIfo.started());

        vm.startPrank(address(user1));

        vm.expectRevert(IFO.NotCurator.selector);
        fNFTIfo.start();

        vm.stopPrank();
    }

    function testStartAlreadyStarted() public {
        IFO fNFTIfo = createValidIFO();

        assertTrue(!fNFTIfo.started());

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        vm.expectRevert(IFO.SaleAlreadyStarted.selector);
        fNFTIfo.start();
    }

    function testEnd() public {
        IFO fNFTIfo = createValidIFO();

        assertTrue(!fNFTIfo.started());

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        assertTrue(fNFTIfo.ended());
    }

    function testFail_startDoesNotHaveFNFT() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFO.initialize.selector,
            address(this),
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            true // allow whitelist
        );

        IFO fNFTIfo = IFO(address(new BeaconProxy(address(new IFO()), _initializationCalldata)));

        fNFTIfo.start();
    }

    function testEndNotCurator() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.startPrank(address(user1));

        vm.expectRevert(IFO.NotCurator.selector);
        fNFTIfo.end();

        vm.stopPrank();
    }

    function testEndWhilePaused() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        fNFTIfo.togglePause();

        assertTrue(fNFTIfo.paused());

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.expectRevert(IFO.ContractPaused.selector);
        fNFTIfo.end();
    }

    function testEndBeforeStart() public {
        IFO fNFTIfo = createValidIFO();

        assertTrue(!fNFTIfo.started());

        vm.expectRevert(IFO.SaleUnstarted.selector);
        fNFTIfo.end();
    }

    function testEndBeforeDuration() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration());

        vm.expectRevert(IFO.DeadlineActive.selector);
        fNFTIfo.end();
    }

    function testEndAfterEnd() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        assertTrue(fNFTIfo.ended());

        vm.expectRevert(IFO.SaleAlreadyEnded.selector);
        fNFTIfo.end();
    }

    function testEndBeforeMinimumDurationForInfiniteDuration() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        vm.expectRevert(IFO.DeadlineActive.selector);
        fNFTIfo.end();
    }

    function testEndAfterMinimumDurationForInfiniteDuration() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();
    }

    function testTogglePause() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        vm.roll(fNFTIfo.startBlock() + 1000);

        assertEq(block.number, fNFTIfo.startBlock() + 1000);

        fNFTIfo.togglePause();

        assertTrue(fNFTIfo.paused());

        assertEq(fNFTIfo.duration(), ifoFactory.minimumDuration());

        vm.roll(fNFTIfo.pauseBlock() + 1000);

        fNFTIfo.togglePause();

        assertTrue(!fNFTIfo.paused());

        assertEq(fNFTIfo.duration(), ifoFactory.minimumDuration() + 1000);
    }

    function testTogglePauseWhenNotStarted() public {
        IFO fNFTIfo = createValidIFO();

        vm.expectRevert(IFO.SaleUnstarted.selector);
        fNFTIfo.togglePause();
    }

    function testTogglePauseAfterEnded() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        vm.expectRevert(IFO.SaleAlreadyEnded.selector);
        fNFTIfo.togglePause();
    }

    function testTogglePauseNotCurator() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.startPrank(address(user1));

        vm.expectRevert(IFO.NotCurator.selector);
        fNFTIfo.togglePause();

        vm.stopPrank();
    }

    function testWithdrawProfit() public {
        IFO fNFTIfo = createValidIFO();
        uint256 originalAccountBalance = address(this).balance;
        uint256 originalUser2Balance = address(user2).balance;

        ifoFactory.setFeeReceiver(payable(address(user1)));
        uint256 govFee = ifoFactory.governanceFee();
        uint256 fee = (govFee * 1 ether) / 10000;
        uint256 profit = 1 ether - fee;

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        fNFTIfo.deposit{value: 1 ether}();

        vm.startPrank(address(user2));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fNFTIfo.profitRaised(), profit * 2);

        assertEq(address(fNFTIfo).balance, profit * 2);

        assertEq(address(this).balance, originalAccountBalance - 1 ether);

        assertEq(address(user2).balance, originalUser2Balance - 1 ether);

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        fNFTIfo.adminWithdrawProfit();

        assertEq(fNFTIfo.profitRaised(), 0);

        assertEq(address(fNFTIfo).balance, 0);

        assertEq(address(user2).balance, originalUser2Balance - 1 ether);

        assertEq(address(this).balance, originalAccountBalance - 1 ether + profit * 2);
    }

    function testWithdrawProfitNotCurator() public {
        IFO fNFTIfo = createValidIFO();

        ifoFactory.setFeeReceiver(payable(address(user1)));

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        vm.startPrank(address(user2));
        vm.expectRevert(IFO.NotCurator.selector);
        fNFTIfo.adminWithdrawProfit();
        vm.stopPrank();
    }

    function testWithdrawProfitAutoEndsAfterDuration() public {
        IFO fNFTIfo = createValidIFO();

        ifoFactory.setFeeReceiver(payable(address(user1)));

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.adminWithdrawProfit();
    }

    function testWithdrawProfitBeforeEnd() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            0, //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        ifoFactory.setFeeReceiver(payable(address(user1)));

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.expectRevert(IFO.SaleActive.selector);
        fNFTIfo.adminWithdrawProfit();
    }

    function testWithdrawProfitTwice() public {
        IFO fNFTIfo = createValidIFO();

        ifoFactory.setFeeReceiver(payable(address(user1)));

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.adminWithdrawProfit();

        vm.expectRevert(IFO.NoProfit.selector);
        fNFTIfo.adminWithdrawProfit();
    }

    function testWithdrawFNFT() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0);

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        uint256 withdrawnBalance = originalBalance - (1 ether * 1e18 / 0.01 ether);
        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), withdrawnBalance);

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        fNFTIfo.adminWithdrawFNFT();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), 0);

        assertEq(fractionalizedNFT.balanceOf(address(this)), withdrawnBalance);
    }

    function testWithdrawFNFTWhileSaleActive() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0);

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.expectRevert(IFO.SaleActive.selector);
        fNFTIfo.adminWithdrawFNFT();
    }

    function testWithdrawFNFTAutoEndsAfterDuration() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0);

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.adminWithdrawFNFT();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), 0);

        assertEq(fractionalizedNFT.balanceOf(address(this)), originalBalance - (1 ether * 1e18 / 0.01 ether));
    }

    function testWithdrawFNFTIfLockedAndRedeemed() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        IFO fNFTIfo = createValidIFO();
        ifoFactory.setCreatorIFOLock(true);

        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0);

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        //start and end the bidding process
        user1.call_start(10 ether);
        assertTrue(fractionalizedNFT.auctionState() == FNFT.State.Live);
        vm.warp(block.timestamp + 7 days);

        fractionalizedNFT.end();
        assertTrue(fractionalizedNFT.auctionState() == FNFT.State.Ended);

        fNFTIfo.adminWithdrawFNFT();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), 0);

        assertEq(fractionalizedNFT.balanceOf(address(this)), originalBalance - (1 ether * 1e18 / 0.01 ether));
    }

    function testWithdrawFNFTIfLockedAndNotRedeemed() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        IFO fNFTIfo = createValidIFO();
        ifoFactory.setCreatorIFOLock(true);
        fNFTIfo.start();

        assertTrue(fNFTIfo.started());

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0);

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        vm.expectRevert(IFO.FNFTLocked.selector);
        fNFTIfo.adminWithdrawFNFT();
    }

    function testApproveUtilityContract() public {
        ifoFactory.setCreatorUtilityContract(address(user2));
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        IFO fNFTIfo = createValidIFO();

        vm.startPrank(address(user2));
        fractionalizedNFT.transferFrom(address(fNFTIfo), address(user2), fractionalizedNFT.balanceOf(address(fNFTIfo)));
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), 0);
        assertEq(fractionalizedNFT.balanceOf(address(user2)), originalBalance);
    }

    function testFail_approveUtilityContractZeroAddress() public {
        IFO fNFTIfo = createValidIFO();

        vm.startPrank(address(user2));
        fractionalizedNFT.transferFrom(address(fNFTIfo), address(user2), fractionalizedNFT.balanceOf(address(fNFTIfo)));
        vm.stopPrank();
    }

    function testManualApproveUtilityContract() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        IFO fNFTIfo = createValidIFO();

        ifoFactory.setCreatorUtilityContract(address(user2));

        fNFTIfo.approve();

        vm.startPrank(address(user2));
        fractionalizedNFT.transferFrom(address(fNFTIfo), address(user2), fractionalizedNFT.balanceOf(address(fNFTIfo)));
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), 0);
        assertEq(fractionalizedNFT.balanceOf(address(user2)), originalBalance);
    }

    function testManualApproveUtilityContractZeroAddress() public {
        IFO fNFTIfo = createValidIFO();

        vm.expectRevert(IFO.InvalidAddress.selector);
        fNFTIfo.approve();
    }

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    function testDeposit() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        IFO fNFTIfo = createValidIFOWith3EthCap();
        uint256 originalAccountBalance = address(this).balance;
        uint256 originalUser2Balance = address(user2).balance;
        uint256 originalUser1Balance = address(user1).balance;

        ifoFactory.setFeeReceiver(payable(address(user1)));
        uint256 govFee = ifoFactory.governanceFee();
        uint256 fee = (govFee * 1 ether) / 10000;
        uint256 profit = 1 ether - fee;

        fNFTIfo.start();

        //started
        assertTrue(fNFTIfo.started());

        //start remaining allocation 3
        assertEq(fNFTIfo.getUserRemainingAllocation(address(this)), 3 ether * 1e18 / price, "this remaining allocaiton 3");
        assertEq(fNFTIfo.getUserRemainingAllocation(address(user2)), 3 ether * 1e18 / price, "user2 remaining allocaiton 3");

        //fnft balance 0 before deposit
        assertEq(fractionalizedNFT.balanceOf(address(this)), 0, "this fnft balance before deposit");
        assertEq(fractionalizedNFT.balanceOf(address(user2)), 0, "user2 fnft balance before deposit");

        //fnft balance full in ifo contract
        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalAccountFNFTBalance, "ifo fnft balance before deposit");

        fNFTIfo.deposit{value: 1 ether}();

        //fnft balance of ifo contract after this address deposit
        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalAccountFNFTBalance - (1 ether * 1e18 / price), "ifo fnft balance after this deposit");
        //profitRaised balance of ifo contract after this address deposit
        assertEq(fNFTIfo.profitRaised(), profit, "profitRaised balance after this deposit");
        //totalaRaised balance of ifo contract after this address deposit
        assertEq(fNFTIfo.totalRaised(), 1 ether, "totalRaised balance after this deposit");
        //this address remaining allocation (3 - 1)
        assertEq(fNFTIfo.getUserRemainingAllocation(address(this)), 2 ether * 1e18 / price, "this remaining allocation after deposit");
        //this address got fnft
        assertEq(fractionalizedNFT.balanceOf(address(this)), 1 ether * 1e18 / price, "this address fnft balance after deposit");
        //this balance after deposit
        assertEq(address(this).balance, originalAccountBalance - 1 ether);
        //ifo balance after deposit
        assertEq(address(fNFTIfo).balance, profit);
        //user1 balance after deposit
        assertEq(address(user1).balance, originalUser1Balance + fee);

        vm.startPrank(address(user2));
        fNFTIfo.deposit{value: 2 ether}();
        vm.stopPrank();

        //fnft balance of ifo contract after user2 address deposit (1 + 2)
        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalAccountFNFTBalance - (3 ether * 1e18 / price), "ifo fnft balance after user2 deposit");
        //profitRaised balance of ifo contract after user2 address deposit
        assertEq(fNFTIfo.profitRaised(), profit * 3, "profitRaised balance after user2 deposit");
        //totalaRaised balance of ifo contract after user2 address deposit
        assertEq(fNFTIfo.totalRaised(), 3 ether, "totalRaised balance after user2 deposit");
        //user2 address remaining allocation (3 - 2)
        assertEq(fNFTIfo.getUserRemainingAllocation(address(user2)), 1 ether * 1e18 / price, "user2 remaining allocation after deposit");
        //user2 address got fnft
        assertEq(fractionalizedNFT.balanceOf(address(user2)), 2 ether * 1e18 / price, "user2 address fnft balance after deposit");
        //this balance after deposit
        assertEq(address(user2).balance, originalUser2Balance - 2 ether);
        //ifo balance after deposit
        assertEq(address(fNFTIfo).balance, profit * 3);
        //user1 balance after deposit
        assertEq(address(user1).balance, originalUser1Balance + fee * 3);
    }

    function testDepositAfterSaleEnded() public {
        IFO fNFTIfo = createValidIFOWith3EthCap();

        fNFTIfo.start();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        fNFTIfo.end();

        vm.expectRevert(IFO.SaleAlreadyEnded.selector);
        fNFTIfo.deposit{value: 1 ether}();
    }

    function testDepositWhilePaused() public {
        IFO fNFTIfo = createValidIFOWith3EthCap();

        fNFTIfo.start();

        fNFTIfo.togglePause();

        vm.expectRevert(IFO.ContractPaused.selector);
        fNFTIfo.deposit{value: 1 ether}();
    }

    function testDepositAfterSaleResumesAfterDeadline() public {
        IFO fNFTIfo = createValidIFOWith3EthCap();

        fNFTIfo.start();

        fNFTIfo.togglePause();

        assertEq(fNFTIfo.duration(), ifoFactory.minimumDuration());

        vm.roll(fNFTIfo.startBlock() + 1000);

        assertEq(fNFTIfo.duration(), ifoFactory.minimumDuration());

        fNFTIfo.togglePause();

        assertEq(fNFTIfo.duration(), ifoFactory.minimumDuration() + 1000);

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1001);

        fNFTIfo.end();
    }

    function testDepositSaleEndAutoAfterDeadline() public {
        IFO fNFTIfo = createValidIFO();

        fNFTIfo.start();

        vm.roll(fNFTIfo.startBlock() + ifoFactory.minimumDuration() + 1);

        vm.expectRevert(IFO.SaleAlreadyEnded.selector);
        fNFTIfo.deposit{value: 1 ether}();
    }

    function testDepositBeforeSaleStarted() public {
        IFO fNFTIfo = createValidIFO();

        vm.expectRevert(IFO.SaleUnstarted.selector);
        fNFTIfo.deposit{value: 1 ether}();
    }

    function testDepositIfNotWhitelisted() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.start();

        vm.expectRevert(IFO.NotWhitelisted.selector);
        fNFTIfo.deposit{value: 1 ether}();
    }

    function testDepositAfterWhitelisted() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoFactory.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));
        fNFTIfo.addWhitelist(address(this));

        fNFTIfo.start();

        fNFTIfo.deposit{value: 1 ether}();
    }

    function testDepositMoreThanCap() public {
        IFO fNFTIfo = createValidIFOWith3EthCap();

        fNFTIfo.start();

        vm.expectRevert(IFO.OverLimit.selector);
        fNFTIfo.deposit{value: 3.1 ether}();
    }

    function testDepositMoreThanCapAfterDeposit() public {
        IFO fNFTIfo = createValidIFOWith3EthCap();

        fNFTIfo.start();

        fNFTIfo.deposit{value: 1 ether}();

        vm.expectRevert(IFO.OverLimit.selector);
        fNFTIfo.deposit{value: 2.1 ether}();
    }

    function testDepositMoreThanCapAfterMeetingDeposit() public {
        IFO fNFTIfo = createValidIFOWith3EthCap();

        fNFTIfo.start();

        fNFTIfo.deposit{value: 1 ether}();

        fNFTIfo.deposit{value: 2 ether}();

        vm.expectRevert(IFO.OverLimit.selector);
        fNFTIfo.deposit{value: 1 ether}();
    }

    function testGetUserRemainingAllocation() public {
        uint256 price = 0.01 ether;
        IFO fNFTIfo = createValidIFOWith3EthCap();

        fNFTIfo.start();

        assertEq(fNFTIfo.getUserRemainingAllocation(address(this)), 3 ether * 1e18 / price);

        fNFTIfo.deposit{value: 1 ether}();

        assertEq(fNFTIfo.getUserRemainingAllocation(address(this)), 2 ether * 1e18 / price);

        fNFTIfo.deposit{value: 2 ether}();

        assertEq(fNFTIfo.getUserRemainingAllocation(address(this)), 0);
    }

    receive() external payable {}
}