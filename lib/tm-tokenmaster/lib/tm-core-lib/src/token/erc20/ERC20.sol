// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.4;

import "./IERC20.sol";
import "./IERC20Metadata.sol";
import "./IERC20Errors.sol";
import "./StorageERC20.sol";
import "../../utils/token/TransferHooks.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20 is TransferHooks, IERC20, IERC20Metadata, IERC20Errors {
    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        StorageERC20.data().name = name_;
        StorageERC20.data().symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return StorageERC20.data().name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return StorageERC20.data().symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return StorageERC20.data().totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return StorageERC20.data().balances[account];
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return StorageERC20.data().allowances[_getAllowanceKey(owner, spender)];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }

        StorageERC20.data().allowances[_getAllowanceKey(msg.sender, spender)] = value;
        emit Approval(msg.sender, spender, value);

        return true;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _validateTransfer(msg.sender, msg.sender, to, 0, value, 0);
        
        uint256 fromBalance = StorageERC20.data().balances[msg.sender];
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(msg.sender, fromBalance, value);
        }
        unchecked {
            // Overflow not possible: value <= fromBalance <= totalSupply.
            StorageERC20.data().balances[msg.sender] = fromBalance - value;

            // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
            StorageERC20.data().balances[to] += value;
        }

        emit Transfer(msg.sender, to, value);

        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }

        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        uint256 currentAllowance = allowance(from, msg.sender);

        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(msg.sender, currentAllowance, value);
            }
    
            unchecked {
                StorageERC20.data().allowances[_getAllowanceKey(from, msg.sender)] = currentAllowance - value;
            }
        }

        _validateTransfer(msg.sender, from, to, 0, value, 0);

        uint256 fromBalance = StorageERC20.data().balances[from];
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(from, fromBalance, value);
        }

        unchecked {
            // Overflow not possible: value <= fromBalance <= totalSupply.
            StorageERC20.data().balances[from] = fromBalance - value;

            // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
            StorageERC20.data().balances[to] += value;
        }

        emit Transfer(from, to, value);

        return true;
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     */
    function _mint(address to, uint256 value) internal {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        _validateMint(msg.sender, to, 0, value, msg.value);

        // Overflow check required: The rest of the code assumes that totalSupply never overflows
        StorageERC20.data().totalSupply += value;

        unchecked {
            // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
            StorageERC20.data().balances[to] += value;
        }

        emit Transfer(address(0), to, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     */
    function _burn(address from, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        
        _validateBurn(msg.sender, from, 0, value, msg.value);

        uint256 fromBalance = StorageERC20.data().balances[from];
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(from, fromBalance, value);
        }
        
        unchecked {
            // Overflow not possible: value <= fromBalance <= totalSupply.
            StorageERC20.data().balances[from] = fromBalance - value;

            // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
            StorageERC20.data().totalSupply -= value;
        }

        emit Transfer(from, address(0), value);
    }

    function _getAllowanceKey(address owner, address spender) internal pure returns (bytes32 key) {
        assembly {
            mstore(0x00, owner)
            mstore(0x20, spender)
            key := keccak256(0x00, 0x40)
        }
    }
}