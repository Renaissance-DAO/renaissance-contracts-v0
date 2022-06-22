//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interfaces/IVaultManager.sol";

contract VaultManager is
    OwnableUpgradeable,
    PausableUpgradeable,
    IVaultManager
{    
    mapping(address => bool) public override excludedFromFees;

    mapping(uint256 => address) public override vaults;

    address public override fnftSingleFactory;

    address public override fnftCollectionFactory;

    address public override feeDistributor;

    address public override WETH;

    address public override priceOracle;

    address public override ifoFactory;

    uint256 public override numVaults;    

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

    function setPriceOracle(address _newOracle) external onlyOwner {
        emit UpdatePriceOracle(priceOracle, _newOracle);
        priceOracle = _newOracle;
    }


    function setFeeDistributor(address _feeDistributor) public onlyOwner override {
        if (_feeDistributor == address(0)) revert ZeroAddressDisallowed();
        emit NewFeeDistributor(feeDistributor, _feeDistributor);
        feeDistributor = _feeDistributor;
    }

    function setFeeExclusion(address _excludedAddr, bool excluded) public onlyOwner override {
        emit FeeExclusion(_excludedAddr, excluded);
        excludedFromFees[_excludedAddr] = excluded;
    }

    function setFeeReceiver(address payable _receiver) external onlyOwner {
        if (_receiver == address(0)) revert ZeroAddressDisallowed();

        emit UpdateFeeReceiver(feeReceiver, _receiver);

        feeReceiver = _receiver;
    }

    function setVault(uint256 _vaultId, address _fnft) external override {
        if (_fnft == address(0)) revert ZeroAddressDisallowed();
        if (msg.sender != fnftCollectionFactory && msg.sender != fnftSingleFactory) revert OnlyFactory();

        emit VaultSet(_vaultId, _fnft);

        vaults[_vaultId] = _fnft;
    }

    function vault(uint256 vaultId) external view override returns (address) {
        return vaults[vaultId];
    }
}
