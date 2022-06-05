// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "./interfaces/IFeeDistributor.sol";
import "./proxy/BeaconProxy.sol";
import "./proxy/BeaconUpgradeable.sol";

// Authors: @0xKiwi_ and @alexgausman.

contract FNFTCollectionSettings is BeaconUpgradeable {
    address public override zapContract; // No longer needed, but keeping for compatibility.
    address public override feeDistributor;
    address public override eligibilityManager;

    // v1.0.1
    mapping(address => bool) public override excludedFromFees;

    // v1.0.2
    struct VaultFees {
        bool active;
        uint64 mintFee;
        uint64 randomRedeemFee;
        uint64 targetRedeemFee;
        uint64 randomSwapFee;
        uint64 targetSwapFee;
    }
    mapping(uint256 => VaultFees) private _vaultFees;
    uint64 public override factoryMintFee;
    uint64 public override factoryRandomRedeemFee;
    uint64 public override factoryTargetRedeemFee;
    uint64 public override factoryRandomSwapFee;
    uint64 public override factoryTargetSwapFee;

    error FeeTooHigh();
    error CallerIsNotVault();
    error ZeroAddress();

    function initialize(address _vaultImpl, address _feeDistributor) public override initializer {
        __Pausable_init();
        // We use a beacon proxy so that every child contract follows the same implementation code.
        __BeaconUpgradeable__init(_vaultImpl);
        setFeeDistributor(_feeDistributor);
        setFactoryFees(0.1 ether, 0.05 ether, 0.1 ether, 0.05 ether, 0.1 ether);
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
            address vaultAddr = vaults[vaultId];
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
            address vaultAddr = vaults[vaultId];
            if (msg.sender != vaultAddr) revert CallerIsNotVault();
        }
        delete _vaultFees[vaultId];
        emit DisableVaultFees(vaultId);
    }

    function setFeeDistributor(address _feeDistributor) public onlyOwner virtual override {
        if (_feeDistributor == address(0)) revert ZeroAddress();
        emit NewFeeDistributor(feeDistributor, _feeDistributor);
        feeDistributor = _feeDistributor;
    }

    function setZapContract(address _zapContract) public onlyOwner virtual override {
        emit NewZapContract(zapContract, _zapContract);
        zapContract = _zapContract;
    }

    function setFeeExclusion(address _excludedAddr, bool excluded) public onlyOwner virtual override {
        emit FeeExclusion(_excludedAddr, excluded);
        excludedFromFees[_excludedAddr] = excluded;
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
}
