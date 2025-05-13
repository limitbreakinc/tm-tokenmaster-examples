// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title  TrustedForwarder
 * @author Limit Break, Inc.
 * @notice TrustedForwarder is a generic message forwarder, which allows you to relay transactions to any contract and preserve the original sender.
 *         The processor acts as a trusted proxy, which can be a way to limit interactions with your contract, or enforce certain conditions.
 */
contract TrustedForwarder is EIP712, Initializable, Ownable {
    error TrustedForwarder__CannotSetAppSignerToZeroAddress();
    error TrustedForwarder__CannotSetOwnerToZeroAddress();
    error TrustedForwarder__CannotUseWithoutSignature();
    error TrustedForwarder__InvalidSignature();
    error TrustedForwarder__SignerNotAuthorized();

    struct SignatureECDSA {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // keccak256("AppSigner(bytes32 messageHash,address target,address sender)")
    bytes32 public constant APP_SIGNER_TYPEHASH = 0xc83d02443cc9e12c5d2faae8a9a36bf0112f5b4a8cce23c9277a0c68bf638762;
    address public signer;

    constructor() EIP712("TrustedForwarder", "1") {}

    /**
     * @notice Initializes the TrustedForwarder contract.
     *
     * @dev    This should be called atomically with the clone of the contract to prevent bad actors from calling it.
     * @dev    - Throws if the contract is already initialized
     *
     * @param owner           The address to assign the owner role to.
     * @param appSigner       The address to assign the app signer role to.
     */
    function __TrustedForwarder_init(address owner, address appSigner) external initializer {
        if (owner == address(0)) {
            revert TrustedForwarder__CannotSetOwnerToZeroAddress();
        }
        if (appSigner != address(0)) {
            signer = appSigner;
        }
        _transferOwnership(owner);
    }

    /**
     * @notice Forwards a message to a target contract, preserving the original sender.
     * @notice In the case the forwarder does not require a signature, this function should be used to save gas.
     *
     * @dev    - Throws if the target contract reverts.
     * @dev    - Throws if the target address has no code.
     * @dev    - Throws if `signer` is not address(0).
     *
     * @param target    The address of the contract to forward the message to.
     * @param message   The calldata to forward.
     *
     * @return returnData The return data of the call to the target contract.
     */
    function forwardCall(address target, bytes calldata message)
        external
        payable
        returns (bytes memory returnData)
    {
        address signerCache = signer;
        if (signerCache != address(0)) {
            revert TrustedForwarder__CannotUseWithoutSignature();
        }

        bytes memory encodedData = _encodeERC2771Context(message, _msgSender());
        assembly {
            let success := call(gas(), target, callvalue(), add(encodedData, 0x20), mload(encodedData), 0, 0)
            let size := returndatasize()

            returnData := mload(0x40)
            mstore(returnData, size)
            mstore(0x40, add(add(returnData, 0x20), size)) // Adjust memory pointer
            returndatacopy(add(returnData, 0x20), 0, size) // Copy returndata to memory

            if iszero(success) {
                revert(add(returnData, 0x20), size) // Revert with return data on failure
            }

            // If the call was successful, but the return data is empty, check if the target address has code
            if iszero(size) {
                if iszero(extcodesize(target)) {
                    mstore(0x00, 0x39bf07c1) // Store function selector `TrustedForwarder__TargetAddressHasNoCode()` and revert
                    revert(0x1c, 0x04) // Revert with the custom function selector
                }
            }
        }
    }


    /**
     * @notice Forwards a message to a target contract, preserving the original sender.
     * @notice This should only be used if the forwarder requires a signature.
     * @notice In the case the app signer is not set, use the overloaded `forwardCall` function without a signature variable.
     *
     * @dev    - Throws if the target contract reverts.
     * @dev    - Throws if the target address has no code.
     * @dev    - Throws if `signer` is not address(0) and the signature does not match the signer.
     *
     * @param target    The address of the contract to forward the message to.
     * @param message   The calldata to forward.
     * @param signature The signature of the message.
     *
     * @return returnData The return data of the call to the target contract.
     */
    function forwardCall(address target, bytes calldata message, SignatureECDSA calldata signature)
        external
        payable
        returns (bytes memory returnData)
    {
        address signerCache = signer;
        if (signerCache != address(0)) {
            if (
                    signerCache != _ecdsaRecover(
                        _hashTypedDataV4(
                            keccak256(abi.encode(APP_SIGNER_TYPEHASH, keccak256(message), target, _msgSender()))
                        ),
                        signature.v,
                        signature.r,
                        signature.s
                    )
            ) {
                revert TrustedForwarder__SignerNotAuthorized();
            }
        }

        bytes memory encodedData = _encodeERC2771Context(message, _msgSender());
        assembly {
            let success := call(gas(), target, callvalue(), add(encodedData, 0x20), mload(encodedData), 0, 0)
            let size := returndatasize()

            returnData := mload(0x40)
            mstore(returnData, size)
            mstore(0x40, add(add(returnData, 0x20), size)) // Adjust memory pointer
            returndatacopy(add(returnData, 0x20), 0, size) // Copy returndata to memory

            if iszero(success) {
                revert(add(returnData, 0x20), size) // Revert with return data on failure
            }

            // If the call was successful, but the return data is empty, check if the target address has code
            if iszero(size) {
                if iszero(extcodesize(target)) {
                    mstore(0x00, 0x39bf07c1) // Store function selector `TrustedForwarder__TargetAddressHasNoCode()` and revert
                    revert(0x1c, 0x04) // Revert with the custom function selector
                }
            }
        }
    }

    /**
     * @notice Updates the app signer address. To disable app signing, set signer to address(0).
     *
     * @dev    - Throws if the sender is not the owner.
     *
     * @param signer_ The address to assign the app signer role to.
     */
    function updateSigner(address signer_) external onlyOwner {
        if (signer_ == address(0)) {
            revert TrustedForwarder__CannotSetAppSignerToZeroAddress();
        }
        signer = signer_;
    }

    /**
     * @notice Resets the app signer address to address(0).
     *
     * @dev    - Throws if the sender is not the owner.
     */
     function deactivateSigner() external onlyOwner {
        signer = address(0);
    }

    /**
     * @notice Returns the domain separator used in the permit signature
     *
     * @return The domain separator
     */
    function domainSeparatorV4() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @dev appends the msg.sender to the end of the calldata
    function _encodeERC2771Context(bytes calldata _data, address _msgSender) internal pure returns (bytes memory encodedData) {
        assembly  {
            // Calculate total length: data.length + 20 bytes for the address
            let totalLength := add(_data.length, 20)

            // Allocate memory for the combined data
            encodedData := mload(0x40)
            mstore(0x40, add(encodedData, add(totalLength, 0x20)))

            // Set the length of the `encodedData`
            mstore(encodedData, totalLength)

            // Copy the `bytes calldata` data
            calldatacopy(add(encodedData, 0x20), _data.offset, _data.length)

            // Append the `address`. Addresses are 20 bytes, stored in the last 20 bytes of a 32-byte word
            mstore(add(add(encodedData, 0x20), _data.length), shl(96, _msgSender))
        }
    }

    /**
     * @notice Recovers an ECDSA signature
     *
     * @dev    This function is copied from OpenZeppelin's ECDSA library
     *
     * @param digest The digest to recover
     * @param v      The v component of the signature
     * @param r      The r component of the signature
     * @param s      The s component of the signature
     *
     * @return recoveredSigner The signer of the digest
     */
    function _ecdsaRecover(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (address recoveredSigner) {
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert TrustedForwarder__InvalidSignature();
        }

        recoveredSigner = ecrecover(digest, v, r, s);
        if (recoveredSigner == address(0)) {
            revert TrustedForwarder__InvalidSignature();
        }
    }
}