pragma solidity ^0.8.4;

import "./IERC721.sol";
import "./IERC721Errors.sol";
import "./IERC721Receiver.sol";
import "./IERC721Metadata.sol";
import "./StorageERC721.sol";
import "../../utils/introspection/ERC165.sol";
import "../../utils/misc/Strings.sol";
import "../../utils/token/TransferHooks.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
abstract contract ERC721 is TransferHooks, ERC165, IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        StorageERC721.data().name = name_;
        StorageERC721.data().symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return StorageERC721.data().balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address owner_) {
        owner_ = StorageERC721.data().owners[tokenId];
        if (owner_ == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual returns (string memory) {
        return StorageERC721.data().name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual returns (string memory) {
        return StorageERC721.data().symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        address owner_ = StorageERC721.data().owners[tokenId];
        if (owner_ == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual {
        address owner_ = StorageERC721.data().owners[tokenId];
            
        if (owner_ == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        } 

        if (owner_ != msg.sender) {
            if (!isApprovedForAll(owner_, msg.sender)) {
                revert ERC721InvalidApprover(msg.sender);
            }
        }

        emit Approval(owner_, to, tokenId);
        StorageERC721.data().tokenApprovals[tokenId] = to;
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        if (StorageERC721.data().owners[tokenId] == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }

        return StorageERC721.data().tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        StorageERC721.data().operatorApprovals[_getOperatorApprovalKey(msg.sender, operator)] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return StorageERC721.data().operatorApprovals[_getOperatorApprovalKey(owner, operator)];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        
        address previousOwner = StorageERC721.data().owners[tokenId];
        
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }

        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }

        _validateTransfer(msg.sender, from, to, tokenId, 0);

        if (from == msg.sender ||
            isApprovedForAll(from, msg.sender) ||
            StorageERC721.data().tokenApprovals[tokenId] == msg.sender) {
            
            // Clear approval. No need to re-authorize or emit the Approval event
            StorageERC721.data().tokenApprovals[tokenId] = address(0);
    
            unchecked {
                --StorageERC721.data().balances[from];
                ++StorageERC721.data().balances[to];
            }
    
            StorageERC721.data().owners[tokenId] = to;
            emit Transfer(from, to, tokenId);
        } else {
            revert ERC721InsufficientApproval(msg.sender, tokenId);
        }
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Mints `tokenId`, transfers it to `to` and checks for `to` acceptance.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, data);
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }

        if (StorageERC721.data().owners[tokenId] != address(0)) {
            revert ERC721InvalidSender(address(0));
        }

        _validateMint(msg.sender, to, tokenId, msg.value);

        unchecked {
            ++StorageERC721.data().balances[to];
        }

        StorageERC721.data().owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address from = StorageERC721.data().owners[tokenId];
        if (from == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }

        _validateBurn(msg.sender, from, tokenId, msg.value);

        // Clear approval. No need to re-authorize or emit the Approval event
        StorageERC721.data().tokenApprovals[tokenId] = address(0);

        unchecked {
            --StorageERC721.data().balances[from];
        }

        StorageERC721.data().owners[tokenId] = address(0);
        emit Transfer(from, address(0), tokenId);
    }

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target address. This will revert if the
     * recipient doesn't accept the token transfer. The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
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