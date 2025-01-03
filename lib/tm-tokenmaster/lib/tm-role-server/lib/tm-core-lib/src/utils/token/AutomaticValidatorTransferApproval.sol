// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../access/OwnablePermissions.sol";

/**
 * @title AutomaticValidatorTransferApproval
 * @author Limit Break, Inc.
 * @notice Base contract mix-in that provides boilerplate code giving the contract owner the
 *         option to automatically approve a 721-C transfer validator implementation for transfers.
 */
abstract contract AutomaticValidatorTransferApproval is OwnablePermissions {
    struct StorageAutomaticValidatorTransferApproval {
        bool autoApproveTransfersFromValidator;
    }

    bytes32 private constant AUTOMATIC_VALIDATOR_TRANSFER_APPROVAL_STORAGE_SLOT = keccak256("storage.AutomaticValidatorTransferApproval");
    
    function storageAutomaticValidatorTransferApproval() internal pure returns (StorageAutomaticValidatorTransferApproval storage ptr) {
        bytes32 slot = AUTOMATIC_VALIDATOR_TRANSFER_APPROVAL_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }

    /// @dev Emitted when the automatic approval flag is modified by the creator.
    event AutomaticApprovalOfTransferValidatorSet(bool autoApproved);

    /**
     * @notice Sets if the transfer validator is automatically approved as an operator for all token owners.
     * 
     * @dev    Throws when the caller is not the contract owner.
     * 
     * @param autoApprove If true, the collection's transfer validator will be automatically approved to
     *                    transfer holder's tokens.
     */
    function setAutomaticApprovalOfTransfersFromValidator(bool autoApprove) external {
        _requireCallerIsContractOwner();
        storageAutomaticValidatorTransferApproval().autoApproveTransfersFromValidator = autoApprove;
        emit AutomaticApprovalOfTransferValidatorSet(autoApprove);
    }

    function autoApproveTransfersFromValidator() public view returns (bool) {
        return storageAutomaticValidatorTransferApproval().autoApproveTransfersFromValidator;
    }
}