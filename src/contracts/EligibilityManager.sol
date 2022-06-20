// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity 0.8.13;

import "./interfaces/IEligibility.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

contract EligibilityManager is OwnableUpgradeable {
    struct EligibilityModule {
        address implementation;
        address targetAsset;
        string name;
    }
    EligibilityModule[] public modules;

    event ModuleAdded(
        address implementation,
        address targetAsset,
        string name,
        bool finalizedOnDeploy
    );
    event ModuleUpdated(
        address implementation,
        string name,
        bool finalizedOnDeploy
    );

    error OutOfBounds();
    error NoImplementation();

    function __EligibilityManager_init() public initializer {
        __Ownable_init();
    }

    function addModule(address implementation) external onlyOwner {
        if (implementation == address(0)) revert NoImplementation();

        IEligibility elig = IEligibility(implementation);
        string memory name = elig.name();
        EligibilityModule memory module = EligibilityModule(
            implementation,
            elig.targetAsset(),
            name
        );
        modules.push(module);
        emit ModuleAdded(
            implementation,
            module.targetAsset,
            name,
            elig.finalized()
        );
    }

    function updateModule(uint256 moduleIndex, address implementation)
        external
        onlyOwner
    {
        if (moduleIndex >= modules.length) revert OutOfBounds();
        if (implementation == address(0)) revert NoImplementation();
        modules[moduleIndex].implementation = implementation;
        IEligibility elig = IEligibility(implementation);
        emit ModuleUpdated(implementation, elig.name(), elig.finalized());
    }

    function deployEligibility(uint256 moduleIndex, bytes calldata configData)
        external
        virtual
        returns (address)
    {
        if (moduleIndex >= modules.length) revert OutOfBounds();
        address eligImpl = modules[moduleIndex].implementation;
        address eligibilityClone = ClonesUpgradeable.clone(eligImpl);
        IEligibility(eligibilityClone).__Eligibility_init_bytes(
            configData
        );
        return eligibilityClone;
    }

    function allModules() external view returns (EligibilityModule[] memory) {
        return modules;
    }

    function allModuleNames() external view returns (string[] memory) {
        EligibilityModule[] memory modulesCopy = modules;
        string[] memory names = new string[](modulesCopy.length);
        for (uint256 i = 0; i < modulesCopy.length; i++) {
            names[i] = modulesCopy[i].name;
        }
        return names;
    }
}
