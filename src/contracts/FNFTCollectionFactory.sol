// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./util/Pausable.sol";

import "./interfaces/IFNFTCollectionFactory.sol";
import "./interfaces/IVaultManager.sol";
import "./FNFTCollection.sol";
import "./proxy/BeaconProxy.sol";
import "./proxy/BeaconUpgradeable.sol";

// Authors: @0xKiwi_ and @alexgausman.

contract FNFTCollectionFactory is
    IFNFTCollectionFactory,
    Pausable,
    BeaconUpgradeable
{
    mapping(uint256 => VaultFees) private _vaultFees;

    uint64 public override factoryMintFee;
    uint64 public override factoryRandomRedeemFee;
    uint64 public override factoryTargetRedeemFee;
    uint64 public override factoryRandomSwapFee;

    IVaultManager public override vaultManager;
    uint64 public override factoryTargetSwapFee;

    address public override eligibilityManager;
    uint64 public override flashLoanFee;

    uint256 public override swapFee;

    function __FNFTCollectionFactory_init(address _vaultManager) public override initializer {
        if (_vaultManager == address(0)) revert ZeroAddress();
        __Pausable_init();
        // We use a beacon proxy so that every child contract follows the same implementation code.
        __BeaconUpgradeable__init(address(new FNFTCollection()));
        vaultManager = IVaultManager(_vaultManager);
        setFactoryFees(0.1 ether, 0.05 ether, 0.1 ether, 0.05 ether, 0.1 ether);
    }

    function createVault(
        string memory name,
        string memory symbol,
        address _assetAddress,
        bool is1155,
        bool allowAllItems
    ) external virtual override returns (address) {
        onlyOwnerIfPaused(0);
        if (childImplementation() == address(0)) revert ZeroAddress();
        IVaultManager _vaultManager = vaultManager;
        address fnftCollection = deployVault(name, symbol, _assetAddress, is1155, allowAllItems);
        uint vaultId = _vaultManager.addVault(fnftCollection);
        emit NewVault(vaultId, fnftCollection, _assetAddress);
        return fnftCollection;
    }

    function setFlashLoanFee(uint256 _flashLoanFee) external virtual override onlyOwner {
        if (_flashLoanFee > 500) revert FeeTooHigh();
        emit UpdateFlashLoanFee(flashLoanFee, _flashLoanFee);
        flashLoanFee = uint64(_flashLoanFee);
    }

    function setSwapFee(uint256 _swapFee) external virtual override onlyOwner {
        if (_swapFee > 500) revert FeeTooHigh();
        emit UpdateSwapFee(swapFee, _swapFee);
        swapFee = _swapFee;
    }

    function setFactoryFees(
        uint256 mintFee,
        uint256 randomRedeemFee,
        uint256 targetRedeemFee,
        uint256 randomSwapFee,
        uint256 targetSwapFee
    ) public onlyOwner virtual override {
        if (mintFee > 0.5 ether) revert FeeTooHigh();
        if (randomRedeemFee > 0.5 ether) revert FeeTooHigh();
        if (targetRedeemFee > 0.5 ether) revert FeeTooHigh();
        if (randomSwapFee > 0.5 ether) revert FeeTooHigh();
        if (targetSwapFee > 0.5 ether) revert FeeTooHigh();

        factoryMintFee = uint64(mintFee);
        factoryRandomRedeemFee = uint64(randomRedeemFee);
        factoryTargetRedeemFee = uint64(targetRedeemFee);
        factoryRandomSwapFee = uint64(randomSwapFee);
        factoryTargetSwapFee = uint64(targetSwapFee);

        emit UpdateFactoryFees(mintFee, randomRedeemFee, targetRedeemFee, randomSwapFee, targetSwapFee);
    }

    function setVaultFees(
        uint256 vaultId,
        uint256 mintFee,
        uint256 randomRedeemFee,
        uint256 targetRedeemFee,
        uint256 randomSwapFee,
        uint256 targetSwapFee
    ) public virtual override {
        if (msg.sender != owner()) {
            address vaultAddr = vaultManager.vault(vaultId);
            if (msg.sender != vaultAddr) revert CallerIsNotVault();
        }
        if (mintFee > 0.5 ether) revert FeeTooHigh();
        if (randomRedeemFee > 0.5 ether) revert FeeTooHigh();
        if (targetRedeemFee > 0.5 ether) revert FeeTooHigh();
        if (randomSwapFee > 0.5 ether) revert FeeTooHigh();
        if (targetSwapFee > 0.5 ether) revert FeeTooHigh();

        _vaultFees[vaultId] = VaultFees(
            true,
            uint64(mintFee),
            uint64(randomRedeemFee),
            uint64(targetRedeemFee),
            uint64(randomSwapFee),
            uint64(targetSwapFee)
        );
        emit UpdateVaultFees(vaultId, mintFee, randomRedeemFee, targetRedeemFee, randomSwapFee, targetSwapFee);
    }

    function disableVaultFees(uint256 vaultId) public virtual override {
        if (msg.sender != owner()) {
            address vaultAddr = vaultManager.vault(vaultId);
            if (msg.sender != vaultAddr) revert CallerIsNotVault();
        }
        delete _vaultFees[vaultId];
        emit DisableVaultFees(vaultId);
    }

    function setEligibilityManager(address _eligibilityManager) external onlyOwner virtual override {
        emit NewEligibilityManager(eligibilityManager, _eligibilityManager);
        eligibilityManager = _eligibilityManager;
    }

    function vaultFees(uint256 vaultId) external view virtual override returns (uint256, uint256, uint256, uint256, uint256) {
        VaultFees memory fees = _vaultFees[vaultId];
        if (fees.active) {
            return (
                uint256(fees.mintFee),
                uint256(fees.randomRedeemFee),
                uint256(fees.targetRedeemFee),
                uint256(fees.randomSwapFee),
                uint256(fees.targetSwapFee)
            );
        }

        return (uint256(factoryMintFee), uint256(factoryRandomRedeemFee), uint256(factoryTargetRedeemFee), uint256(factoryRandomSwapFee), uint256(factoryTargetSwapFee));
    }

    function isLocked(uint256 lockId) external view override virtual returns (bool) {
        return isPaused[lockId];
    }

    function deployVault(
        string memory name,
        string memory symbol,
        address _assetAddress,
        bool is1155,
        bool allowAllItems
    ) internal returns (address) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            FNFTCollection.__FNFTCollection_init.selector,
            name,
            symbol,
            _assetAddress,
            is1155,
            allowAllItems
        );

        address newBeaconProxy = address(new BeaconProxy(address(this), _initializationCalldata));

        // Manager for configuration.
        FNFTCollection(newBeaconProxy).setManager(msg.sender);
        // Owner for administrative functions.
        FNFTCollection(newBeaconProxy).transferOwnership(owner());
        return newBeaconProxy;
    }
}