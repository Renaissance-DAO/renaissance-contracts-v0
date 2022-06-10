//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/IFNFTFactory.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IIFOFactory.sol";
import "./interfaces/IIFO.sol";
import "./libraries/UniswapV2Library.sol";
import "./interfaces/IFeeDistributor.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC3156FlashBorrowerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IPriceOracle} from "./PriceOracle.sol";
import "./token/ERC20FlashMintUpgradeable.sol";

contract FNFT is ERC20FlashMintUpgradeable, ERC721HolderUpgradeable {
    using Address for address;

    /// -----------------------------------
    /// -------- TOKEN INFORMATION --------
    /// -----------------------------------

    /// @notice the ERC721 token address of the vault's token
    address public token;

    /// @notice the ERC721 token ID of the vault's token
    uint256 public id;

    /// -------------------------------------
    /// -------- AUCTION INFORMATION --------
    /// -------------------------------------

    /// @notice the unix timestamp end time of the token auction
    uint256 public auctionEnd;

    /// @notice the length of auctions
    uint256 public auctionLength;

    /// @notice reservePrice * votingTokens
    uint256 public reserveTotal;

    /// @notice the current price of the token during an auction
    uint256 public livePrice;

    /// @notice the current user winning the token auction
    address payable public winning;

    enum State {
        Inactive,
        Live,
        Ended,
        Redeemed
    }

    State public auctionState;

    /// -----------------------------------
    /// -------- VAULT INFORMATION --------
    /// -----------------------------------

    /// @notice the governance contract which gets paid in ETH
    address public factory;

    /// @notice whether or not this FNFT has been verified by DAO
    bool public verified;

    /// @notice the address who initially deposited the NFT
    address public curator;

    /// @notice the AUM fee paid to the curator yearly. 3 decimals. ie. 100 = 10%
    uint256 public fee;

    /// @notice the last timestamp where fees were claimed
    uint256 public lastClaimed;

    /// @notice the number of ownership tokens voting on the reserve price at any given time
    uint256 public votingTokens;

    /// @notice initial price of NFT set by curator on creation
    uint256 public initialReserve;

    /// @notice a mapping of users to their desired token price
    mapping(address => uint256) public userReservePrice;

    /// ------------------------
    /// -------- EVENTS --------
    /// ------------------------

    /// @notice An event emitted when a user updates their price
    event PriceUpdate(address indexed user, uint256 price);

    /// @notice An event emitted when an auction starts
    event Start(address indexed buyer, uint256 price);

    /// @notice An event emitted when a bid is made
    event Bid(address indexed buyer, uint256 price);

    /// @notice An event emitted when an auction is won
    event Won(address indexed buyer, uint256 price);

    /// @notice An event emitted when someone redeems all tokens for the NFT
    event Redeem(address indexed redeemer);

    /// @notice An event emitted when someone cashes in ERC20 tokens for ETH from an ERC721 token sale
    event Cash(address indexed owner, uint256 shares);

    event UpdateAuctionLength(uint256 length);

    event UpdateCuratorFee(uint256 fee);

    event FeeClaimed(uint256 fee);

    event Verified(bool verified);

    event KickCurator(address indexed oldCurator, address indexed newCurator);
    event UpdateCurator(address indexed oldCurator, address indexed newCurator);

    error NotGov();
    error NotCurator();
    error SameCurator();
    error AuctionLive();
    error NotAnUpdate();
    error InvalidAuctionLength();
    error CanNotRaise();
    error FeeTooHigh();
    error AuctionEnded();
    error AuctionNotEnded();
    error NotEnoughETH();
    error PriceTooLow();
    error PriceTooHigh();
    error BidTooLow();
    error NotEnoughVoters();
    error AuctionNotLive();
    error NoTokens();
    error WrongToken();

    function initialize(
        address _curator,
        address _token,
        uint256 _id,
        uint256 _supply,
        uint256 _listPrice,
        uint256 _fee,
        string memory _name,
        string memory _symbol
    ) external initializer {
        // initialize inherited contracts
        __ERC20_init(_name, _symbol);
        __ERC721Holder_init();

        if (_fee > IFNFTFactory(msg.sender).maxCuratorFee()) revert FeeTooHigh();

        // set storage variables
        factory = msg.sender;
        token = _token;
        id = _id;
        auctionLength = 3 days;
        curator = _curator;
        fee = _fee;
        lastClaimed = block.timestamp;
        userReservePrice[_curator] = _listPrice;
        initialReserve = _listPrice;

        _mint(_curator, _supply);
    }

    modifier onlyCurator() {
        if (msg.sender != curator) revert NotCurator();
        _;
    }

    modifier onlyGov() {
        if (msg.sender != OwnableUpgradeable(factory).owner()) revert NotGov();
        _;
    }

    /// --------------------------------
    /// -------- VIEW FUNCTIONS --------
    /// --------------------------------

    function reservePrice() public view returns (uint256) {
        return votingTokens == 0 ? 0 : reserveTotal / votingTokens;
    }

    /// -------------------------------
    /// -------- GOV FUNCTIONS --------
    /// -------------------------------

    /// @notice allow governance to boot a bad actor curator
    /// @param _curator the new curator
    function kickCurator(address _curator) external onlyGov {
        if (curator == _curator) revert SameCurator();
        emit KickCurator(curator, _curator);
        curator = _curator;
    }

    /// @notice allow governance to remove bad reserve prices
    function removeReserve(address _user) external onlyGov {
        if (auctionState != State.Inactive) revert AuctionLive();

        uint256 old = userReservePrice[_user];
        if (old == 0) revert NotAnUpdate();

        uint256 weight = balanceOf(_user);

        votingTokens -= weight;
        reserveTotal -= weight * old;

        userReservePrice[_user] = 0;

        emit PriceUpdate(_user, 0);
    }

    function toggleVerified() external onlyGov {
        bool _verified = !verified;
        verified = _verified;
        emit Verified(_verified);
    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    /// @notice allow curator to update the curator address
    /// @param _curator the new curator
    function updateCurator(address _curator) external onlyCurator {
        if (curator == _curator) revert SameCurator();
        emit UpdateCurator(curator, _curator);
        curator = _curator;
    }

    /// @notice allow curator to update the auction length
    /// @param _length the new base price
    function updateAuctionLength(uint256 _length) external onlyCurator {
        if (
            _length < IFNFTFactory(factory).minAuctionLength() || _length > IFNFTFactory(factory).maxAuctionLength()
        ) revert InvalidAuctionLength();

        auctionLength = _length;
        emit UpdateAuctionLength(_length);
    }

    /// @notice allow the curator to change their fee
    /// @param _fee the new fee
    function updateFee(uint256 _fee) external onlyCurator {
        if (_fee >= fee) revert CanNotRaise();
        if (_fee > IFNFTFactory(factory).maxCuratorFee()) revert FeeTooHigh();

        _claimFees();

        fee = _fee;
        emit UpdateCuratorFee(fee);
    }

    /// @notice external function to claim fees for the curator and governance
    function claimFees() external {
        _claimFees();
    }

    /// @dev interal fuction to calculate and mint fees
    function _claimFees() internal {
        if (auctionState == State.Ended) revert AuctionEnded();

        // get how much in fees the curator would make in a year
        uint256 currentAnnualFee = (fee * totalSupply()) / 10000;
        // get how much that is per second;
        uint256 feePerSecond = currentAnnualFee / 31536000;
        // get how many seconds they are eligible to claim
        uint256 sinceLastClaim = block.timestamp - lastClaimed;
        // get the amount of tokens to mint
        uint256 curatorMint = sinceLastClaim * feePerSecond;

        // now lets do the same for governance
        address govAddress = IFNFTFactory(factory).feeReceiver();
        uint256 govFee = IFNFTFactory(factory).governanceFee();
        currentAnnualFee = (govFee * totalSupply()) / 10000;
        feePerSecond = currentAnnualFee / 31536000;
        uint256 govMint = sinceLastClaim * feePerSecond;

        lastClaimed = block.timestamp;

        if (curator != address(0)) {
            _mint(curator, curatorMint);
            emit FeeClaimed(curatorMint);
        }
        if (govAddress != address(0)) {
            _mint(govAddress, govMint);
            emit FeeClaimed(govMint);
        }
    }

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    function getAuctionPrice() external view returns (uint256) {
        return _getAuctionPrice();
    }

    function buyItNow() external payable {
        if (auctionState != State.Inactive) revert AuctionLive();
        uint256 price = buyItNowPrice();
        if (price == 0) revert PriceTooLow();
        if (msg.value < price) revert NotEnoughETH();

        _claimFees();

        // deposit weth
        IWETH(IFNFTFactory(factory).WETH()).deposit{value: msg.value}();

        // transfer erc721 to buyer
        IERC721(token).transferFrom(address(this), msg.sender, id);

        auctionState = State.Ended;

        emit Won(msg.sender, price);
    }

    function buyItNowPrice() public view returns (uint256) {
        return (_getAuctionPrice() * IFNFTFactory(factory).instantBuyMultiplier()) / 10;
    }

    /// @notice a function for an end user to update their desired sale price
    /// @param newUserReserve the desired price in ETH
    function updateUserPrice(uint256 newUserReserve) external {
        if (auctionState != State.Inactive) revert AuctionLive();
        uint256 previousUserReserve = userReservePrice[msg.sender];
        if (newUserReserve == previousUserReserve) revert NotAnUpdate();

        uint256 weight = balanceOf(msg.sender);

        if (votingTokens == 0) {
            _validateUserPrice(initialReserve, newUserReserve);

            votingTokens = weight;
            reserveTotal = weight * newUserReserve;
        }
        // they are the only one voting
        else if (weight == votingTokens && previousUserReserve != 0) {
            _validateUserPrice(previousUserReserve, newUserReserve);

            reserveTotal = weight * newUserReserve;
        }
        // previously they were not voting
        else if (previousUserReserve == 0) {
            uint256 averageReserve = reserveTotal / votingTokens;

            _validateUserPrice(averageReserve, newUserReserve);

            votingTokens += weight;
            reserveTotal += weight * newUserReserve;
        }
        // they no longer want to vote
        else if (newUserReserve == 0) {
            votingTokens -= weight;
            reserveTotal -= weight * previousUserReserve;
        }
        // they are updating their vote
        else {
            uint256 averageReserve = (reserveTotal - (previousUserReserve * weight)) / (votingTokens - weight);

            _validateUserPrice(averageReserve, newUserReserve);

            reserveTotal = reserveTotal + (weight * newUserReserve) - (weight * previousUserReserve);
        }

        userReservePrice[msg.sender] = newUserReserve;

        emit PriceUpdate(msg.sender, newUserReserve);
    }

    function getQuorum() external view returns (uint256) {
        return _getQuorum();
    }

    function _getQuorum() internal view returns (uint256) {
        IIFO ifo = IIFO(IIFOFactory(IFNFTFactory(factory).ifoFactory()).getIFO(address(this)));
        if (address(ifo) != address(0) && ifo.ended() && ifo.fnftLocked()) {
            return votingTokens * 10000 / (totalSupply() - ifo.lockedSupply());
        } else {
            return votingTokens * 10000 / totalSupply();
        }
    }

    function _getAuctionPrice() internal view returns (uint256) {
        address priceOracle = IFNFTFactory(factory).priceOracle();
        bool aboveQuorum = _getQuorum() > IFNFTFactory(factory).minVotePercentage();
        uint256 _reservePrice = reservePrice();

        if (address(priceOracle) != address(0)) {
            address weth = IFNFTFactory(factory).WETH();
            IUniswapV2Pair pair = IUniswapV2Pair(IPriceOracle(priceOracle).getPairAddress(address(this), weth));
            uint256 reserve1;
            uint256 twapPrice;
            if (IPriceOracle(priceOracle).getPairInfo(address(pair)).exists) {
                (, reserve1) = UniswapV2Library.getReserves(pair.factory(), address(this), weth);
                twapPrice = _getTWAP();
            }

            bool aboveLiquidityThreshold = reserve1 * 2 > IFNFTFactory(factory).liquidityThreshold();

            if (aboveLiquidityThreshold) {
                if (aboveQuorum) {
                    //twap price if twap > reserve
                    //reserve price if twap < reserve
                    return twapPrice > _reservePrice ? twapPrice : _reservePrice;
                } else {
                    //twap price if twap > initial reserve
                    //reserve price if twap < initial reserve
                    return twapPrice > initialReserve ? twapPrice : initialReserve;
                }
            } else {
                if (aboveQuorum) {
                    //average reserve
                    return _reservePrice;
                } else {
                    //initial reserve
                    return initialReserve;
                }
            }
        } else {
            return aboveQuorum ? _reservePrice : initialReserve;
        }
    }

    function _getTWAP() internal view returns (uint256) {
        try IPriceOracle(IFNFTFactory(factory).priceOracle()).getfNFTPriceETH(address(this), totalSupply()) returns (uint256 twapPrice) {
            return twapPrice;
        } catch {
            return 0;
        }
    }

    /// @notice makes sure that the new price does not impact the reserve drastically
    function _validateUserPrice(uint256 prevUserReserve, uint256 newUserReserve) private view {
        uint256 reservePriceMin = (prevUserReserve * IFNFTFactory(factory).minReserveFactor()) / 10000;
        if (newUserReserve < reservePriceMin) revert PriceTooLow();
        uint256 reservePriceMax = (prevUserReserve * IFNFTFactory(factory).maxReserveFactor()) / 10000;
        if (newUserReserve > reservePriceMax) revert PriceTooHigh();
    }

    /// @notice an internal function used to update sender and receivers price on token transfer
    /// @param _from the ERC20 token sender
    /// @param _to the ERC20 token receiver
    /// @param _amount the ERC20 token amount
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override {
        if (auctionState == State.Inactive) {
            uint256 sendersReservePrice = userReservePrice[_from];
            uint256 receiversReservePrice = userReservePrice[_to];
            // only do something if users have different reserve price
            if (receiversReservePrice != sendersReservePrice) {
                // Receiver has not voted on a reserve price
                // NOTE: the sender address could have voted or not
                if (receiversReservePrice == 0) {
                    // subtract the total amount of tokens voting on what the reserve price should be
                    // NOTE: there would never be a situation where the sender has not voted, because all the tokens are minted to the curator on init,
                    //     _and_ the curator's votes are initially set at the list price
                    votingTokens -= _amount;
                    // subtract the avg reserve price by the amount of tokens the
                    reserveTotal -= _amount * sendersReservePrice;
                }
                // the new holder is a voter (implied from the `else`) _and_ old holder is not a voter
                else if (sendersReservePrice == 0) {
                    // since the new holder is a voter: add the tokens being sent to the amount of tokens currently voting
                    votingTokens += _amount;
                    // _and_ since they are a voter:
                    // multiply the amount of tokens they're receiving by their previously set reserve price, since they have specified their reservePrice already
                    reserveTotal += _amount * receiversReservePrice;
                }
                // both holders are voters
                else {
                    // set the new reserve price to the previous reserve price, plus the difference between the receivers reserve and the senders reserve (NOTE: could be negative)
                    // - edge cases:
                    //      - the sender and receiver are the only voters and they have the same vote ✅
                    //      - the sender and receiver are the only voters but the receivers reserve is higher than the senders reserve ✅
                    reserveTotal = reserveTotal + (_amount * receiversReservePrice) - (_amount * sendersReservePrice);
                }
            }
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        //Take fee here
        uint256 swapFee = IFNFTFactory(factory).swapFee();
        if (swapFee > 0) {
            address priceOracle = IFNFTFactory(factory).priceOracle();
            IWETH weth = IWETH(IFNFTFactory(factory).WETH());
            IUniswapV2Pair pair = IUniswapV2Pair(IPriceOracle(priceOracle).getPairAddress(address(this), weth));

            if (to == pair) {
                address feeDistributor = IFNFTFactory(factory).feeDistributor();
                uint256 feeAmount = amount * swapFee / 10000;

                super._transfer(from, feeDistributor, feeAmount);
                // IFeeDistributor(feeDistributor).distribute(vaultId);

                amount = amount - feeAmount;
            }
        }

        super._transfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address,
        address,
        uint256
    ) internal virtual override {
        address priceOracle = IFNFTFactory(factory).priceOracle();
        if (priceOracle != address(0)) {
            IPriceOracle(priceOracle).updatefNFTPairInfo(address(this));
        }
    }

    /// @notice kick off an auction. Must send reservePrice in ETH
    function start() external payable {
        if (auctionState != State.Inactive) revert AuctionLive();
        uint256 _auctionPrice = _getAuctionPrice();
        if (_auctionPrice == 0 || msg.value < _auctionPrice) revert BidTooLow();

        auctionEnd = block.timestamp + auctionLength;
        auctionState = State.Live;

        livePrice = msg.value;
        winning = payable(msg.sender);

        emit Start(msg.sender, msg.value);
    }

    /// @notice an external function to bid on purchasing the vaults NFT. The msg.value is the bid amount
    function bid() external payable {
        if (auctionState != State.Live) revert AuctionNotLive();
        uint256 increase = IFNFTFactory(factory).minBidIncrease() + 10000;
        if (msg.value * 10000 < livePrice * increase) revert BidTooLow();
        if (block.timestamp >= auctionEnd) revert AuctionEnded();

        // If bid is within 15 minutes of auction end, extend auction
        if (auctionEnd - block.timestamp <= 15 minutes) {
            auctionEnd += 15 minutes;
        }

        _sendETHOrWETH(winning, livePrice);

        livePrice = msg.value;
        winning = payable(msg.sender);

        emit Bid(msg.sender, msg.value);
    }

    /// @notice an external function to end an auction after the timer has run out
    function end() external {
        if (auctionState != State.Live) revert AuctionNotLive();
        if (block.timestamp < auctionEnd) revert AuctionNotEnded();

        _claimFees();

        // transfer erc721 to winner
        IERC721(token).transferFrom(address(this), winning, id);

        auctionState = State.Ended;

        emit Won(winning, livePrice);
    }

    /// @notice an external function to burn all ERC20 tokens to receive the ERC721 token
    function redeem() external {
        if (auctionState != State.Inactive) revert AuctionLive();
        _burn(msg.sender, totalSupply());

        // transfer erc721 to redeemer
        IERC721(token).transferFrom(address(this), msg.sender, id);

        auctionState = State.Redeemed;

        emit Redeem(msg.sender);
    }

    /// @notice an external function to burn ERC20 tokens to receive ETH from ERC721 token purchase
    function cash() external {
        if (auctionState != State.Ended) revert AuctionNotEnded();
        uint256 bal = balanceOf(msg.sender);
        if (bal == 0) revert NoTokens();

        uint256 share = (bal * address(this).balance) / totalSupply();
        _burn(msg.sender, bal);

        _sendETHOrWETH(payable(msg.sender), share);

        emit Cash(msg.sender, share);
    }

    function setVaultMetadata(
        string calldata name_,
        string calldata symbol_
    ) external onlyCurator {
        _setMetadata(name_, symbol_);
    }

    // Will attempt to transfer ETH, but will transfer WETH instead if it fails.
    function _sendETHOrWETH(address to, uint256 value) internal {
        // Try to transfer ETH to the given recipient.
        if (!_attemptETHTransfer(to, value)) {
            // If the transfer fails, wrap and send as WETH, so that
            // the auction is not impeded and the recipient still
            // can claim ETH via the WETH contract (similar to escrow).
            IWETH weth = IWETH(IFNFTFactory(factory).WETH());
            weth.deposit{value: value}();
            weth.transfer(to, value);
            // At this point, the recipient can unwrap WETH.
        }
    }

    // Sending ETH is not guaranteed complete, and the method used here will return false if
    // it fails. For example, a contract can block ETH transfer, or might use
    // an excessive amount of gas, thereby griefing a new bidder.
    // We should limit the gas used in transfers, and handle failure cases.
    function _attemptETHTransfer(address to, uint256 value) internal returns (bool) {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = to.call{value: value, gas: 30000}("");
        return success;
    }

    function flashFee(address loanToken, uint256 amount) public view returns (uint256) {
        if (loanToken != address(this)) revert WrongToken();
        return IFNFTFactory(factory).flashLoanFee() * amount / 10000;
    }

    function flashLoan(
        IERC3156FlashBorrowerUpgradeable receiver,
        address loanToken,
        uint256 amount,
        bytes calldata data
    ) public override virtual returns (bool) {
        uint256 flashLoanFee = flashFee(loanToken, amount);
        return _flashLoan(receiver, loanToken, amount, flashLoanFee, data);
    }

    function _chargeAndDistributeFees(address user, uint256 amount) internal override virtual {
        // TODO: charge a fee
    }
}
