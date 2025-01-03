pragma solidity ^0.8.4;

import "./OwnablePermissions.sol";
import "./Ownable2Step.sol";

abstract contract Ownable2StepInitializable is OwnablePermissions, Ownable2Step {
    struct StorageOwnableInitializable {
        bool ownerInitialized;
    }

    bytes32 private constant OWNABLE_INITIALIZABLE_STORAGE_SLOT = keccak256("storage.Ownable.Initializable");
    
    function storageOwnableInitializable() internal pure returns (StorageOwnableInitializable storage ptr) {
        bytes32 slot = OWNABLE_INITIALIZABLE_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }

    error OwnableInitializable__OwnerAlreadyInitialized();

    /**
     * @dev When EIP-1167 is used to clone a contract that inherits Ownable permissions,
     * this is required to assign the initial contract owner, as the constructor is
     * not called during the cloning process.
     */
    function initializeOwner(address owner_) public {
      if (owner() != address(0) || storageOwnableInitializable().ownerInitialized) {
          revert OwnableInitializable__OwnerAlreadyInitialized();
      }

      _transferOwnership(owner_);
      storageOwnableInitializable().ownerInitialized = true;
    }

    function renounceOwnership() public override {
        super.renounceOwnership();

        // Ensure _ownerInitialized flag is true to prevent recapture of ownership.
        storageOwnableInitializable().ownerInitialized = true;
    }

    function _requireCallerIsContractOwner() internal view virtual override {
        _checkOwner();
    }
}