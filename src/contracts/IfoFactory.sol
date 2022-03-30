
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./InitializedProxy.sol";
import "./IFO.sol";
import "./interfaces/IFNFT.sol";

contract IFOFactory is Ownable, Pausable {
  /// @notice the number of ERC721 vaults
  uint256 public vaultCount;

  /// @notice the mapping of vault number to vault contract
  mapping(uint256 => address) public vaults;

  /// @notice a settings contract controlled by governance
  address public immutable settings;
  /// @notice the TokenVault logic contract
  address public immutable logic;

  event IfoCreated(
    address _IFO,
    address _FNFT,
    uint256 _amountForSale,
    uint256 _price,
    uint256 _cap,
    bool _allowWhitelisting
  );

  error AlreadyExists();

  constructor(address _ifoSettings) {
    settings = _ifoSettings;
    logic = address(new IFO(_ifoSettings));
  }

  /// @notice the function to create a ifo
  /// @param _FNFT the desired name of the vault
  /// @param _amountForSale the desired sumbol of the vault
  /// @param _price the ERC721 token address fo the NFT
  /// @param _cap the uint256 ID of the token
  /// @param _allowWhitelisting the initial price of the NFT
  function create(
    address _FNFT,
    uint256 _amountForSale,
    uint256 _price,
    uint256 _cap,
    bool _allowWhitelisting
  ) external whenNotPaused {
    bytes memory _initializationCalldata =
      abi.encodeWithSignature(
        "initialize(address,uint256,uint256,uint256,bool)",
        _FNFT,
        _amountForSale,
        _price,
        _cap,
        _allowWhitelisting
    );

    address _IFO = address(
      new InitializedProxy(
        logic,
        _initializationCalldata
      )
    );

    emit IfoCreated(
        _IFO,
        _FNFT,
        _amountForSale,
        _price,
        _cap,
        _allowWhitelisting
    );
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }
}