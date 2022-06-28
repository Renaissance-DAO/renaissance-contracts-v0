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

    function setCreatorIFOLock(bool _lock) external;

    function setMinimumDuration(uint256 _blocks) external;

    function setMaximumDuration(uint256 _blocks) external;

    function setCreatorUtilityContract(address _utility) external;

    function setGovernanceFee(uint256 _fee) external;

    function setFeeReceiver(address payable _receiver) external;

    event UpdateCreatorIFOLock(bool _old, bool _new);
    event UpdateMinimumDuration(uint256 _old, uint256 _new);
    event UpdateMaximumDuration(uint256 _old, uint256 _new);
    event UpdateCreatorUtilityContract(address _old, address _new);
    event UpdateGovernanceFee(uint256 _old, uint256 _new);
    event UpdateFeeReceiver(address _old, address _new);
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
