// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ITrustedForwarder {
    struct SignatureECDSA {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    error InvalidShortString();
    error StringTooLong(string str);
    error TrustedForwarder__CannotSetAppSignerToZeroAddress();
    error TrustedForwarder__CannotSetOwnerToZeroAddress();
    error TrustedForwarder__CannotUseWithoutSignature();
    error TrustedForwarder__InvalidSignature();
    error TrustedForwarder__SignerNotAuthorized();

    event EIP712DomainChanged();
    event Initialized(uint8 version);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function APP_SIGNER_TYPEHASH() external view returns (bytes32);
    function __TrustedForwarder_init(address owner, address appSigner) external;
    function domainSeparatorV4() external view returns (bytes32);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function forwardCall(address target, bytes memory message) external payable returns (bytes memory returnData);
    function forwardCall(address target, bytes memory message, SignatureECDSA memory signature)
        external
        payable
        returns (bytes memory returnData);
    function owner() external view returns (address);
    function renounceOwnership() external;
    function signer() external view returns (address);
    function transferOwnership(address newOwner) external;
    function updateSigner(address signer_) external;
}