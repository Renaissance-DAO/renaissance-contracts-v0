//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IIFOSettings.sol";

contract IFOSettings is Ownable, IIFOSettings {
    /// @notice the boolean whether creator should have access to the creator's fNFT shares after IFO
    bool public override creatorIFOLock;
    uint public override minimumDuration;
    uint public override maximumDuration;
    address public override creatorUtilityContract;

    event UpdateCreatorIFOLock(bool _lock);
    event UpdateMinimumDuration(uint _blocks);
    event UpdateMaximumDuration(uint _blocks);
    event UpdateCreatorUtilityContract(address _utility);

    constructor() {
        creatorIFOLock = false;
        minimumDuration = 86400; // 1 day;
        maximumDuration = 7776000; // 90 days;        
    }

    function setCreatorIFOLock(bool  _lock) external onlyOwner {
        emit UpdateCreatorIFOLock(_lock);

        creatorIFOLock = _lock;
    }

    function setMinimumDuration(uint _blocks) external onlyOwner {
        emit UpdateMinimumDuration(_blocks);

        minimumDuration = _blocks;
    }

    function setMaximumDuration(uint _blocks) external onlyOwner {
        emit UpdateMaximumDuration(_blocks);

        maximumDuration = _blocks;
    }

    function setCreatorUtilityContract(address _utility) external onlyOwner {
        emit UpdateCreatorUtilityContract(_utility);

        creatorUtilityContract = _utility;
    }
}