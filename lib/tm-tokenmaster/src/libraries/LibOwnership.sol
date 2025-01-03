//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

library LibOwnership {

    bytes32 private constant DEFAULT_ACCESS_CONTROL_ADMIN_ROLE = 0x00;
    error Ownership__CallerIsNotTokenOrOwnerOrAdmin();
    error Ownership__CallerIsNotTokenOrOwnerOrAdminOrRole();

    /**
     * @notice Reverts the transaction if the caller is not the owner or assigned the default
     * @notice admin role of the contract at `tokenAddress`.
     *
     * @dev    Throws when the caller is neither owner nor assigned the default admin role.
     * 
     * @param tokenAddress The contract address of the token to check permissions for.
     */
    function requireCallerIsTokenOrContractOwnerOrAdmin(address tokenAddress) internal view {
        if (msg.sender == tokenAddress) {
            return;
        }

        (address contractOwner,) = safeOwner(tokenAddress);
        if (msg.sender == contractOwner) {
            return;
        }

        (bool callerIsContractAdmin,) = safeHasRole(tokenAddress, DEFAULT_ACCESS_CONTROL_ADMIN_ROLE, msg.sender);
        if (callerIsContractAdmin) {
            return;
        }

        revert Ownership__CallerIsNotTokenOrOwnerOrAdmin();
    }

    /**
     * @notice Returns if the caller is the token contract, owner or assigned the default
     * @notice admin role of the contract at `tokenAddress`.
     * 
     * @param caller       The address calling the contract
     * @param tokenAddress The contract address of the token to check permissions for.
     * 
     * @return isTokenOwnerOrAdmin True if caller is token, owner or admin, false otherwise
     */
    function isCallerTokenOrContractOwnerOrAdmin(
        address caller,
        address tokenAddress
    ) internal view returns (bool isTokenOwnerOrAdmin) {
        if (caller == tokenAddress) {
            return true;
        }

        (address contractOwner,) = safeOwner(tokenAddress);
        if (caller == contractOwner) {
            return true;
        }

        (bool callerIsContractAdmin,) = safeHasRole(tokenAddress, DEFAULT_ACCESS_CONTROL_ADMIN_ROLE, caller);
        return callerIsContractAdmin;
    }

    /**
     * @notice Reverts the transaction if the caller is not the owner or assigned the default
     * @notice admin role of the contract at `tokenAddress`.
     *
     * @dev    Throws when the caller is neither owner nor assigned the default admin role.
     * 
     * @param tokenAddress The contract address of the token to check permissions for.
     */
    function requireCallerIsTokenOrContractOwnerOrAdminOrRole(address tokenAddress, bytes32 role) internal view {        
        if (msg.sender == tokenAddress) {
            return;
        }

        (address contractOwner,) = safeOwner(tokenAddress);
        if (msg.sender == contractOwner) {
            return;
        }

        (bool callerIsContractAdmin,) = safeHasRole(tokenAddress, DEFAULT_ACCESS_CONTROL_ADMIN_ROLE, msg.sender);
        if (callerIsContractAdmin) {
            return;
        }

        (bool callerHasRole,) = safeHasRole(tokenAddress, role, msg.sender);
        if (callerHasRole) {
            return;
        }

        revert Ownership__CallerIsNotTokenOrOwnerOrAdminOrRole();
    }

    /**
     * @dev A gas efficient, and fallback-safe way to call the owner function on a token contract.
     *      This will get the owner if it exists - and when the function is unimplemented, the
     *      presence of a fallback function will not result in halted execution.
     * 
     * @param tokenAddress  The address of the token collection to get the owner of.
     * 
     * @return owner   The owner of the token collection contract.
     * @return isError True if there was an error in retrieving the owner, false if the call was successful.
     */
    function safeOwner(
        address tokenAddress
    ) private view returns(address owner, bool isError) {
        assembly ("memory-safe") {
            function _callOwner(_tokenAddress) -> _owner, _isError {
                mstore(0x00, 0x8da5cb5b)
                if and(iszero(lt(returndatasize(), 0x20)), staticcall(gas(), _tokenAddress, 0x1C, 0x04, 0x00, 0x20)) {
                    _owner := mload(0x00)
                    leave
                }
                _isError := true
            }
            owner, isError := _callOwner(tokenAddress)
        }
    }
    
    /**
     * @dev A gas efficient, and fallback-safe way to call the hasRole function on a token contract.
     *      This will check if the account `hasRole` if `hasRole` exists - and when the function is unimplemented, the
     *      presence of a fallback function will not result in halted execution.
     * 
     * @param tokenAddress  The address of the token collection to call hasRole on.
     * @param role          The role to check if the account has on the collection.
     * @param account       The address of the account to check if they have a specified role.
     * 
     * @return hasRole The owner of the token collection contract.
     * @return isError True if there was an error in retrieving the owner, false if the call was successful.
     */
    function safeHasRole(
        address tokenAddress,
        bytes32 role,
        address account
    ) private view returns(bool hasRole, bool isError) {
        assembly ("memory-safe") {
            function _callHasRole(_tokenAddress, _role, _account) -> _hasRole, _isError {
                let ptr := mload(0x40)
                mstore(0x40, add(ptr, 0x60))
                mstore(ptr, 0x91d14854)
                mstore(add(0x20, ptr), _role)
                mstore(add(0x40, ptr), _account)
                if and(iszero(lt(returndatasize(), 0x20)), staticcall(gas(), _tokenAddress, add(ptr, 0x1C), 0x44, 0x00, 0x20)) {
                    _hasRole := mload(0x00)
                    leave
                }
                _isError := true
            }
            hasRole, isError := _callHasRole(tokenAddress, role, account)
        }
    }
}