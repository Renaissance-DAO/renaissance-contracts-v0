// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "./interfaces/IFNFT.sol";
import "./interfaces/IFNFTSingle.sol";
import "./interfaces/IIFO.sol";
import "./interfaces/IIFOFactory.sol";

import {console} from "../test/utils/console.sol";

contract IFO is IIFO, Initializable {
    mapping(address => UserInfo) public override userInfo;
    mapping(address => bool) public override whitelisted; // True if user is whitelisted

    IIFOFactory public override factory;
    IFNFT public override fnft; // FNFT the ifo contract sells
    address public override curator;

    bool public override allowWhitelisting; // whether the ifo operates through WL
    bool public override started; // true when sale is started
    bool public override ended; // true when sale is ended
    bool public override paused; // circuit breaker

    uint256 public override amountForSale; // amount of FNFT for sale
    uint256 public override cap; // cap per user
    uint256 public override duration; // ifo duration
    uint256 public override lockedSupply;
    uint256 public override pauseBlock; // block paused
    uint256 public override price; // initial price per FNFT
    uint256 public override profitRaised;
    uint256 public override startBlock; // block started
    uint256 public override totalRaised; // total ETH raised by sale
    uint256 public override totalSold; // total FNFT sold by sale

    /// @param _curator original owner
    /// @param _fnftAddress FNFT address
    /// @param _amountForSale Amount of FNFT for sale in IFO
    /// @param _price Price per FNFT in IFO
    /// @param _cap Maximum an account can buy
    /// @param _duration Duration of IFO. Max duration set by DAO if _duration == 0
    /// @param _allowWhitelisting If IFO should be governed by whitelists
    function __IFO_init(
        address _curator,
        address _fnftAddress,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        uint256 _duration,
        bool _allowWhitelisting
    ) external override initializer {
        // set storage variables
        if (_curator == address(0)) revert ZeroAddress();
        if (_fnftAddress == address(0)) revert ZeroAddress();
        IFNFT _fnft = IFNFT(_fnftAddress);
        uint256 curatorSupply = _fnft.balanceOf(_curator);
        uint256 totalSupply = _fnft.totalSupply();
        IIFOFactory _factory = IIFOFactory(msg.sender);
        // make sure curator holds 100% of the FNFT before IFO (May change if DAO takes fee on fractionalize)
        if (IERC165(_fnftAddress).supportsInterface(type(IFNFTSingle).interfaceId)) {
            // reject if MC of IFO greater than reserve price set by curator. Protects the initial investors
            //if the requested price of the tokens here is greater than the implied value of each token from the initial reserve, revert
            if (curatorSupply < totalSupply) revert NotEnoughSupply();
            if (_price * totalSupply / (10 ** _fnft.decimals()) > IFNFTSingle(_fnftAddress).initialReserve()) revert InvalidReservePrice();
        } else {
            //0.5 ether is the maximum (50%) mint fee for collection.
            if (totalSupply == 0 || curatorSupply < totalSupply / 2) revert NotEnoughSupply();
        }
        // make sure amount for sale is not bigger than the supply if FNFT
        if (_amountForSale == 0 || _amountForSale > curatorSupply) revert InvalidAmountForSale();
        if (_cap == 0 || _cap > totalSupply) revert InvalidCap();
        // expect ifo duration to be between minimum and maximum durations set by the DAO
        if (_duration != 0 &&
        (_duration < _factory.minimumDuration()
        || _duration > _factory.maximumDuration())) revert InvalidDuration();

        factory = _factory;
        curator = _curator;
        amountForSale = _amountForSale;
        price = _price;
        cap = _cap;
        allowWhitelisting = _allowWhitelisting;
        duration = _duration;
        fnft = _fnft;

        /// @notice approve FNFT usage by creator utility contract, to deploy LP pool or stake if IFOLock enabled
        address creatorUtilityContract = IIFOFactory(msg.sender).creatorUtilityContract();
        if (creatorUtilityContract != address(0)) {
            _fnft.approve(creatorUtilityContract, totalSupply);
        }
    }

    /// @notice checks if whitelist period is over and ends whitelist
    modifier checkDeadline() {
        if (block.number > startBlock + duration && duration != 0 && !ended) {
            end();
        }
        _;
    }

    /// @notice modifer to check if contract is paused
    modifier checkPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier onlyCurator() {
        if (msg.sender != curator) revert NotCurator();
        _;
    }

    modifier onlyGov() {
        if (msg.sender != OwnableUpgradeable(address(factory)).owner()) revert NotGov();
        _;
    }

    /// @notice modifer to check if contract accepts whitelists
    modifier whitelistingAllowed() {
        if (!allowWhitelisting) revert WhitelistingDisallowed();
        _;
    }

    /**
     *  @notice adds multiple whitelist to the sale
     *  @param _addresses: dynamic array of addresses to whitelist
     */
    function addMultipleWhitelists(address[] calldata _addresses) external override onlyCurator whitelistingAllowed {
        if (_addresses.length > 333) revert TooManyWhitelists();
        for (uint256 i; i < _addresses.length;) {
            whitelisted[_addresses[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    /**
     *  @notice adds a single whitelist to the sale
     *  @param _address: address to whitelist
     */
    function addWhitelist(address _address) external override onlyCurator whitelistingAllowed {
        whitelisted[_address] = true;
    }

    /// @notice withdraws FNFT from sale only after IFO. Can only withdraw after NFT redemption if IFOLock enabled
    function adminWithdrawFNFT() external override checkDeadline onlyCurator {
        if (!ended) revert SaleActive();
        IFNFT _fnft = fnft;
        if (IERC165(address(_fnft)).supportsInterface(type(IFNFTSingle).interfaceId) &&
            IFNFTSingle(address(_fnft)).auctionState() != IFNFTSingle.State.Ended && _fnftLocked()) {
            revert FNFTLocked();
        }

        uint256 balance = _fnft.balanceOf(address(this));
        lockedSupply -= balance;
        _fnft.transfer(msg.sender, balance);

        emit AdminFNFTWithdrawn(address(_fnft), balance);
    }

    /// @notice withdraws ETH from sale only after IFO over
    function adminWithdrawProfit() external override checkDeadline onlyCurator {
        if (!ended) revert SaleActive();
        if (profitRaised == 0) revert NoProfit();
        uint256 profit = profitRaised;
        profitRaised = 0;

        _safeTransferETH(msg.sender, profit);

        emit AdminProfitWithdrawn(address(fnft), profit);
    }

    /// @notice approve FNFT usage by creator utility contract, to deploy LP pool or stake if IFOLock enabled
    function approve() external override onlyCurator {
        address creatorUtilityContract = factory.creatorUtilityContract();
        if (creatorUtilityContract == address(0)) revert ZeroAddress();
        IFNFT _fnft = fnft;
        _fnft.approve(creatorUtilityContract, _fnft.totalSupply());
    }

    /// @notice it deposits ETH for the sale
    function deposit() external payable override checkPaused checkDeadline {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();
        if (allowWhitelisting) {
            if (!whitelisted[msg.sender]) revert NotWhitelisted();
        }

        UserInfo storage user = userInfo[msg.sender];

        IFNFT _fnft = fnft;

        // FNFT to mint for msg.value
        uint256 payout = msg.value * (10 ** _fnft.decimals()) / price;

        if (user.amount + payout > cap) revert OverLimit();

        totalSold += payout;

        IIFOFactory _factory = factory;
        address govAddress = _factory.feeReceiver();
        uint256 govFee = _factory.governanceFee();

        uint256 fee = (govFee * msg.value) / 10000;
        uint256 profit = msg.value - fee;

        user.amount += payout;
        totalRaised += msg.value;
        profitRaised += profit;

        _fnft.transfer(msg.sender, payout);
        _safeTransferETH(govAddress, fee);

        emit FNFTSold(msg.sender, msg.value, payout);
    }

    function emergencyWithdrawFNFT() external override onlyGov {
        IFNFT _fnft = fnft;
        uint256 balance = _fnft.balanceOf(address(this));
        lockedSupply = 0;
        _fnft.transfer(curator, balance);

        emit EmergencyFNFTWithdrawn(address(_fnft), balance);
    }

    /// @notice Ends the sale
    function end() public override onlyCurator checkPaused {
        if (!started) revert SaleUnstarted();
        if (
            block.number <= startBlock + duration || // If not past duration
            block.number - startBlock < factory.minimumDuration() // If tries to end before minimum duration
        ) revert DeadlineActive();
        if (ended) revert SaleAlreadyEnded();

        ended = true;
        lockedSupply = fnft.balanceOf(address(this));
        emit SaleEnded();
    }

    function fnftLocked() external view override returns(bool) {
        return _fnftLocked();
    }

    /** @notice it checks a users ETH allocation remaining
    *   @param _user: user's remaining allocation based on cap
    */
    function getUserRemainingAllocation(address _user) external view override returns (uint256) {
        UserInfo memory user = userInfo[_user];
        return cap - user.amount;
    }

    /**
     *  @notice removes a single whitelist from the sale
     *  @param _address: address to remove from whitelist
     */
    function removeWhitelist(address _address) external override onlyCurator whitelistingAllowed {
        whitelisted[_address] = false;
    }

    /// @notice Starts the sale and checks if all FNFT is in IFO
    function start() external override onlyCurator {
        if (started) revert SaleAlreadyStarted();
        if (ended) revert SaleAlreadyEnded();

        IFNFT _fnft = fnft;
        uint256 ifoFNFTBalance = _fnft.balanceOf(address(this));
        uint256 totalSupply = _fnft.totalSupply();
        // make sure curator holds 100% of the FNFT before IFO (May change if DAO takes fee on fractionalize)
        if (IERC165(address(_fnft)).supportsInterface(type(IFNFTSingle).interfaceId)) {
            // reject if MC of IFO greater than reserve price set by curator. Protects the initial investors
            //if the requested price of the tokens here is greater than the implied value of each token from the initial reserve, revert
            if (ifoFNFTBalance < totalSupply) revert NotEnoughSupply();
        } else {
            //0.5 ether is the maximum (50%) mint fee for collection.
            if (totalSupply == 0 || ifoFNFTBalance < totalSupply / 2) revert NotEnoughSupply();
        }
        startBlock = block.number;
        started = true;
        emit SaleStarted();
    }

    //TODO: Add a circute breaker controlled by the DAO

    /// @notice lets owner pause contract. Pushes back the IFO end date
    function togglePause() external override onlyCurator checkDeadline returns (bool) {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();

        if (paused) {
            duration += block.number - pauseBlock;
            paused = false;
        } else {
            pauseBlock = block.number;
            paused = true;
        }
        emit PausedToggled(paused);
        return paused;
    }
    /** @notice If wrong FNFT
    *   @param _address: address of FNFT
    */
    function updateFNFTAddress(address _address) external override onlyGov {
        if (_address == address(0)) revert ZeroAddress();
        fnft = IFNFT(_address);
    }

    function _fnftLocked() internal view returns(bool) {
        return factory.creatorIFOLock();
    }

    /** @notice transfer ETH using call
    *   @param _to: address to transfer ETH to
    *   @param _value: amount of ETH to transfer
    */
    function _safeTransferETH(address _to, uint256 _value) private {
        (bool success, ) = _to.call{value: _value}(new bytes(0));
        if (!success) revert TxFailed();
    }
}
