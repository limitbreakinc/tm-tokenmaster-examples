pragma solidity ^0.8.4;

import "./ERC721.sol";
import "../../utils/token/AutomaticValidatorTransferApproval.sol";
import "../../utils/token/CreatorTokenBase.sol";
import "../../utils/token/Constants.sol";

abstract contract ERC721CBase is ERC721, CreatorTokenBase, AutomaticValidatorTransferApproval {
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) { }

    /**
     * @notice Overrides behavior of isApprovedFor all such that if an operator is not explicitly approved
     *         for all, the contract owner can optionally auto-approve the 721-C transfer validator for transfers.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool isApproved) {
        isApproved = super.isApprovedForAll(owner, operator);

        if (!isApproved) {
            if (storageAutomaticValidatorTransferApproval().autoApproveTransfersFromValidator) {
                isApproved = operator == address(getTransferValidator());
            }
        }
    }

    /**
     * @notice Indicates whether the contract implements the specified interface.
     * @dev Overrides supportsInterface in ERC165.
     * @param interfaceId The interface id
     * @return true if the contract implements the specified interface, false otherwise
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return 
        interfaceId == type(ICreatorToken).interfaceId || 
        interfaceId == type(ICreatorTokenLegacy).interfaceId || 
        super.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called 
     * @notice for transaction simulation. 
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    function _validateTransfer(
        address caller, 
        address from, 
        address to, 
        uint256 tokenId, 
        uint256 value
    ) internal virtual override {
        _preValidateTransfer(caller, from, to, tokenId, value);
    }

    function _tokenType() internal pure override returns(uint16) {
        return uint16(TOKEN_TYPE_ERC721);
    }
}

/**
 * @title ERC721C
 * @author Limit Break, Inc.
 * @notice Extends OpenZeppelin's ERC721 implementation with Creator Token functionality, which
 *         allows the contract owner to update the transfer validation logic by managing a security policy in
 *         an external transfer validation security policy registry.  See {CreatorTokenTransferValidator}.
 */
abstract contract ERC721C is ERC721CBase {
    constructor(string memory name_, string memory symbol_) ERC721CBase(name_, symbol_) { }
}

abstract contract ERC721CInitializable is ERC721CBase {
    struct StorageERC721Initializable {
        bool erc721Initialized;
    }

    bytes32 private constant ERC721_INITIALIZABLE_STORAGE_SLOT = keccak256("storage.ERC721Initializable");
    
    function storageERC721Initializable() internal pure returns (StorageERC721Initializable storage ptr) {
        bytes32 slot = ERC721_INITIALIZABLE_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }

    error ERC721OpenZeppelinInitializable__AlreadyInitializedERC721();

    constructor() ERC721CBase("", "") { }

    /// @dev Initializes parameters of ERC721 tokens.
    /// These cannot be set in the constructor because this contract is optionally compatible with EIP-1167.
    function initializeERC721(string memory name_, string memory symbol_) public virtual {
        _requireCallerIsContractOwner();

        if(storageERC721Initializable().erc721Initialized) {
            revert ERC721OpenZeppelinInitializable__AlreadyInitializedERC721();
        }

        storageERC721Initializable().erc721Initialized = true;

        StorageERC721.data().name = name_;
        StorageERC721.data().symbol = symbol_;

        _emitDefaultTransferValidator();
        _registerTokenType(getTransferValidator());
    }
}