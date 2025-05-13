// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ITrustedForwarderFactory {
    error TrustedForwarderFactory__TrustedForwarderInitFailed(address admin, address appSigner);

    event TrustedForwarderCreated(address indexed trustedForwarder);

    function cloneTrustedForwarder(address admin, address appSigner, bytes32 salt)
        external
        returns (address trustedForwarder);
    function forwarders(address) external view returns (bool);
    function isTrustedForwarder(address sender) external view returns (bool);
    function trustedForwarderImplementation() external view returns (address);
}