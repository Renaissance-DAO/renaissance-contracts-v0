// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IIFOSettings.sol";
import "./interfaces/IFNFT.sol";

contract IFO is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount; // Amount ETH deposited by user
        uint256 debt; // total fNFT claimed thus fNFT debt
    }

    enum FNFTState {
        inactive,
        presale,
        live,
        ended,
        redeemed
    }

    IIFOSettings public immutable settings;
    
    IERC20 public FNFT; // fNFT the ifo contract sells
    IERC20 public ETH; // for user deposits
    uint256 public amountForSale; // amount of fNFT for sale
    uint256 public price; // initial price per fNFT
    uint256 public cap; // cap per user
    uint256 public totalRaised; // total ETH raised by sale
    uint256 public totalSold; // total fNFT sold by sale    
    
    uint256 public duration; // ifo duration
    uint256 public startBlock; // block started
    uint256 public pauseBlock; // block paused

    bool public allowWhitelisting; // whether the ifo operates through WL
    bool public started; // true when sale is started
    bool public ended; // true when sale is ended
    bool public paused; // circuit breaker

    uint256 public liquidity = 0; //liquidity deployed by the creator

    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public whitelisted; // True if user is whitelisted

    event Deposit(address indexed who, uint256 amount, uint256 payout);
    event Withdraw(address token, address indexed who, uint256 amount);
    event Mint(address token, address indexed who, uint256 amount);
    event SaleStarted(uint256 block);
    event SaleEnded(uint256 block);
    event AdminProfitWithdrawal(address _FNFT, uint256 _amount);        
    event AdminETHWithdrawal(address _eth, uint256 _amount);
    event AdminFNFTWithdrawal(address _FNFT, uint256 _amount);
    event LiquidityAdded(uint amountToken, uint amountETH, uint liquidity);
    event LiquidityRemoved(uint amountToken, uint amountETH, uint liquidity);
    
    error InvalidAddress();
    error NotOwner();
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
    error OverLimit();
    error NoLiquidityProvided();
    error FNFTLocked();
    error NotAdmin();

    constructor(address _settings) {
        settings = IIFOSettings(_settings);
    }

    function initialize(
        address _FNFT,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        uint256 _duration,
        bool _allowWhitelisting
    ) external initializer {
        // initialize inherited contracts
         __Ownable_init();
        // set storage variables
        if (_FNFT == address(0)) revert InvalidAddress();
        FNFT = IERC20(_FNFT);
        IFNFT fnft = IFNFT( address(FNFT) );
        uint initiatorSupply = fnft.balanceOf(msg.sender);
        // make sure curator holds 100% of the FNFT before IFO (May change if DAO takes fee on fractionalize)
        if (initiatorSupply <= fnft.totalSupply()) revert NotOwner();
        // make sure amount for sale is not bigger than the supply if FNFT
        if (
            _amountForSale == 0 || 
            _amountForSale > initiatorSupply
            // _amountForSale % _cap != 0
        ) revert InvalidAmountForSale();
        if (_price == 0) revert InvalidPrice();
        if (_cap == 0) revert InvalidCap();
        // expect ifo duration to be between minimum and maximum durations set by the DAO        
        if (_duration < settings.minimumDuration() || _duration > settings.maximumDuration()) revert InvalidDuration();
        // reject if MC of IFO greater than reserve price set by curator. Protects the initial investors
        if (_price * fnft.totalSupply() > fnft.userPrices(msg.sender)) revert InvalidReservePrice();

        amountForSale = _amountForSale;
        price = _price;
        cap = _cap;
        allowWhitelisting = _allowWhitelisting;        
        duration = _duration;

        FNFT.safeTransferFrom(msg.sender, address(this), initiatorSupply);
    }

    modifier checkDeadline() {
        if (block.number > startBlock + duration && duration != 0) {
            end();
        }
        _;
    }

    //* @notice modifer to check if contract is paused
    modifier checkPaused() {
        if (paused) revert ContractPaused();        
        _;
    }

    //* @notice modifer to check if contract is paused
    modifier whitelistingAllowed() {
        if (!allowWhitelisting) revert WhitelistingDisallowed();
        _;
    }

    function updatefNFTAddress(address _address) external onlyOwner {
        FNFT = IERC20(_address);
    }

    /**
     *  @notice adds a single whitelist to the sale
     *  @param _address: address to whitelist
     */
    function addWhitelist(address _address) external onlyOwner whitelistingAllowed {
        whitelisted[_address] = true;
    }

    /**
     *  @notice adds multiple whitelist to the sale
     *  @param _addresses: dynamic array of addresses to whitelist
     */
    function addMultipleWhitelists(address[] calldata _addresses) external onlyOwner whitelistingAllowed {
        if (_addresses.length > 333) revert TooManyWhitelists();
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelisted[_addresses[i]] = true;
        }
    }

    /**
     *  @notice removes a single whitelist from the sale
     *  @param _address: address to remove from whitelist
     */
    function removeWhitelist(address _address) external onlyOwner whitelistingAllowed {
        whitelisted[_address] = false;
    }

    // @notice Starts the sale
    function start() external onlyOwner {
        if (started) revert SaleAlreadyStarted();
        if (ended) revert SaleAlreadyEnded();

        startBlock = block.number;
        
        started = true;
        emit SaleStarted(block.number);
    }

    // @notice lets owner pause contract
    function togglePause() external onlyOwner returns (bool){
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();

        if (paused) {
            duration += block.number - pauseBlock;
            paused = false;
        } else {
            pauseBlock = block.number;
            paused = true;
        }        
        return paused;
    }

    // @notice Ends the sale
    function end() public onlyOwner checkPaused {        
        if (!started) revert SaleUnstarted();
        if (
            block.number < startBlock + duration || // If not past duration
            settings.minimumDuration() > block.number - startBlock // If tries to end before minimum duration
        ) revert DeadlineActive();
        if (ended) revert SaleAlreadyEnded();

        ended = true;
        emit SaleEnded(block.number);
    }

    /**
     *  @notice it deposits ETH for the sale
     */
    function deposit() external payable checkPaused checkDeadline {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();
        if (allowWhitelisting == true) {
            if (!whitelisted[msg.sender]) revert NotWhitelisted();
        }

        UserInfo storage user = userInfo[msg.sender];
        if (user.amount + msg.value > cap) revert OverLimit();

        user.amount = user.amount + msg.value;
        totalRaised = totalRaised + msg.value;

        uint256 payout = (msg.value * 1e18) / price; // fNFT to mint for msg.value

        totalSold = totalSold + payout;

        FNFT.safeTransferFrom(address(this), msg.sender, payout);

        emit Deposit(msg.sender, msg.value, payout);
    }

    // @notice it checks a users ETH allocation remaining
    function getUserRemainingAllocation(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        return cap - user.amount;
    }

    //Managerial

    function adminWithdrawProfit() external checkDeadline onlyOwner {
        if (!ended) revert SaleActive();

        totalRaised = 0;

        _safeTransferETH(msg.sender, totalRaised);

        emit AdminProfitWithdrawal(address(FNFT), totalRaised);
    }

    function adminWithdrawFNFT() external checkDeadline onlyOwner {
        if (!ended) revert SaleActive();
        if (
            settings.creatorIFOLock() && 
            IFNFT(address(FNFT)).auctionState() != uint(FNFTState.redeemed)
        ) revert FNFTLocked();

        uint fNFTBalance = IFNFT( address(FNFT) ).balanceOf(address(this));
        FNFT.safeTransfer( address(msg.sender), fNFTBalance);

        emit AdminFNFTWithdrawal(address(FNFT), fNFTBalance);
    }

    // @notice approve fNFT usage by creator utility contract
    function approve(address _recipient) public onlyOwner {
        if (!ended) revert SaleActive();
        if (msg.sender != settings.creatorUtilityContract()) revert NotAdmin();

        FNFT.safeApprove(_recipient, 1e18);
    }

    //Helper functions

    function _safeTransferETH(address to, uint256 value) private {
        (bool success, ) = to.call{value: value}(new bytes(0));
        if (!success) revert TxFailed();
    }
}
