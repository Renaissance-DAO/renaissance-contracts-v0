//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import {FNFTSingleFactory} from "../../contracts/FNFTSingleFactory.sol";
import {FNFTSingle} from "../../contracts/FNFTSingle.sol";
import {MockNFT} from "../../contracts/mocks/NFT.sol";
import {WETH} from "../../contracts/mocks/WETH.sol";
import {console} from "../utils/console.sol";
import {CheatCodes} from "../utils/cheatcodes.sol";

contract User is ERC721Holder {
    FNFTSingle public fnftSingle;

    constructor(address _fnft) {
        fnftSingle = FNFTSingle(_fnft);
    }

    function call_transfer(address _guy, uint256 _amount) public {
        fnftSingle.transfer(_guy, _amount);
    }

    function call_updatePrice(uint256 _price) public {
        fnftSingle.updateUserPrice(_price);
    }

    function call_bid(uint256 _amount) public {
        fnftSingle.bid{value: _amount}();
    }

    function call_start(uint256 _amount) public {
        fnftSingle.start{value: _amount}();
    }

    function call_cash() public {
        fnftSingle.cash();
    }

    function call_remove(address _user) public {
        fnftSingle.removeReserve(_user);
    }

    // to be able to receive funds
    receive() external payable {} // solhint-disable-line no-empty-blocks
}

contract UserNoETH is ERC721Holder {
    bool public canReceive = true;

    FNFTSingle public fnftSingle;

    constructor(address _fnft) {
        fnftSingle = FNFTSingle(_fnft);
    }

    function call_transfer(address _guy, uint256 _amount) public {
        fnftSingle.transfer(_guy, _amount);
    }

    function call_updatePrice(uint256 _price) public {
        fnftSingle.updateUserPrice(_price);
    }

    function call_bid(uint256 _amount) public {
        fnftSingle.bid{value: _amount}();
    }

    function call_start(uint256 _amount) public {
        fnftSingle.start{value: _amount}();
    }

    function call_cash() public {
        fnftSingle.cash();
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
    FNFTSingle public fnftSingle;

    constructor(address _fnft) {
        fnftSingle = FNFTSingle(_fnft);
    }

    function call_updateCurator(address _who) public {
        fnftSingle.updateCurator(_who);
    }

    function call_kickCurator(address _who) public {
        fnftSingle.kickCurator(_who);
    }

    // to be able to receive funds
    receive() external payable {} // solhint-disable-line no-empty-blocks
}
