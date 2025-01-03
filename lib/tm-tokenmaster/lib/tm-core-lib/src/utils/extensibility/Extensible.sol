pragma solidity ^0.8.4;

import "./IExtensible.sol";
import "./IExtension.sol";
import "./IExtensionRegistry.sol";
import "../Errors.sol";
import "../access/OwnablePermissions.sol";
import "../structs/EnumerableSet.sol";

abstract contract Extensible is OwnablePermissions, IExtensible {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct ExtensibleStorage {
        EnumerableSet.AddressSet installedExtensions;
        mapping (bytes4 selector => address extension) extensionBySelector;
    }

    bytes32 private constant EXTENSIBLE_STORAGE_SLOT = keccak256("storage.Extensible");
    
    IExtensionRegistry private constant EXTENSION_REGISTRY = IExtensionRegistry(address(0x1234567890ABCDEF));

    function extensibleStorage() internal pure returns (ExtensibleStorage storage ptr) {
        bytes32 slot = EXTENSIBLE_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }

    function installExtensions(address[] calldata extensionAddresses) external {
        _requireCallerIsContractOwner();

        ExtensibleStorage storage s = extensibleStorage();

        for (uint256 i = 0; i < extensionAddresses.length; ++i) {
            _installExtension(s, extensionAddresses[i]);
        }
    }

    function uninstallExtensions(address[] calldata extensionAddresses) external {
        _requireCallerIsContractOwner();

        ExtensibleStorage storage s = extensibleStorage();

        for (uint256 i = 0; i < extensionAddresses.length; ++i) {
            _uninstallExtension(s, extensionAddresses[i]);
        }
    }

    function isExtensionInstalled(address extensionAddress) external view returns (bool) {
        return extensibleStorage().installedExtensions.contains(extensionAddress);
    }

    function extensibleTypes() external view virtual returns (uint256[] memory);

    fallback() external payable virtual {
        _fallback();
    }

    function _fallback() internal virtual {
        _delegate(_getExtensionBySelectorOrRevert());
    }

    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function _getExtensionBySelectorOrRevert() internal view returns (address extension) {
        extension = extensibleStorage().extensionBySelector[msg.sig];
        if (extension == address(0)) {
            revert Extensible__ExtensionNotInstalled();
        }
    }

    function _requireIsValidExtension(address extensionAddress) private view {
        if (!EXTENSION_REGISTRY.isValidExtensionForExtensibleContract(address(this), extensionAddress)) {
            revert Extensible__InvalidExtension();
        }
    }

    function _installExtension(ExtensibleStorage storage s, address extensionAddress) private {
        _requireIsValidExtension(extensionAddress);

        if (s.installedExtensions.add(extensionAddress)) { 
            emit ExtensionInstalled(extensionAddress);

            bytes4[] memory selectors = IExtension(extensionAddress).selectorManifest();
            bytes4 selector;
            for (uint256 i = 0; i < selectors.length; ++i) {
                selector = selectors[i];
                
                if (s.extensionBySelector[selector] != address(0)) {
                    revert Extensible__ConflictingFunctionSelectorAlreadyInstalled();
                }
    
                s.extensionBySelector[selector] = extensionAddress;
                emit ExtensionSelectorInstalled(extensionAddress, selector);
            }
        } else {
            revert Extensible__ExtensionAlreadyInstalled(); 
        }
    }

    function _uninstallExtension(ExtensibleStorage storage s, address extensionAddress) private {
        if (s.installedExtensions.remove(extensionAddress)) {
            emit ExtensionUninstalled(extensionAddress);

            bytes4[] memory selectors = IExtension(extensionAddress).selectorManifest();
            bytes4 selector;
            for (uint256 i = 0; i < selectors.length; ++i) {
                selector = selectors[i];
                s.extensionBySelector[selector] = address(0);
                emit ExtensionSelectorUninstalled(extensionAddress, selector);
            }
        } else {
            revert Extensible__ExtensionNotInstalled();
        }
    }
}