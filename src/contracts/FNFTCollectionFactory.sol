// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./FNFTCollection.sol";
import "./interfaces/IFNFTCollectionFactory.sol";
import "./interfaces/IVaultManager.sol";
import "./proxy/BeaconProxy.sol";
import "./proxy/BeaconUpgradeable.sol";
import "./util/Pausable.sol";

// Authors: @0xKiwi_ and @alexgausman.

contract FNFTCollectionFactory is
    IFNFTCollectionFactory,
    Pausable,
    BeaconUpgradeable
{
    mapping(uint256 => VaultFees) private _vaultFees;

    uint64 public override factoryMintFee;
    uint64 public override factoryRandomRedeemFee;
    uint64 public override factoryRandomSwapFee;
    uint64 public override factoryTargetRedeemFee;

    IVaultManager public override vaultManager;
    uint64 public override factoryTargetSwapFee;

    address public override eligibilityManager;
    uint256 public override flashLoanFee;

    uint256 public override swapFee;

    function __FNFTCollectionFactory_init(address _vaultManager) external override initializer {
        if (_vaultManager == address(0)) revert ZeroAddress();
        __Pausable_init();
        // We use a beacon proxy so that every child contract follows the same implementation code.
        __BeaconUpgradeable__init(address(new FNFTCollection()));
        vaultManager = IVaultManager(_vaultManager);
        setFactoryFees(0.1 ether, 0.05 ether, 0.1 ether, 0.05 ether, 0.1 ether);
    }

    function createVault(
        string memory _name,
        string memory _symbol,
        address _assetAddress,
        bool is1155,
        bool allowAllItems
    ) external virtual override returns (address) {
        onlyOwnerIfPaused(0);
        if (childImplementation() == address(0)) revert ZeroAddress();
        IVaultManager _vaultManager = vaultManager;
        address fnftCollection = _deployVault(_name, _symbol, _assetAddress, is1155, allowAllItems);
        uint vaultId = _vaultManager.addVault(fnftCollection);
        emit VaultCreated(vaultId, fnftCollection, _assetAddress);
        return fnftCollection;
    }

    function isLocked(uint256 lockId) external view override virtual returns (bool) {
        return isPaused[lockId];
    }

    function setEligibilityManager(address _eligibilityManager) external onlyOwner virtual override {
        emit EligibilityManagerUpdated(eligibilityManager, _eligibilityManager);
        eligibilityManager = _eligibilityManager;
    }

    function setFlashLoanFee(uint256 _flashLoanFee) external virtual override onlyOwner {
        if (_flashLoanFee > 500) revert FeeTooHigh();
        emit FlashLoanFeeUpdated(flashLoanFee, _flashLoanFee);
        flashLoanFee = _flashLoanFee;
    }

    function setSwapFee(uint256 _swapFee) external virtual override onlyOwner {
        if (_swapFee > 500) revert FeeTooHigh();
        emit SwapFeeUpdated(swapFee, _swapFee);
        swapFee = _swapFee;
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

    function disableVaultFees(uint256 vaultId) public virtual override {
        if (msg.sender != owner()) {
            address vaultAddr = vaultManager.vault(vaultId);
            if (msg.sender != vaultAddr) revert NotVault();
        }
        delete _vaultFees[vaultId];
        emit VaultFeesDisabled(vaultId);
    }

    function setFactoryFees(
        uint256 _factoryMintFee,
        uint256 _factoryRandomRedeemFee,
        uint256 _factoryTargetRedeemFee,
        uint256 _factoryRandomSwapFee,
        uint256 _factoryTargetSwapFee
    ) public onlyOwner virtual override {
        if (_factoryMintFee > 0.5 ether) revert FeeTooHigh();
        if (_factoryRandomRedeemFee > 0.5 ether) revert FeeTooHigh();
        if (_factoryTargetRedeemFee > 0.5 ether) revert FeeTooHigh();
        if (_factoryRandomSwapFee > 0.5 ether) revert FeeTooHigh();
        if (_factoryTargetSwapFee > 0.5 ether) revert FeeTooHigh();

        factoryMintFee = uint64(_factoryMintFee);
        factoryRandomRedeemFee = uint64(_factoryRandomRedeemFee);
        factoryTargetRedeemFee = uint64(_factoryTargetRedeemFee);
        factoryRandomSwapFee = uint64(_factoryRandomSwapFee);
        factoryTargetSwapFee = uint64(_factoryTargetSwapFee);

        emit FactoryFeesUpdated(_factoryMintFee, _factoryRandomRedeemFee, _factoryTargetRedeemFee, _factoryRandomSwapFee, _factoryTargetSwapFee);
    }

    function setVaultFees(
        uint256 vaultId,
        uint256 _mintFee,
        uint256 _randomRedeemFee,
        uint256 _targetRedeemFee,
        uint256 _randomSwapFee,
        uint256 _targetSwapFee
    ) public virtual override {
        if (msg.sender != owner()) {
            address vaultAddr = vaultManager.vault(vaultId);
            if (msg.sender != vaultAddr) revert NotVault();
        }
        if (_mintFee > 0.5 ether) revert FeeTooHigh();
        if (_randomRedeemFee > 0.5 ether) revert FeeTooHigh();
        if (_targetRedeemFee > 0.5 ether) revert FeeTooHigh();
        if (_randomSwapFee > 0.5 ether) revert FeeTooHigh();
        if (_targetSwapFee > 0.5 ether) revert FeeTooHigh();

        _vaultFees[vaultId] = VaultFees(
            true,
            uint64(_mintFee),
            uint64(_randomRedeemFee),
            uint64(_targetRedeemFee),
            uint64(_randomSwapFee),
            uint64(_targetSwapFee)
        );
        emit VaultFeesUpdated(vaultId, _mintFee, _randomRedeemFee, _targetRedeemFee, _randomSwapFee, _targetSwapFee);
    }

    function _deployVault(
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

        // Curator for configuration.
        FNFTCollection(newBeaconProxy).setCurator(msg.sender);
        // Owner for administrative functions.
        FNFTCollection(newBeaconProxy).transferOwnership(owner());
        return newBeaconProxy;
    }
}