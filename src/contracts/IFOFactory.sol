//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IFO.sol";
import "./interfaces/IIFOFactory.sol";
import "./proxy/BeaconProxy.sol";
import "./proxy/BeaconUpgradeable.sol";

contract IFOFactory is IIFOFactory, OwnableUpgradeable, PausableUpgradeable, BeaconUpgradeable {
    /// @notice 10% fee is max
    uint256 public constant MAX_GOV_FEE = 1000;

    /// @notice the mapping of FNFT to IFO address
    mapping(address => address) public override ifos;

    address public override creatorUtilityContract;
    /// @notice the address who receives ifo fees
    address payable public override feeReceiver;
    /// @notice the boolean whether creator should have access to the creator's FNFT shares after IFO
    bool public override creatorIFOLock;

    uint256 public override governanceFee;
    uint256 public override maximumDuration;
    uint256 public override minimumDuration;

    function __IFOFactory_init() external override initializer {
        __Ownable_init();
        __Pausable_init();
        __BeaconUpgradeable__init(address(new IFO()));

        feeReceiver = payable(msg.sender);
        governanceFee = 200;
        maximumDuration = 7776000; // 90 days;
        minimumDuration = 86400; // 1 day;
    }

    /// @notice the function to create an IFO
    /// @param _fnft the ERC20 token address of the FNFT
    /// @param _amountForSale the amount of FNFT for sale in IFO
    /// @param _price the price of each FNFT token
    /// @param _cap the maximum amount an account can buy
    /// @param _allowWhitelisting if IFO should be governed by whitelists
    /// @return IFO address
    function create(
        address _fnft,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        uint256 _duration,
        bool _allowWhitelisting
    ) external override whenNotPaused returns (address) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFO.__IFO_init.selector,
            msg.sender,
            _fnft,
            _amountForSale,
            _price,
            _cap,
            _duration,
            _allowWhitelisting
        );

        address _ifo = address(new BeaconProxy(address(this), _initializationCalldata));
        ifos[_fnft] = _ifo;

        IERC20(_fnft).transferFrom(msg.sender, _ifo, IERC20(_fnft).balanceOf(msg.sender));

        emit IFOCreated(_ifo, _fnft, _amountForSale, _price, _cap, _duration, _allowWhitelisting);

        return _ifo;
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function setCreatorIFOLock(bool _creatorIFOLock) external override onlyOwner {
        emit CreatorIFOLockUpdated(creatorIFOLock, _creatorIFOLock);
        creatorIFOLock = _creatorIFOLock;
    }

    function setCreatorUtilityContract(address _creatorUtilityContract) external override onlyOwner {
        emit CreatorUtilityContractUpdated(creatorUtilityContract, _creatorUtilityContract);
        creatorUtilityContract = _creatorUtilityContract;
    }

    function setFeeReceiver(address payable _feeReceiver) external override onlyOwner {
        if (_feeReceiver == address(0)) revert ZeroAddress();
        emit FeeReceiverUpdated(feeReceiver, _feeReceiver);
        feeReceiver = _feeReceiver;
    }

    function setGovernanceFee(uint256 _governanceFee) external override onlyOwner {
        if (_governanceFee > MAX_GOV_FEE) revert FeeTooHigh();
        emit GovernanceFeeUpdated(governanceFee, _governanceFee);
        governanceFee = _governanceFee;
    }

    function setMaximumDuration(uint256 _maximumDuration) external override onlyOwner {
        if (minimumDuration > _maximumDuration) revert InvalidDuration();
        emit MaximumDurationUpdated(maximumDuration, _maximumDuration);
        maximumDuration = _maximumDuration;
    }

    function setMinimumDuration(uint256 _minimumDuration) external override onlyOwner {
        if (_minimumDuration > maximumDuration) revert InvalidDuration();
        emit MinimumDurationUpdated(minimumDuration, _minimumDuration);
        minimumDuration = _minimumDuration;
    }

    function unpause() external override onlyOwner {
        _unpause();
    }
}
