pragma solidity ^0.8.4;

library Signatures {
    bytes32 constant UPPER_BIT_MASK = (0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

    error Signatures__SignatureTransferInvalidSignature();

    function verifyCalldata(bytes calldata signature, bytes32 digest, address expectedSigner) internal view {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // Divide the signature in r, s and v variables
            /// @solidity memory-safe-assembly
            assembly {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 32))
                v := byte(0, calldataload(add(signature.offset, 64)))
            }
            (bool isError, address signer) = _ecdsaRecover(digest, v, r, s);
            if (expectedSigner != signer || isError) {
                _verifyEIP1271Signature(expectedSigner, digest, signature);
            }
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // Divide the signature in r and vs variables
            /// @solidity memory-safe-assembly
            assembly {
                r := calldataload(signature.offset)
                vs := calldataload(add(signature.offset, 32))
            }
            (bool isError, address signer) = _ecdsaRecover(digest, r, vs);
            if (expectedSigner != signer || isError) {
                _verifyEIP1271Signature(expectedSigner, digest, signature);
            }
        } else {
            _verifyEIP1271Signature(expectedSigner, digest, signature);
        }
    }

    /**
     * @notice Verifies an EIP-1271 signature.
     * 
     * @dev    Throws when `signer` code length is zero OR the EIP-1271 call does not
     * @dev    return the correct magic value.
     * 
     * @param signer     The signer address to verify a signature with
     * @param hash       The hash digest to verify with the signer
     * @param signature  The signature to verify
     */
    function _verifyEIP1271Signature(address signer, bytes32 hash, bytes calldata signature) private view {
        if(signer.code.length == 0) {
            revert Signatures__SignatureTransferInvalidSignature();
        }

        if (!_safeIsValidSignature(signer, hash, signature)) {
            revert Signatures__SignatureTransferInvalidSignature();
        }
    }

    /**
     * @notice  Overload of the `_ecdsaRecover` function to unpack the `v` and `s` values
     * 
     * @param digest    The hash digest that was signed
     * @param r         The `r` value of the signature
     * @param vs        The packed `v` and `s` values of the signature
     * 
     * @return isError  True if the ECDSA function is provided invalid inputs
     * @return signer   The recovered address from ECDSA
     */
    function _ecdsaRecover(bytes32 digest, bytes32 r, bytes32 vs) private pure returns (bool isError, address signer) {
        unchecked {
            bytes32 s = vs & UPPER_BIT_MASK;
            uint8 v = uint8(uint256(vs >> 255)) + 27;

            (isError, signer) = _ecdsaRecover(digest, v, r, s);
        }
    }

    /**
     * @notice  Recovers the signer address using ECDSA
     * 
     * @dev     Does **NOT** revert if invalid input values are provided or `signer` is recovered as address(0)
     * @dev     Returns an `isError` value in those conditions that is handled upstream
     * 
     * @param digest    The hash digest that was signed
     * @param v         The `v` value of the signature
     * @param r         The `r` value of the signature
     * @param s         The `s` value of the signature
     * 
     * @return isError  True if the ECDSA function is provided invalid inputs
     * @return signer   The recovered address from ECDSA
     */
    function _ecdsaRecover(bytes32 digest, uint8 v, bytes32 r, bytes32 s) private pure returns (bool isError, address signer) {
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            // Invalid signature `s` value - return isError = true and signer = address(0) to check EIP-1271
            return (true, address(0));
        }

        signer = ecrecover(digest, v, r, s);
        isError = (signer == address(0));
    }

    /**
     * @notice A gas efficient, and fallback-safe way to call the isValidSignature function for EIP-1271.
     *
     * @param signer     The EIP-1271 signer to call to check for a valid signature.
     * @param hash       The hash digest to verify with the EIP-1271 signer.
     * @param signature  The supplied signature to verify.
     * 
     * @return isValid   True if the EIP-1271 signer returns the EIP-1271 magic value.
     */
    function _safeIsValidSignature(
        address signer,
        bytes32 hash,
        bytes calldata signature
    ) private view returns(bool isValid) {
        assembly {
            function _callIsValidSignature(_signer, _hash, _signatureOffset, _signatureLength) -> _isValid {
                let ptr := mload(0x40)
                // store isValidSignature(bytes32,bytes) selector
                mstore(ptr, hex"1626ba7e")
                // store bytes32 hash value in abi encoded location
                mstore(add(ptr, 0x04), _hash)
                // store abi encoded location of the bytes signature data
                mstore(add(ptr, 0x24), 0x40)
                // store bytes signature length
                mstore(add(ptr, 0x44), _signatureLength)
                // copy calldata bytes signature to memory
                calldatacopy(add(ptr, 0x64), _signatureOffset, _signatureLength)
                // calculate data length based on abi encoded data with rounded up signature length
                let dataLength := add(0x64, and(add(_signatureLength, 0x1F), not(0x1F)))
                // update free memory pointer
                mstore(0x40, add(ptr, dataLength))

                // static call _signer with abi encoded data
                // skip return data check if call failed or return data size is not at least 32 bytes
                if and(iszero(lt(returndatasize(), 0x20)), staticcall(gas(), _signer, ptr, dataLength, 0x00, 0x20)) {
                    // check if return data is equal to isValidSignature magic value
                    _isValid := eq(mload(0x00), hex"1626ba7e")
                    leave
                }
            }
            isValid := _callIsValidSignature(signer, hash, signature.offset, signature.length)
        }
    }
}
