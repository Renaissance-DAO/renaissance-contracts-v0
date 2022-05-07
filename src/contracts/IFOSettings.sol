//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IIFOSettings.sol";

contract IFOSettings is OwnableUpgradeable, IIFOSettings {
    /// @notice the boolean whether creator should have access to the creator's fNFT shares after IFO
    bool public override creatorIFOLock;
    uint256 public override minimumDuration;
    uint256 public override maximumDuration;    
    uint256 public override governanceFee;
    /// @notice 10% fee is max
    uint256 public constant maxGovFee = 100;
    address public override creatorUtilityContract;
    /// @notice the address who receives ifo fees
    address payable public override feeReceiver;

    event UpdateCreatorIFOLock(bool _old, bool _new);
    event UpdateMinimumDuration(uint256 _old, uint256 _new);
    event UpdateMaximumDuration(uint256 _old, uint256 _new);
    event UpdateCreatorUtilityContract(address _old, address _new);
    event UpdateGovernanceFee(uint256 _old, uint256 _new);
    event UpdateFeeReceiver(address _old, address _new);

    error ZeroAddressDisallowed();
    error GovFeeTooHigh();
    
    function initialize() external initializer {
        __Ownable_init();

        creatorIFOLock = false;
        minimumDuration = 86400; // 1 day;
        feeReceiver = payable(msg.sender);
        maximumDuration = 7776000; // 90 days;
        governanceFee = 20;
    }

    function setCreatorIFOLock(bool _lock) external onlyOwner {
        emit UpdateCreatorIFOLock(creatorIFOLock, _lock);

        creatorIFOLock = _lock;
    }

    function setMinimumDuration(uint256 _blocks) external onlyOwner {
        emit UpdateMinimumDuration(minimumDuration, _blocks);

        minimumDuration = _blocks;
    }

    function setMaximumDuration(uint256 _blocks) external onlyOwner {
        emit UpdateMaximumDuration(maximumDuration, _blocks);

        maximumDuration = _blocks;
    }

    function setCreatorUtilityContract(address _utility) external onlyOwner {
        emit UpdateCreatorUtilityContract(creatorUtilityContract, _utility);

        creatorUtilityContract = _utility;
    }

    function setGovernanceFee(uint256 _fee) external onlyOwner {
        if (_fee > maxGovFee) revert GovFeeTooHigh();

        emit UpdateGovernanceFee(governanceFee, _fee);

        governanceFee = _fee;
    }

    function setFeeReceiver(address payable _receiver) external onlyOwner {
        if (_receiver == address(0)) revert ZeroAddressDisallowed();        

        emit UpdateFeeReceiver(feeReceiver, _receiver);

        feeReceiver = _receiver;
    }
}
