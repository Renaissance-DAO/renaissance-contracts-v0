// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/IIFOFactory.sol";
import "./interfaces/IFNFTSingle.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

contract IFO is Initializable {
    struct UserInfo {
        uint256 amount; // Amount ETH deposited by user
        uint256 debt; // total fNFT claimed thus fNFT debt
    }

    IFNFTSingle public fnft; // fNFT the ifo contract sells
    uint256 public amountForSale; // amount of fNFT for sale
    uint256 public price; // initial price per fNFT
    uint256 public cap; // cap per user
    uint256 public totalRaised; // total ETH raised by sale
    uint256 public profitRaised;
    uint256 public totalSold; // total fNFT sold by sale
    uint256 public lockedSupply;

    uint256 public duration; // ifo duration
    uint256 public startBlock; // block started
    uint256 public pauseBlock; // block paused

    bool public allowWhitelisting; // whether the ifo operates through WL
    bool public started; // true when sale is started
    bool public ended; // true when sale is ended
    bool public paused; // circuit breaker

    address public curator;
    IIFOFactory public factory;

    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public whitelisted; // True if user is whitelisted

    event Deposit(address indexed buyer, uint256 amount, uint256 payout);
    event Start();
    event End();
    event Pause(bool paused);
    event AdminProfitWithdrawal(address FNFT, uint256 amount);
    event AdminFNFTWithdrawal(address FNFT, uint256 amount);
    event EmergencyFNFTWithdrawal(address FNFT, uint256 amount);

    error NotGov();
    error NotCurator();
    error InvalidAddress();
    error NotEnoughSupply();
    error InvalidAmountForSale();
    error InvalidPrice();
    error InvalidCap();
    error InvalidDuration();
    error InvalidReservePrice();
    error WhitelistingDisallowed();
    error ContractPaused();
    error TooManyWhitelists();
    error SaleAlreadyStarted();
    error SaleUnstarted();
    error SaleAlreadyEnded();
    error DeadlineActive();
    error SaleActive();
    error TxFailed();
    error NotWhitelisted();
    error NoProfit();
    error OverLimit();
    error NoLiquidityProvided();
    error FNFTLocked();

    /// @param _curator original owner
    /// @param _fnftAddress FNFT address
    /// @param _amountForSale Amount of FNFT for sale in IFO
    /// @param _price Price per FNFT in IFO
    /// @param _cap Maximum an account can buy
    /// @param _duration Duration of IFO. Max duration set by DAO if _duration == 0
    /// @param _allowWhitelisting If IFO should be governed by whitelists
    function initialize(
        address _curator,
        address _fnftAddress,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        uint256 _duration,
        bool _allowWhitelisting
    ) external initializer {
        // set storage variables
        if (_fnftAddress == address(0)) revert InvalidAddress();
        IFNFTSingle _fnft = IFNFTSingle(_fnftAddress);
        uint256 curatorSupply = IERC20Upgradeable(_fnftAddress).balanceOf(_curator);
        uint256 totalSupply = IERC20Upgradeable(_fnftAddress).totalSupply();
        bool isSingle = IERC165(_fnftAddress).supportsInterface(type(IFNFTSingle).interfaceId);
        IIFOFactory _factory = IIFOFactory(msg.sender);
        // make sure curator holds 100% of the FNFT before IFO (May change if DAO takes fee on fractionalize)
        if (isSingle) {
            // reject if MC of IFO greater than reserve price set by curator. Protects the initial investors
            //if the requested price of the tokens here is greater than the implied value of each token from the initial reserve, revert
            if (curatorSupply < totalSupply) revert NotEnoughSupply();
            if (_price * totalSupply / (10 ** IERC20MetadataUpgradeable(_fnftAddress).decimals()) > IFNFTSingle(_fnftAddress).initialReserve()) revert InvalidReservePrice();
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

        /// @notice approve fNFT usage by creator utility contract, to deploy LP pool or stake if IFOLock enabled
        address creatorUtilityContract = IIFOFactory(msg.sender).creatorUtilityContract();
        if (creatorUtilityContract != address(0)) {
            IERC20Upgradeable(_fnftAddress).approve(creatorUtilityContract, totalSupply);
        }
    }

    modifier onlyCurator() {
        if (msg.sender != curator) revert NotCurator();
        _;
    }

    modifier onlyGov() {
        if (msg.sender != OwnableUpgradeable(address(factory)).owner()) revert NotGov();
        _;
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

    /// @notice modifer to check if contract accepts whitelists
    modifier whitelistingAllowed() {
        if (!allowWhitelisting) revert WhitelistingDisallowed();
        _;
    }

    /**
     *  @notice adds a single whitelist to the sale
     *  @param _address: address to whitelist
     */
    function addWhitelist(address _address) external onlyCurator whitelistingAllowed {
        whitelisted[_address] = true;
    }

    /**
     *  @notice adds multiple whitelist to the sale
     *  @param _addresses: dynamic array of addresses to whitelist
     */
    function addMultipleWhitelists(address[] calldata _addresses) external onlyCurator whitelistingAllowed {
        if (_addresses.length > 333) revert TooManyWhitelists();
        for (uint256 i; i < _addresses.length;) {
            whitelisted[_addresses[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    /**
     *  @notice removes a single whitelist from the sale
     *  @param _address: address to remove from whitelist
     */
    function removeWhitelist(address _address) external onlyCurator whitelistingAllowed {
        whitelisted[_address] = false;
    }

    /// @notice Starts the sale and checks if all FNFT is in IFO
    function start() external onlyCurator {
        if (started) revert SaleAlreadyStarted();
        if (ended) revert SaleAlreadyEnded();
        IERC20Upgradeable _fnft = IERC20Upgradeable(address(fnft));
        if (_fnft.balanceOf(address(this)) < _fnft.totalSupply()) revert NotEnoughSupply();

        startBlock = block.number;

        started = true;
        emit Start();
    }

    //TODO: Add a circute breaker controlled by the DAO

    /// @notice lets owner pause contract. Pushes back the IFO end date
    function togglePause() external onlyCurator checkDeadline returns (bool) {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();

        if (paused) {
            duration += block.number - pauseBlock;
            paused = false;
        } else {
            pauseBlock = block.number;
            paused = true;
        }
        emit Pause(paused);
        return paused;
    }

    /// @notice Ends the sale
    function end() public onlyCurator checkPaused {
        if (!started) revert SaleUnstarted();
        if (
            block.number <= startBlock + duration || // If not past duration
            block.number - startBlock < factory.minimumDuration() // If tries to end before minimum duration
        ) revert DeadlineActive();
        if (ended) revert SaleAlreadyEnded();

        ended = true;
        lockedSupply = IERC20Upgradeable(address(fnft)).balanceOf(address(this));
        emit End();
    }

    ///@notice it deposits ETH for the sale
    function deposit() external payable checkPaused checkDeadline {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();
        if (allowWhitelisting) {
            if (!whitelisted[msg.sender]) revert NotWhitelisted();
        }

        UserInfo storage user = userInfo[msg.sender];

        address fnftAddress = address(fnft);

        // fNFT to mint for msg.value
        uint256 payout = msg.value * (10 ** IERC20MetadataUpgradeable(fnftAddress).decimals()) / price;

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

        IERC20Upgradeable(fnftAddress).transfer(msg.sender, payout);
        _safeTransferETH(govAddress, fee);

        emit Deposit(msg.sender, msg.value, payout);
    }

    /** @notice it checks a users ETH allocation remaining
    *   @param _user: user's remaining allocation based on cap
    */
    function getUserRemainingAllocation(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        return cap - user.amount;
    }

    /** @notice If wrong FNFT
    *   @param _address: address of FNFT
    */
    function updateFNFTAddress(address _address) external onlyGov {
        if (_address == address(0)) revert InvalidAddress();
        fnft = IFNFTSingle(_address);
    }

    /// @notice withdraws ETH from sale only after IFO over
    function adminWithdrawProfit() external checkDeadline onlyCurator {
        if (!ended) revert SaleActive();
        if (profitRaised == 0) revert NoProfit();
        uint256 profit = profitRaised;
        profitRaised = 0;

        _safeTransferETH(msg.sender, profit);

        emit AdminProfitWithdrawal(address(fnft), profit);
    }

    /// @notice withdraws FNFT from sale only after IFO. Can only withdraw after NFT redemption if IFOLock enabled
    function adminWithdrawFNFT() external checkDeadline onlyCurator {
        if (!ended) revert SaleActive();
        address fnftAddress = address(fnft);
        if (IERC165(fnftAddress).supportsInterface(type(IFNFTSingle).interfaceId) &&
            IFNFTSingle(fnftAddress).auctionState() != IFNFTSingle.State.Ended && _fnftLocked()) {
            revert FNFTLocked();
        }

        IERC20Upgradeable _fnft = IERC20Upgradeable(fnftAddress);
        uint256 fNFTBalance = _fnft.balanceOf(address(this));
        lockedSupply -= fNFTBalance;
        _fnft.transfer(msg.sender, fNFTBalance);

        emit AdminFNFTWithdrawal(fnftAddress, fNFTBalance);
    }

    /// @notice approve fNFT usage by creator utility contract, to deploy LP pool or stake if IFOLock enabled
    function approve() external onlyCurator {
        address creatorUtilityContract = factory.creatorUtilityContract();
        if (creatorUtilityContract == address(0)) revert InvalidAddress();
        IERC20Upgradeable _fnft = IERC20Upgradeable(address(fnft));
        _fnft.approve(creatorUtilityContract, _fnft.totalSupply());
    }

    function emergencyWithdrawFNFT() external onlyGov {
        IERC20Upgradeable _fnft = IERC20Upgradeable(address(fnft));
        uint256 fNFTBalance = _fnft.balanceOf(address(this));
        lockedSupply = 0;
        _fnft.transfer(curator, fNFTBalance);

        emit EmergencyFNFTWithdrawal(address(_fnft), fNFTBalance);
    }

    //Helper functions

    /** @notice transfer ETH using call
    *   @param _to: address to transfer ETH to
    *   @param _value: amount of ETH to transfer
    */
    function _safeTransferETH(address _to, uint256 _value) private {
        (bool success, ) = _to.call{value: _value}(new bytes(0));
        if (!success) revert TxFailed();
    }

    function fnftLocked() external view returns(bool) {
        return _fnftLocked();
    }

    function _fnftLocked() internal view returns(bool) {
        return factory.creatorIFOLock();
    }
}
