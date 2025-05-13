pragma solidity ^0.8.4;

import "./IERC1155.sol";
import "./IERC1155Errors.sol";
import "./IERC1155Receiver.sol";
import "./IERC1155MetadataURI.sol";
import "./StorageERC1155.sol";
import "../../utils/introspection/ERC165.sol";
import "../../utils/misc/Arrays.sol";
import "../../utils/token/TransferHooks.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 */
abstract contract ERC1155 is TransferHooks, ERC165, IERC1155, IERC1155MetadataURI, IERC1155Errors {
    using Arrays for uint256[];
    using Arrays for address[];

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256 /* id */) public view virtual returns (string memory) {
        return StorageERC1155.data().uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     */
    function balanceOf(address account, uint256 id) public view virtual returns (uint256) {
        return StorageERC1155.data().balances[_getUserBalanceKey(id, account)];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual returns (uint256[] memory batchBalances) {
        if (accounts.length != ids.length) {
            revert ERC1155InvalidArrayLength(ids.length, accounts.length);
        }

        batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length;) {
            batchBalances[i] = StorageERC1155.data().balances[_getUserBalanceKey(ids.unsafeMemoryAccess(i), accounts.unsafeMemoryAccess(i))];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        if (operator == address(0)) {
            revert ERC1155InvalidOperator(address(0));
        }
        StorageERC1155.data().operatorApprovals[_getOperatorApprovalKey(msg.sender, operator)] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual returns (bool) {
        return StorageERC1155.data().operatorApprovals[_getOperatorApprovalKey(account, operator)];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public virtual {
        if (!(from == msg.sender || isApprovedForAll(from, msg.sender))) {
            revert ERC1155MissingApprovalForAll(msg.sender, from);
        } 

        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }

        _validateTransfer(msg.sender, from, to, id, value, 0);

        uint256 fromBalance = StorageERC1155.data().balances[_getUserBalanceKey(id, from)];
        if (fromBalance < value) {
            revert ERC1155InsufficientBalance(from, fromBalance, value, id);
        }
        unchecked {
            // Overflow not possible: value <= fromBalance
            StorageERC1155.data().balances[_getUserBalanceKey(id, from)] = fromBalance - value;
        }

        StorageERC1155.data().balances[_getUserBalanceKey(id, to)] += value;

        emit TransferSingle(msg.sender, from, to, id, value);

        if (_getCodeLengthAsm(to) > 0) {
            try IERC1155Receiver(to).onERC1155Received(msg.sender, from, id, value, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    // Tokens rejected
                    revert ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ERC1155InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual {
        if (ids.length != values.length) {
            revert ERC1155InvalidArrayLength(ids.length, values.length);
        }

        if (ids.length == 1) {
            safeTransferFrom(from, to, ids.unsafeMemoryAccess(0), values.unsafeMemoryAccess(0), data);
            return;
        }

        if (!(from == msg.sender || isApprovedForAll(from, msg.sender))) {
            revert ERC1155MissingApprovalForAll(msg.sender, from);
        }
        
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }

        uint256 id;
        uint256 value;

        for (uint256 i = 0; i < ids.length;) {
            id = ids.unsafeMemoryAccess(i);
            value = values.unsafeMemoryAccess(i);

            _validateTransfer(msg.sender, from, to, id, value, 0);

            uint256 fromBalance = StorageERC1155.data().balances[_getUserBalanceKey(id, from)];
            if (fromBalance < value) {
                revert ERC1155InsufficientBalance(from, fromBalance, value, id);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance
                StorageERC1155.data().balances[_getUserBalanceKey(id, from)] = fromBalance - value;
            }

            StorageERC1155.data().balances[_getUserBalanceKey(id, to)] += value;

            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, values);

        if (_getCodeLengthAsm(to) > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, from, ids, values, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    // Tokens rejected
                    revert ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ERC1155InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the values in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        StorageERC1155.data().uri = newuri;
    }

    /**
     * @dev Creates a `value` amount of tokens of type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }

        _validateMint(msg.sender, to, id, value, msg.value);
        
        StorageERC1155.data().balances[_getUserBalanceKey(id, to)] += value;
        emit TransferSingle(msg.sender, address(0), to, id, value);

        if (_getCodeLengthAsm(to) > 0) {
            try IERC1155Receiver(to).onERC1155Received(msg.sender, address(0), id, value, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    // Tokens rejected
                    revert ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ERC1155InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `values` must have the same length.
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal {
        if (ids.length != values.length) {
            revert ERC1155InvalidArrayLength(ids.length, values.length);
        }

        if (ids.length == 1) {
            _mint(to, ids.unsafeMemoryAccess(0), values.unsafeMemoryAccess(0), data);
            return;
        }

        if (to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }

        uint256 id;
        uint256 value;

        for (uint256 i = 0; i < ids.length;) {
            id = ids.unsafeMemoryAccess(i);
            value = values.unsafeMemoryAccess(i);

            _validateMint(msg.sender, to, id, value, msg.value);

            StorageERC1155.data().balances[_getUserBalanceKey(id, to)] += value;

            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, values);

        if (_getCodeLengthAsm(to) > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, values, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    // Tokens rejected
                    revert ERC1155InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ERC1155InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev Destroys a `value` amount of tokens of type `id` from `from`
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `value` amount of tokens of type `id`.
     */
    function _burn(address from, uint256 id, uint256 value) internal {
        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }

        _validateBurn(msg.sender, from, id, value, msg.value);

        uint256 fromBalance = StorageERC1155.data().balances[_getUserBalanceKey(id, from)];
        if (fromBalance < value) {
            revert ERC1155InsufficientBalance(from, fromBalance, value, id);
        }
        unchecked {
            // Overflow not possible: value <= fromBalance
            StorageERC1155.data().balances[_getUserBalanceKey(id, from)] = fromBalance - value;
        }

        emit TransferSingle(msg.sender, from, address(0), id, value);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `value` amount of tokens of type `id`.
     * - `ids` and `values` must have the same length.
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory values) internal {
        if (ids.length != values.length) {
            revert ERC1155InvalidArrayLength(ids.length, values.length);
        }

        if (ids.length == 1) {
            _burn(from, ids.unsafeMemoryAccess(0), values.unsafeMemoryAccess(0));
            return;
        }

        if (from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }

        uint256 id;
        uint256 value;

        for (uint256 i = 0; i < ids.length;) {
            id = ids.unsafeMemoryAccess(i);
            value = values.unsafeMemoryAccess(i);

            _validateBurn(msg.sender, from, id, value, msg.value);

            uint256 fromBalance = StorageERC1155.data().balances[_getUserBalanceKey(id, from)];
            if (fromBalance < value) {
                revert ERC1155InsufficientBalance(from, fromBalance, value, id);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance
                StorageERC1155.data().balances[_getUserBalanceKey(id, from)] = fromBalance - value;
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, address(0), ids, values);
    }

    /**
     * @dev Internal function used to efficiently retrieve the code length of `account`.
     * 
     * @param account The address to get the deployed code length for.
     * 
     * @return length The length of deployed code at the address.
     */
    function _getCodeLengthAsm(address account) internal view returns (uint256 length) {
        assembly { length := extcodesize(account) }
    }

    function _getUserBalanceKey(uint256 tokenId_, address account_) internal pure returns (bytes32 key) {
        assembly {
            mstore(0x00, tokenId_)
            mstore(0x20, account_)
            key := keccak256(0x00, 0x40)
        }
    }

    function _getOperatorApprovalKey(address owner_, address operator_) internal pure returns (bytes32 key) {
        assembly {
            mstore(0x00, owner_)
            mstore(0x20, operator_)
            key := keccak256(0x00, 0x40)
        }
    }
}