//solhint-disable func-name-mixedcase
//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IFNFTSettings, FNFTSettings} from "../contracts/FNFTSettings.sol";
import {IIFOSettings, IFOSettings} from "../contracts/IFOSettings.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";
import {PriceOracle} from "../contracts/PriceOracle.sol";
import {FNFTFactory} from "../contracts/FNFTFactory.sol";
import {IFOFactory} from "../contracts/IFOFactory.sol";
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
    FNFTSettings public fnftSettings;
    IFOSettings public ifoSettings;
    IPriceOracle public priceOracle;
    MockNFT public nft;
    FNFT public fractionalizedNFT;

    User public user1;
    User public user2;
    User public user3;
    UserNoETH public user4;

    Curator public curator;

    function setUp() public {
        setupEnvironment(10 ether);
        (, priceOracle, ifoSettings, ifoFactory, fnftSettings, fnftFactory, ) = setupContracts(10 ether);        

        fnftSettings.setGovernanceFee(0);

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
        curator = new Curator(address(fnftFactory));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fractionalizedNFT));
        user2 = new User(address(fractionalizedNFT));
        user3 = new User(address(fractionalizedNFT));
        user4 = new UserNoETH(address(fractionalizedNFT));

        payable(address(user1)).transfer(20 ether);
        payable(address(user2)).transfer(20 ether);
        payable(address(user3)).transfer(20 ether);
        payable(address(user4)).transfer(20 ether);
    }

    /// -------------------------------
    /// -------- INIT FUNCTIONS -------
    /// -------------------------------

    function testPause() public {
        ifoFactory.pause();
        ifoFactory.unpause();
    }

    function testCreateIFO() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), fractionalizedNFT.totalSupply());
        assertEq(fNFTIfo.duration(), ifoSettings.minimumDuration());        
    }

    function testFail_createIFOInvalidAddress() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(0), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFOMarketCapTooHigh() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));
        //burn 1
        fractionalizedNFT.transferFrom(address(this), address(0), 1);
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFONotEnoughSupply() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));
        //burn 1
        fractionalizedNFT.transferFrom(address(this), address(0), 1);
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFOAmountForSaleTooLow() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            0, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFOAmountForSaleTooHigh() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this))+1, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFOMarketCapHigherThanInitialReserve() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFOCapTooHigh() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply() + 1, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFOCapTooLow() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            0, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFODurationTooLow() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration() - 1, //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFODurationTooHigh() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.maximumDuration() + 1, //sale duration
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
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );        
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        vm.stopPrank();

        fNFTIfo.updateFNFTAddress(address(user2));

        assertEq(address(fNFTIfo.fnft()), address(user2));
    }

    function testFail_updateFNFTAddresZeroAddress() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.updateFNFTAddress(address(0));
    }

    function testFail_updateFNFTAddressNotGov() public {           
        fractionalizedNFT.approve(address(this), fractionalizedNFT.balanceOf(address(this)));
        fractionalizedNFT.transferFrom(address(this), address(user1), fractionalizedNFT.balanceOf(address(this)));

        vm.startPrank(address(user1));

        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(user1)));

        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(user1)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.updateFNFTAddress(address(user1));

        vm.stopPrank();        
    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    function testAddWhitelist() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.addWhitelist(address(user1));

        assertEq(fNFTIfo.whitelisted(address(user1)) ? 1 : 0, true ? 1 : 0);
    }

    function testFail_addWhitelistNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        vm.startPrank(address(user1));

        fNFTIfo.addWhitelist(address(user1));

        vm.stopPrank();
    }

    function testFail_addWhitelistWhitelistNotAllowed() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.addWhitelist(address(user1));
    }

    function testAddMultipleWhitelist() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(user1);
        whitelists[1] = address(user2);
        whitelists[2] = address(user3);
        fNFTIfo.addMultipleWhitelists(whitelists);

        assertEq(fNFTIfo.whitelisted(address(user1)) ? 1 : 0, true ? 1 : 0);
        assertEq(fNFTIfo.whitelisted(address(user2)) ? 1 : 0, true ? 1 : 0);
        assertEq(fNFTIfo.whitelisted(address(user3)) ? 1 : 0, true ? 1 : 0);
    }

    function testFail_addMultipleWhitelistNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(user1);
        whitelists[1] = address(user2);
        whitelists[2] = address(user3);

        vm.startPrank(address(user1));

        fNFTIfo.addMultipleWhitelists(whitelists);

        vm.stopPrank();
    }

    function testFail_addMultipleWhitelistWhitelistNotAllowed() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(user1);
        whitelists[1] = address(user2);
        whitelists[2] = address(user3);

        fNFTIfo.addMultipleWhitelists(whitelists);
    }

    function testRemoveWhitelist() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.addWhitelist(address(user1));

        assertEq(fNFTIfo.whitelisted(address(user1)) ? 1 : 0, true ? 1 : 0);

        fNFTIfo.removeWhitelist(address(user1));

        assertEq(fNFTIfo.whitelisted(address(user1)) ? 1 : 0, false ? 1 : 0);
    }

    function testFail_removeWhitelistNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.addWhitelist(address(user1));

        assertEq(fNFTIfo.whitelisted(address(user1)) ? 1 : 0, true ? 1 : 0);

        vm.startPrank(address(user1));

        fNFTIfo.removeWhitelist(address(user1));

        vm.stopPrank();
    }

    function testStart() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);
    }    

    function testFail_startNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);

        vm.startPrank(address(user1));

        fNFTIfo.start();

        vm.stopPrank();
    }

    function testFail_startAlreadyStarted() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        fNFTIfo.start();        
    }

    function testFail_startAlreadyEnded() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();

        assertEq(fNFTIfo.ended() ? 1 : 0, true ? 1 : 0);        

        fNFTIfo.start();
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
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );

        IFO fNFTIfo = new IFO(address(new BeaconProxy(address(new IFO(address(ifoSettings))), _initializationCalldata)));

        fNFTIfo.start();
    }

    function testEnd() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();
    }

    function testFail_endNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        vm.startPrank(address(user1));

        fNFTIfo.end();

        vm.stopPrank();
    }

    function testFail_endWhilePaused() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        fNFTIfo.togglePause();

        assertEq(fNFTIfo.paused() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();
    }

    function testFail_endBeforeStart() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));     

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);   

        fNFTIfo.end();
    }

    function testFail_endBeforDuration() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();        

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration());

        fNFTIfo.end();

    }

    function testFail_endAfterEnd() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();        

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);   

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();

        assertEq(fNFTIfo.ended() ? 1 : 0, true ? 1 : 0);   

        fNFTIfo.end();
    }

    function testFail_endBeforeMinimumDurationForInfiniteDuration() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            0, //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();        

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);   

        fNFTIfo.end();
    }

    function testEndAfterMinimumDurationForInfiniteDuration() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            0, //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();        

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);   

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();
    }

    function testTogglePause() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();        

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + 1000);

        assertEq(block.number, fNFTIfo.startBlock() + 1000);

        fNFTIfo.togglePause();

        assertEq(fNFTIfo.paused() ? 1 : 0, true ? 1 : 0);

        assertEq(fNFTIfo.duration(), ifoSettings.minimumDuration());

        vm.roll(fNFTIfo.pauseBlock() + 1000);

        fNFTIfo.togglePause();

        assertEq(fNFTIfo.paused() ? 1 : 0, false ? 1 : 0);

        assertEq(fNFTIfo.duration(), ifoSettings.minimumDuration() + 1000);        
    }

    function testFail_togglePauseWhenNotStarted() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.togglePause();
    }

    function testFail_togglePauseAfterEnded() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();        

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();

        fNFTIfo.togglePause();
    }

    function testFail_togglePauseNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();        

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        vm.startPrank(address(user1));

        fNFTIfo.togglePause();

        vm.stopPrank();
    }

    function testWithdrawProfit() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        
        uint256 originalAccountBalance = address(this).balance;
        uint256 originalUser2Balance = address(user2).balance;

        ifoSettings.setFeeReceiver(payable(address(user1)));
        uint256 govFee = ifoSettings.governanceFee();
        uint256 fee = (govFee * 1 ether) / 1000;
        uint256 profit = 1 ether - fee;

        fNFTIfo.start();        

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);     

        fNFTIfo.deposit{value: 1 ether}();

        vm.startPrank(address(user2));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fNFTIfo.profitRaised(), profit * 2);

        assertEq(address(fNFTIfo).balance, profit * 2);

        assertEq(address(this).balance, originalAccountBalance - 1 ether);

        assertEq(address(user2).balance, originalUser2Balance - 1 ether);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();

        fNFTIfo.adminWithdrawProfit();

        assertEq(fNFTIfo.profitRaised(), 0);

        assertEq(address(fNFTIfo).balance, 0);

        assertEq(address(user2).balance, originalUser2Balance - 1 ether);

        assertEq(address(this).balance, originalAccountBalance - 1 ether + profit * 2);
    }

    function testFail_withdrawProfitNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));                

        ifoSettings.setFeeReceiver(payable(address(user1)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);     

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();

        vm.startPrank(address(user2));
        fNFTIfo.adminWithdrawProfit();
        vm.stopPrank();
    }

    function testWithdrawProfitAutoEndsAfterDuration() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));                

        ifoSettings.setFeeReceiver(payable(address(user1)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);     

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);
        
        fNFTIfo.adminWithdrawProfit();
    }

    function testFail_withdrawProfitBeforeEnd() public {
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

        ifoSettings.setFeeReceiver(payable(address(user1)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);     

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);
        
        fNFTIfo.adminWithdrawProfit();
    }

    function testFail_withdrawProfitTwice() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));                

        ifoSettings.setFeeReceiver(payable(address(user1)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);     

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);
        
        fNFTIfo.adminWithdrawProfit();

        fNFTIfo.adminWithdrawProfit();
    }

    function testWithdrawFNFT() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), originalBalance);                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalBalance, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);    

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0); 

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();

        fNFTIfo.adminWithdrawFNFT();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), 0);      

        assertEq(fractionalizedNFT.balanceOf(address(this)), originalBalance - (1 ether * 1e18 / 0.01 ether));
    }

    function testFail_withdrawFNFTWhileSaleActive() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), originalBalance);                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalBalance, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);    

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0); 

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        fNFTIfo.adminWithdrawFNFT();
    }

    function testWithdrawFNFTAutoEndsAfterDuration() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), originalBalance);                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalBalance, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);    

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0); 

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.adminWithdrawFNFT();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), 0);      

        assertEq(fractionalizedNFT.balanceOf(address(this)), originalBalance - (1 ether * 1e18 / 0.01 ether));
    }

    function testWithdrawFNFTIfLockedAndRedeemed() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), originalBalance);                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalBalance, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));
        ifoSettings.setCreatorIFOLock(true);

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);    

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0); 

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

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

    function testFail_WithdrawFNFTIfLockedAndNotRedeemed() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), originalBalance);                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalBalance, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));
        ifoSettings.setCreatorIFOLock(true);
        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);    

        assertEq(fractionalizedNFT.balanceOf(address(this)), 0); 

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance);

        vm.startPrank(address(user1));
        fNFTIfo.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), originalBalance - (1 ether * 1e18 / 0.01 ether));

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();

        fNFTIfo.adminWithdrawFNFT();
    }

    function testApproveUtilityContract() public {
        ifoSettings.setCreatorUtilityContract(address(user2));
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), originalBalance);                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalBalance, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        vm.startPrank(address(user2));        
        fractionalizedNFT.transferFrom(address(fNFTIfo), address(user2), fractionalizedNFT.balanceOf(address(fNFTIfo)));
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), 0);
        assertEq(fractionalizedNFT.balanceOf(address(user2)), originalBalance);
    }

    function testFail_approveUtilityContractZeroAddress() public {
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), originalBalance);                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalBalance, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        vm.startPrank(address(user2));        
        fractionalizedNFT.transferFrom(address(fNFTIfo), address(user2), fractionalizedNFT.balanceOf(address(fNFTIfo)));
        vm.stopPrank();        
    }

    function testManualApproveUtilityContract() public {        
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), originalBalance);                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalBalance, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        ifoSettings.setCreatorUtilityContract(address(user2));

        fNFTIfo.approve();

        vm.startPrank(address(user2));        
        fractionalizedNFT.transferFrom(address(fNFTIfo), address(user2), fractionalizedNFT.balanceOf(address(fNFTIfo)));
        vm.stopPrank();

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), 0);
        assertEq(fractionalizedNFT.balanceOf(address(user2)), originalBalance);
    }

    function testFail_manualApproveUtilityContractZeroAddress() public {        
        uint originalBalance = fractionalizedNFT.balanceOf(address(this));
        fractionalizedNFT.approve(address(ifoFactory), originalBalance);                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalBalance, //amountForSale
            0.01 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.approve();
    }

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    function testDeposit() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        
        uint256 originalAccountBalance = address(this).balance;
        uint256 originalUser2Balance = address(user2).balance;
        uint256 originalUser1Balance = address(user1).balance;

        ifoSettings.setFeeReceiver(payable(address(user1)));
        uint256 govFee = ifoSettings.governanceFee();
        uint256 fee = (govFee * 1 ether) / 1000;
        uint256 profit = 1 ether - fee;

        fNFTIfo.start();        

        //started
        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0, "started");     

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

    function testFail_depositAfterSaleEnded() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.start();        

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.end();

        fNFTIfo.deposit{value: 1 ether}();
    }

    function testFail_depositWhilePaused() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));   

        fNFTIfo.start();        

        fNFTIfo.togglePause();     

        fNFTIfo.deposit{value: 1 ether}();
    }

    function testDepositAfterSaleResumesAfterDeadline() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));   

        fNFTIfo.start();        

        fNFTIfo.togglePause();     

        assertEq(fNFTIfo.duration(), ifoSettings.minimumDuration());

        vm.roll(fNFTIfo.startBlock() + 1000);

        assertEq(fNFTIfo.duration(), ifoSettings.minimumDuration());

        fNFTIfo.togglePause();     

        assertEq(fNFTIfo.duration(), ifoSettings.minimumDuration() + 1000);

        fNFTIfo.deposit{value: 1 ether}();

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1001);

        fNFTIfo.end();
    }

    function testFail_depositSaleEndAutoAfterDeadline() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));   

        fNFTIfo.start();        

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration() + 1);

        fNFTIfo.deposit{value: 1 ether}();
    }

    function testFail_depositBeforeSaleStarted() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.deposit{value: 1 ether}();
    }

    function testFail_depositIfNotWhitelisted() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));   

        fNFTIfo.start();        

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
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));   
        fNFTIfo.addWhitelist(address(this));

        fNFTIfo.start();

        fNFTIfo.deposit{value: 1 ether}();
    }

    function testFail_depositMoreThanCap() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));           

        fNFTIfo.start();

        fNFTIfo.deposit{value: 3.1 ether}();
    }

    function testFail_depositMoreThanCapAfterDeposit() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));           

        fNFTIfo.start();

        fNFTIfo.deposit{value: 1 ether}();

        fNFTIfo.deposit{value: 2.1 ether}();
    }

    function testFail_depositMoreThanCapAfterMeetingDeposit() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));           

        fNFTIfo.start();

        fNFTIfo.deposit{value: 1 ether}();

        fNFTIfo.deposit{value: 2 ether}();

        fNFTIfo.deposit{value: 1 ether}();
    }

    function testGetUserRemainingAllocation() public {
        uint256 originalAccountFNFTBalance = fractionalizedNFT.balanceOf(address(this));
        uint256 price = 0.01 ether;
        fractionalizedNFT.approve(address(ifoFactory), originalAccountFNFTBalance);
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            originalAccountFNFTBalance, //amountForSale
            price, //price per token
            3 ether * 1e18 / price, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));           

        fNFTIfo.start();

        assertEq(fNFTIfo.getUserRemainingAllocation(address(this)), 3 ether * 1e18 / price); 

        fNFTIfo.deposit{value: 1 ether}();

        assertEq(fNFTIfo.getUserRemainingAllocation(address(this)), 2 ether * 1e18 / price); 

        fNFTIfo.deposit{value: 2 ether}();

        assertEq(fNFTIfo.getUserRemainingAllocation(address(this)), 0); 
    }

    receive() external payable {}
}
