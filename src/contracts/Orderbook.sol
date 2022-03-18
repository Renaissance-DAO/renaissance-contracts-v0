// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./ifo.sol";

contract Orderbook {
    using SafeERC20 for IERC20;

    event BuyOrderPosted(uint _oid,  address _host, uint _amount, uint _price);
    event SellOrderPosted(uint _oid,  address _host, uint _amount, uint _price);
    event BuyOrderEdited(uint _oid,  address _host, uint _newAmount, uint _newPrice);
    event SellOrderEdited(uint _oid,  address _host, uint _newAmount, uint _newPrice);
    event BuyOrderRemoved(uint _oid, address _host);
    event SellOrderRemoved(uint _oid, address _host);
    event BuyOrderFulfilled(uint _oid, address _buyer, address _seller, uint _amount);
    event SellOrderFulfilled(uint _oid, address _buyer, address _seller, uint _amount);

    error EthAmountDifferent();   
    error NotEnoughFNFT();

    enum OrderType {
        buy,
        sell
    }

    struct Order {        
        OrderType orderType;
        address host;
        uint256 amount;
        uint256 price;
        uint256 remaining;
        uint256 blockNumber;
    }

    IERC20 public fNFT;
    Order[] public orders;
    mapping(address => uint256) public totalEthInEscrow;
    mapping(address => uint256) public totalFNFTInEscrow;

    constructor(address _fNFT) {
        fNFT = IERC20(_fNFT);
    }

    function postBuyOrder(uint _amount, uint _price) external payable {
        if (_amount * _price != msg.value) revert EthAmountDifferent();
        
        orders.push(Order(OrderType.buy, msg.sender, _amount, _price, _amount, block.number));
        totalEthInEscrow[msg.sender] += msg.value;

        emit BuyOrderPosted(orders.length - 1, msg.sender, _amount, _price);
    }

    function postSellOrder(uint _amount, uint _price) external {
        if (_amount > fNFT.balanceOf(msg.sender)) revert NotEnoughFNFT();

        orders.push(Order(OrderType.sell, msg.sender, _amount, _price, _amount, block.number));
        totalFNFTInEscrow[msg.sender] += _amount;

        fNFT.transferFrom(msg.sender, address(this), _amount);

        emit SellOrderPosted(orders.length - 1, msg.sender, _amount, _price);
    }

    function editBuyOrder(uint _oid, uint _newAmount, uint _newPrice) external payable {

    }

    function editSellOrder(uint _oid, uint _newAmount, uint _newPrice) external {

    }

    function removeBuyOrder(uint _oid) external {
        
    }

    function removeSellOrder(uint _oid) external {

    }

    function buy(uint _oid) external payable {

    }

    function sell(uint _oid, uint _amount) external payable {

    }
}