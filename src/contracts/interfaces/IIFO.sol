//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IFNFT.sol";
import "./IIFOFactory.sol";

interface IIFO {
    struct UserInfo {
        uint256 amount; // Amount ETH deposited by user
        uint256 debt; // total FNFT claimed thus FNFT debt
    }

    function curator() external view returns (address);

    function factory() external view returns (IIFOFactory);

    function fnft() external view returns (IFNFT);

    function amountForSale() external view returns (uint256);

    function price() external view returns (uint256);

    function cap() external view returns (uint256);

    function totalRaised() external view returns (uint256);

    function profitRaised() external view returns (uint256);

    function totalSold() external view returns (uint256);

    function lockedSupply() external view returns (uint256);

    function duration() external view returns (uint256);

    function startBlock() external view returns (uint256);

    function pauseBlock() external view returns (uint256);

    function allowWhitelisting() external view returns (bool);

    function started() external view returns (bool);

    function ended() external view returns (bool);

    function paused() external view returns (bool);

    function userInfo(address) external view returns (uint256, uint256);

    function whitelisted(address) external view returns (bool);

    function __IFO_init(
        address _curator,
        address _fnftAddress,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        uint256 _duration,
        bool _allowWhitelisting
    ) external;

    function addWhitelist(address _address) external;

    function addMultipleWhitelists(address[] calldata _addresses) external;

    function removeWhitelist(address _address) external;

    function start() external;

    function togglePause() external returns (bool);

    function end() external;

    function deposit() external payable;

    function getUserRemainingAllocation(address _user) external view returns (uint256);

    function updateFNFTAddress(address _address) external;

    function adminWithdrawProfit() external;

    function adminWithdrawFNFT() external;

    function approve() external;

    function emergencyWithdrawFNFT() external;

    function fnftLocked() external view returns (bool);

    event FNFTSold(address indexed buyer, uint256 amount, uint256 payout);
    event SaleStarted();
    event SaleEnded();
    event PausedToggled(bool paused);
    event AdminProfitWithdrawn(address FNFT, uint256 amount);
    event AdminFNFTWithdrawn(address FNFT, uint256 amount);
    event EmergencyFNFTWithdrawn(address FNFT, uint256 amount);

    error ContractPaused();
    error DeadlineActive();
    error FNFTLocked();
    error InvalidAmountForSale();
    error InvalidCap();
    error InvalidDuration();
    error InvalidPrice();
    error InvalidReservePrice();
    error NoLiquidityProvided();
    error NoProfit();
    error NotCurator();
    error NotEnoughSupply();
    error NotGov();
    error NotWhitelisted();
    error OverLimit();
    error SaleActive();
    error SaleAlreadyEnded();
    error SaleAlreadyStarted();
    error SaleUnstarted();
    error TooManyWhitelists();
    error TxFailed();
    error WhitelistingDisallowed();
    error ZeroAddress();
}
