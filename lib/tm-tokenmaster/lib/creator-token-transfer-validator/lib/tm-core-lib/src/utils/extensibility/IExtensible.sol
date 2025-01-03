pragma solidity ^0.8.4;

interface IExtensible {
    event ExtensionInstalled(address indexed extensionAddress);
    event ExtensionUninstalled(address indexed extensionAddress);
    event ExtensionSelectorInstalled(address indexed extensionAddress, bytes4 indexed selector);
    event ExtensionSelectorUninstalled(address indexed extensionAddress, bytes4 indexed selector);

    function installExtensions(address[] calldata /*extensionAddresses*/) external;
    function uninstallExtensions(address[] calldata /*extensionAddresses*/) external;

    function isExtensionInstalled(address /*extensionAddress*/) external view returns (bool);

    function extensibleTypes() external view returns (uint256[] memory);
}