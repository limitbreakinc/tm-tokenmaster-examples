pragma solidity ^0.8.4;

struct ExtensionRegistration {
    uint256 extensibleType;
    address extensionAddress;
}

interface IExtensionRegistry {
    event ExtensionRegistered(uint256 indexed extensibleType, address indexed extensionAddress);
    event ExtensionUnregistered(uint256 indexed extensibleType, address indexed extensionAddress);

    function registerExtensions(ExtensionRegistration[] calldata registrations) external;
    function unregisterExtensions(ExtensionRegistration[] calldata registrations) external;
    
    function getExtensionsForType(uint256 /*extensibleType*/) external view returns (address[] memory);
    function isValidExtensionForExtensibleContract(address /*extensibleAddress*/, address /*extensionAddress*/) external view returns (bool);
    function isValidExtensionForType(uint256 /*extensibleType*/, address /*extensionAddress*/) external view returns (bool);
}