// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/Clones.sol";

contract TrustedForwarderFactory {

    error TrustedForwarderFactory__TrustedForwarderInitFailed(address admin, address appSigner);

    event TrustedForwarderCreated(address indexed creator, address indexed trustedForwarder);

    // keccak256("__TrustedForwarder_init(address,address)")
    bytes4 constant private INIT_SELECTOR = 0x81ab13d7;
    address immutable public trustedForwarderImplementation;

    mapping(address => bool) public forwarders;

    constructor(address trustedForwarderImplementation_) {
        trustedForwarderImplementation = trustedForwarderImplementation_;
    }

    /**
     * @notice Returns true if the sender is a trusted forwarder, false otherwise.
     * @notice Addresses are added to the `forwarders` mapping when they are cloned via the `cloneTrustedForwarder` function.
     *
     * @dev    This function allows for the TrustedForwarder contracts to be used as trusted forwarders within the TrustedForwarderERC2771Context mixin.
     * 
     * @param sender The address to check.
     * @return True if the sender is a trusted forwarder, false otherwise.
     */
    function isTrustedForwarder(address sender) external view returns (bool) {
        return forwarders[sender];
    }

    /**
     * @notice Clones the TrustedForwarder implementation and initializes it.
     *
     * @dev    To prevent hostile deployments, we hash the sender's address with the salt to create the final salt.
     * @dev    This prevents the mining of specific contract addresses for deterministic deployments, but still allows for
     * @dev    a canonical address to be created for each sender.
     *
     * @param admin             The address to assign the admin role to.
     * @param appSigner         The address to assign the app signer role to. This will be ignored if `enableAppSigner` is false.
     * @param salt              The salt to use for the deterministic deployment.  This is hashed with the sender's address to create the final salt.
     *
     * @return trustedForwarder The address of the newly created TrustedForwarder contract.
     */
    function cloneTrustedForwarder(address admin, address appSigner, bytes32 salt) external returns (address trustedForwarder) {
        trustedForwarder = Clones.cloneDeterministic(trustedForwarderImplementation, keccak256(abi.encode(msg.sender, salt)));

        (bool success, ) = trustedForwarder.call(abi.encodeWithSelector(INIT_SELECTOR, admin, appSigner));
        if (!success) {
            revert TrustedForwarderFactory__TrustedForwarderInitFailed(admin, appSigner);
        }
        forwarders[trustedForwarder] = true;

        emit TrustedForwarderCreated(msg.sender, trustedForwarder);
    }
}
