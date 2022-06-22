//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interfaces/IVaultManager.sol";
import "./interfaces/IFeeDistributor.sol";

contract VaultManager is
    OwnableUpgradeable,
    PausableUpgradeable,
    IVaultManager
{    
    mapping(address => bool) public override excludedFromFees;

    address[] public override vaults;

    address public override fnftSingleFactory;

    address public override fnftCollectionFactory;

    address public override feeDistributor;

    address public override WETH;

    address public override priceOracle;

    address public override ifoFactory;

    address public override zapContract;

    /// @notice the address who receives auction fees
    address payable public override feeReceiver;

    function initialize(
        address _fnftSingleFactory,
        address _fnftCollectionFactory, 
        address _weth, 
        address _ifoFactory, 
        address _feeDistributor
    ) external initializer {
        __Ownable_init();
        __Pausable_init();

        fnftSingleFactory = _fnftSingleFactory;
        fnftCollectionFactory = _fnftCollectionFactory;
        WETH = _weth;
        ifoFactory = _ifoFactory;
        feeDistributor = _feeDistributor;
        feeReceiver = payable(msg.sender);        
    }

    function togglePaused() external onlyOwner {
        paused() ? _unpause() : _pause();
    }

    function setPriceOracle(address _newOracle) external override onlyOwner {
        emit UpdatePriceOracle(priceOracle, _newOracle);
        priceOracle = _newOracle;
    }


    function setFeeDistributor(address _feeDistributor) public override onlyOwner {
        if (_feeDistributor == address(0)) revert ZeroAddressDisallowed();
        emit NewFeeDistributor(feeDistributor, _feeDistributor);
        feeDistributor = _feeDistributor;
    }

    function setFeeExclusion(address _excludedAddr, bool excluded) public override onlyOwner {
        emit FeeExclusion(_excludedAddr, excluded);
        excludedFromFees[_excludedAddr] = excluded;
    }

    function setFeeReceiver(address payable _receiver) external override onlyOwner {
        if (_receiver == address(0)) revert ZeroAddressDisallowed();
        emit UpdateFeeReceiver(feeReceiver, _receiver);
        feeReceiver = _receiver;
    }

    function setZapContract(address _zapContract) external override onlyOwner {
        if (_zapContract == address(0)) revert ZeroAddressDisallowed();
        emit UpdateZapContract(zapContract, _zapContract);
        zapContract = _zapContract;
    }

    function setVault(address _fnft) external override returns (uint256 vaultId) {
        if (_fnft == address(0)) revert ZeroAddressDisallowed();
        if (msg.sender != fnftCollectionFactory && msg.sender != fnftSingleFactory) revert OnlyFactory();
        vaultId = vaults.length;
        vaults.push(_fnft);
        emit VaultSet(vaultId, _fnft);
    }

    function vault(uint256 vaultId) external view override returns (address) {
        return vaults[vaultId];
    }

    function numVaults() external view override returns (uint) {
        return vaults.length;
    }
    
    function initializeVaultReceivers(uint256 _vaultId) external override {         
        if (address(feeDistributor) == address(0)) revert ZeroAddressDisallowed();
        if (msg.sender != fnftCollectionFactory && msg.sender != fnftSingleFactory) revert OnlyFactory();
        IFeeDistributor(feeDistributor).initializeVaultReceivers(_vaultId);
    }
}