pragma solidity ^0.8.4;

interface IExtension {
    function selectorManifest() external pure returns (bytes4[] memory);
}