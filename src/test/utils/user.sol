//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {FNFTFactory, ERC721Holder} from "../../contracts/FNFTFactory.sol";
import {FNFT} from "../../contracts/FNFT.sol";
import {MockNFT} from "../../contracts/mocks/NFT.sol";
import {WETH} from "../../contracts/mocks/WETH.sol";
import {console} from "../utils/console.sol";
import {CheatCodes} from "../utils/cheatcodes.sol";

contract User is ERC721Holder {
    FNFT public fnft;

    constructor(address _fnft) {
        fnft = FNFT(_fnft);
    }

    function call_transfer(address _guy, uint256 _amount) public {
        fnft.transfer(_guy, _amount);
    }

    function call_updatePrice(uint256 _price) public {
        fnft.updateUserPrice(_price);
    }

    function call_bid(uint256 _amount) public {
        fnft.bid{value: _amount}();
    }

    function call_start(uint256 _amount) public {
        fnft.start{value: _amount}();
    }

    function call_cash() public {
        fnft.cash();
    }

    function call_remove(address _user) public {
        fnft.removeReserve(_user);
    }

    // to be able to receive funds
    receive() external payable {} // solhint-disable-line no-empty-blocks
}

contract UserNoETH is ERC721Holder {
    bool public canReceive = true;

    FNFT public fnft;

    constructor(address _fnft) {
        fnft = FNFT(_fnft);
    }

    function call_transfer(address _guy, uint256 _amount) public {
        fnft.transfer(_guy, _amount);
    }

    function call_updatePrice(uint256 _price) public {
        fnft.updateUserPrice(_price);
    }

    function call_bid(uint256 _amount) public {
        fnft.bid{value: _amount}();
    }

    function call_start(uint256 _amount) public {
        fnft.start{value: _amount}();
    }

    function call_cash() public {
        fnft.cash();
    }

    function setCanReceive(bool _can) public {
        canReceive = _can;
    }

    // to be able to receive funds
    receive() external payable {
        require(canReceive, "cannot receive ETH");
    } // solhint-disable-line no-empty-blocks
}

contract Curator {
    FNFT public fnft;

    constructor(address _fnft) {
        fnft = FNFT(_fnft);
    }

    function call_updateCurator(address _who) public {
        fnft.updateCurator(_who);
    }

    function call_kickCurator(address _who) public {
        fnft.kickCurator(_who);
    }

    // to be able to receive funds
    receive() external payable {} // solhint-disable-line no-empty-blocks
}
