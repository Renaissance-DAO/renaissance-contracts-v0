// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IEligibilityManager {
    struct EligibilityModule {
        address implementation;
        address targetAsset;
        string name;
    }

    function modules(uint256) external view returns(address, address, string memory);

    function __EligibilityManager_init() external;

    function addModule(address implementation) external;

    function updateModule(uint256 moduleIndex, address implementation) external;

    function deployEligibility(uint256 vaultId, bytes calldata initData) external returns (address);

    function allModules() external view returns (EligibilityModule[] memory);

    function allModuleNames() external view returns (string[] memory);

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
}
