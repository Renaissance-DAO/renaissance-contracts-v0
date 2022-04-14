// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./IFOSettings.sol";
import "./interfaces/IFNFT.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract IFO is Initializable {
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

    IERC20 public FNFT; // fNFT the ifo contract sells
    uint256 public amountForSale; // amount of fNFT for sale
    uint256 public price; // initial price per fNFT
    uint256 public cap; // cap per user
    uint256 public totalRaised; // total ETH raised by sale
    uint256 public profitRaised;
    uint256 public totalSold; // total fNFT sold by sale

    uint256 public duration; // ifo duration
    uint256 public startBlock; // block started
    uint256 public pauseBlock; // block paused

    bool public allowWhitelisting; // whether the ifo operates through WL
    bool public started; // true when sale is started
    bool public ended; // true when sale is ended
    bool public paused; // circuit breaker

    address public curator;
    address public immutable settings;

    mapping(address => UserInfo) public userInfo;
    mapping(address => bool) public whitelisted; // True if user is whitelisted

    event Deposit(address indexed buyer, uint256 amount, uint256 payout);
    event Start(uint256 block);
    event End(uint256 block);
    event Pause(bool paused, uint256 block);
    event AdminProfitWithdrawal(address FNFT, uint256 amount);    
    event AdminFNFTWithdrawal(address FNFT, uint256 amount);    

    error NotGov();
    error NotCurator();
    error InvalidAddress();
    error NotEnoughSupply();
    error InvalidAmountForSale();
    error InvalidPrice();
    error InvalidCap();
    error InvalidDuration();
    error InvalidReservePrice(uint256 proposedPrice);
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

    constructor(address _settings) {
        settings = _settings;
    }
    
    function initialize(
        //original owner
        address _curator,
        //FNFT address
        address _FNFT,
        //Amount of FNFT for sale in IFO
        uint256 _amountForSale,
        //Price per FNFT in IFO
        uint256 _price,
        //Maximum an account can buy
        uint256 _cap,
        //Duration of IFO. Max duration set by DAO if _duration == 0
        uint256 _duration,
        //If IFO should be governed by whitelists
        bool _allowWhitelisting
    ) external initializer {
        // set storage variables
        if (_FNFT == address(0)) revert InvalidAddress();
        FNFT = IERC20(_FNFT);
        IFNFT fnft = IFNFT(address(FNFT));
        uint256 curatorSupply = fnft.balanceOf(_curator);
        uint256 totalSupply = fnft.totalSupply();
        // make sure curator holds 100% of the FNFT before IFO (May change if DAO takes fee on fractionalize)
        if (curatorSupply < totalSupply) revert NotEnoughSupply();
        // make sure amount for sale is not bigger than the supply if FNFT
        if (
            _amountForSale == 0 || _amountForSale > curatorSupply
            // _amountForSale % _cap != 0
        ) revert InvalidAmountForSale();
        if (_cap == 0 || _cap > totalSupply) revert InvalidCap();
        // expect ifo duration to be between minimum and maximum durations set by the DAO
        if (_duration < IIFOSettings(settings).minimumDuration() || _duration > IIFOSettings(settings).maximumDuration()) revert InvalidDuration();
        // reject if MC of IFO greater than reserve price set by curator. Protects the initial investors
        //if the requested price of the tokens here is greater than the implied value of each token from the initial reserve, revert
        // if ((_price * totalSupply) / 1e18 > fnft.initialReserve()) revert InvalidReservePrice(_price);
        
        curator = _curator;
        amountForSale = _amountForSale;
        price = _price;
        cap = _cap;
        allowWhitelisting = _allowWhitelisting;
        duration = _duration;        
    }

    modifier onlyCurator() {
        if (msg.sender != curator) revert NotCurator();
        _;
    }

    modifier onlyGov() {
        if (msg.sender != Ownable(settings).owner()) revert NotGov();
        _;
    }

    /// @notice checks if whitelist period is over and ends whitelist
    modifier checkDeadline() {
        if (block.number > startBlock + duration && duration != 0) {
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
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelisted[_addresses[i]] = true;
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
        if (FNFT.balanceOf(address(this)) < FNFT.totalSupply()) revert NotEnoughSupply();

        startBlock = block.number;

        started = true;
        emit Start(block.number);
    }

    //TODO: Add a circute breaker controlled by the DAO

    /// @notice lets owner pause contract. Pushes back the IFO end date
    function togglePause() external onlyCurator returns (bool) {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();

        if (paused) {
            duration += block.number - pauseBlock;
            paused = false;
        } else {
            pauseBlock = block.number;
            paused = true;
        }
        emit Pause(paused, block.number);
        return paused;
    }

    /// @notice Ends the sale
    function end() public onlyCurator checkPaused {
        if (!started) revert SaleUnstarted();
        if (
            block.number < startBlock + duration || // If not past duration
            IIFOSettings(settings).minimumDuration() > block.number - startBlock // If tries to end before minimum duration
        ) revert DeadlineActive();
        if (ended) revert SaleAlreadyEnded();

        ended = true;
        emit End(block.number);
    }
    
    ///@notice it deposits ETH for the sale
    function deposit() external payable checkPaused checkDeadline {
        if (!started) revert SaleUnstarted();
        if (ended) revert SaleAlreadyEnded();
        if (allowWhitelisting == true) {
            if (!whitelisted[msg.sender]) revert NotWhitelisted();
        }

        UserInfo storage user = userInfo[msg.sender];

        uint256 payout = msg.value / price; // fNFT to mint for msg.value

        if (user.amount + payout > cap) revert OverLimit();


        totalSold = totalSold + payout;
        
        address govAddress = IIFOSettings(settings).feeReceiver();
        uint256 govFee = IIFOSettings(settings).governanceFee();

        uint256 fee = (govFee * msg.value) / 1000;
        uint256 profit = msg.value - fee;

        user.amount += payout;
        totalRaised += msg.value;
        profitRaised += profit;

        FNFT.safeTransfer(msg.sender, payout);
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
    function updatefNFTAddress(address _address) external onlyGov {
        FNFT = IERC20(_address);
    }

    /// @notice withdraws ETH from sale only after IFO over
    function adminWithdrawProfit() external checkDeadline onlyCurator {
        if (!ended) revert SaleActive();
        uint256 profit = profitRaised;
        profitRaised = 0;

        _safeTransferETH(msg.sender, profit);

        emit AdminProfitWithdrawal(address(FNFT), profit);
    }

    /// @notice withdraws FNFT from sale only after IFO. Can only withdraw after NFT redemption if IFOLock enabled
    function adminWithdrawFNFT() external checkDeadline onlyCurator {
        if (!ended) revert SaleActive();
        if (IIFOSettings(settings).creatorIFOLock() && IFNFT(address(FNFT)).auctionState() != uint256(FNFTState.redeemed))
            revert FNFTLocked();

        uint256 fNFTBalance = IFNFT(address(FNFT)).balanceOf(address(this));
        FNFT.safeTransfer(address(msg.sender), fNFTBalance);

        emit AdminFNFTWithdrawal(address(FNFT), fNFTBalance);
    }

    /// @notice approve fNFT usage by creator utility contract, to deploy LP pool or stake if IFOLock enabled
    function approve() public onlyCurator {
        if (!ended) revert SaleActive();        

        FNFT.safeApprove(IIFOSettings(settings).creatorUtilityContract(), 1e18);
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
}