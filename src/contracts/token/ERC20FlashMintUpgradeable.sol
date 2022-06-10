// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/extensions/ERC20FlashMint.sol)

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC3156FlashBorrowerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC3156FlashLenderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ERC20Upgradeable.sol";

/**
 * @dev Implementation of the ERC3156 Flash loans extension, as defined in
 * https://eips.ethereum.org/EIPS/eip-3156[ERC-3156].
 *
 * Adds the {flashLoan} method, which provides flash loan support at the token
 * level. By default there is no fee, but this can be changed by overriding {flashFee}.
 *
 * _Available since v4.1._
 */
abstract contract ERC20FlashMintUpgradeable is Initializable, ERC20Upgradeable, IERC3156FlashLenderUpgradeable {
    function __ERC20FlashMint_init() internal onlyInitializing {
    }

    function __ERC20FlashMint_init_unchained() internal onlyInitializing {
    }
    bytes32 private constant _ON_RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error ExceedsMaxFlashLoan();
    error FlashLoanNotRepaid();
    error InvalidFlashLoanReturnValue();

    /**
     * @dev Returns the maximum amount of tokens available for loan.
     * @param token The address of the token that is requested.
     * @return The amont of token that can be loaned.
     */
    function maxFlashLoan(address token) public view virtual override returns (uint256) {
        return token == address(this) ? type(uint256).max - ERC20Upgradeable.totalSupply() : 0;
    }

    function _flashLoan(
        IERC3156FlashBorrowerUpgradeable receiver,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) internal returns (bool) {
        if (amount > maxFlashLoan(token)) revert ExceedsMaxFlashLoan();

        _mint(address(receiver), amount);
        if (receiver.onFlashLoan(msg.sender, token, amount, fee, data) != _ON_RETURN_VALUE) revert InvalidFlashLoanReturnValue();
        uint256 currentAllowance = allowance(address(receiver), address(this));
        if (amount + fee > currentAllowance) revert FlashLoanNotRepaid();

        _approve(address(receiver), address(this), currentAllowance - amount - fee);

        _burn(address(receiver), amount);
        _chargeAndDistributeFees(address(receiver), fee);

        return true;
    }

    function _chargeAndDistributeFees(address user, uint256 amount) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
