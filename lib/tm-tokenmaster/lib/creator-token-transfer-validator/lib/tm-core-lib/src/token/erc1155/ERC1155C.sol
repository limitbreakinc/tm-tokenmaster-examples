pragma solidity ^0.8.4;

import "./ERC1155.sol";
import "../../utils/token/AutomaticValidatorTransferApproval.sol";
import "../../utils/token/CreatorTokenBase.sol";
import "../../utils/token/Constants.sol";

abstract contract ERC1155CBase is ERC1155, CreatorTokenBase, AutomaticValidatorTransferApproval {
    constructor(string memory uri_) ERC1155(uri_) { }

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
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256,uint256)"));
        isViewFunction = false;
    }

    function _validateTransfer(
        address caller, 
        address from, 
        address to, 
        uint256 tokenId, 
        uint256 amount,
        uint256 value
    ) internal virtual override {
        _preValidateTransfer(caller, from, to, tokenId, amount, value);
    }

    function _tokenType() internal pure override returns(uint16) {
        return uint16(TOKEN_TYPE_ERC1155);
    }
}

/**
 * @title ERC1155C
 * @author Limit Break, Inc.
 * @notice Extends OpenZeppelin's ERC1155 implementation with Creator Token functionality, which
 *         allows the contract owner to update the transfer validation logic by managing a security policy in
 *         an external transfer validation security policy registry.  See {CreatorTokenTransferValidator}.
 */
abstract contract ERC1155C is ERC1155CBase {
    constructor(string memory uri_) ERC1155CBase(uri_) { }
}

abstract contract ERC1155CInitializable is ERC1155CBase {
    struct StorageERC1155Initializable {
        bool erc1155Initialized;
    }

    bytes32 private constant ERC1155_INITIALIZABLE_STORAGE_SLOT = keccak256("storage.ERC1155Initializable");
    
    function storageERC1155Initializable() internal pure returns (StorageERC1155Initializable storage ptr) {
        bytes32 slot = ERC1155_INITIALIZABLE_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }

    error ERC1155OpenZeppelinInitializable__AlreadyInitializedERC1155();

    constructor() ERC1155CBase("") { }


    function initializeERC1155(string memory uri_) public virtual {
        _requireCallerIsContractOwner();

        if(storageERC1155Initializable().erc1155Initialized) {
            revert ERC1155OpenZeppelinInitializable__AlreadyInitializedERC1155();
        }

        storageERC1155Initializable().erc1155Initialized = true;

        _setURI(uri_);
        _emitDefaultTransferValidator();
        _registerTokenType(getTransferValidator());
    }
}