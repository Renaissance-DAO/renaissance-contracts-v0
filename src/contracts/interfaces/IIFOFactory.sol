//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIFOFactory {
    function getIFO(address) external view returns (address);

    function minimumDuration() external view returns (uint256);

    function maximumDuration() external view returns (uint256);

    function governanceFee() external view returns (uint256);

    function creatorUtilityContract() external view returns (address);

    function creatorIFOLock() external view returns (bool);

    function feeReceiver() external view returns (address payable);

    function __IFOFactory_init() external;

    function create(
        address _FNFT,
        uint256 _amountForSale,
        uint256 _price,
        uint256 _cap,
        uint256 _duration,
        bool _allowWhitelisting
    ) external returns (address);

    function pause() external;

    function unpause() external;

    function setCreatorIFOLock(bool _creatorIFOLock) external;

    function setMinimumDuration(uint256 _minimumDuration) external;

    function setMaximumDuration(uint256 _maximumDuration) external;

    function setCreatorUtilityContract(address _creatorUtilityContract) external;

    function setGovernanceFee(uint256 _governanceFee) external;

    function setFeeReceiver(address payable _feeReceiver) external;

    event CreatorIFOLockUpdated(bool oldCreatorIFOLock, bool newCreatorIFOLock);
    event MinimumDurationUpdated(uint256 oldMinimumDuration, uint256 newMinimumDuration);
    event MaximumDurationUpdated(uint256 oldMaximumDuration, uint256 newMaximumDuration);
    event CreatorUtilityContractUpdated(address oldCreatorUtilityContract, address newCreatorUtilityContract);
    event GovernanceFeeUpdated(uint256 oldGovernanceFee, uint256 newGovernanceFee);
    event FeeReceiverUpdated(address oldFeeReceiver, address newFeeReceiver);
    event IFOCreated(
        address indexed IFO,
        address indexed FNFT,
        uint256 amountForSale,
        uint256 price,
        uint256 cap,
        uint256 duration,
        bool allowWhitelisting
    );

    error ZeroAddressDisallowed();
    error FeeTooHigh();
    error InvalidDuration();
    error IFOExists(address nft);
}
