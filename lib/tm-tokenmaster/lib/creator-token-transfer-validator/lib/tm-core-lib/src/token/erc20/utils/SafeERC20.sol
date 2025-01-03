//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library SafeERC20 {
    /**
     * @dev A gas efficient, and fallback-safe method to transfer ERC20 tokens owned by the contract.
     * 
     * @param tokenAddress  The address of the token to transfer.
     * @param to            The address to transfer tokens to.
     * @param amount        The amount of tokens to transfer.
     * 
     * @return isError      True if there was an error transferring, false if the call was successful.
     */
    function safeTransfer(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal returns(bool isError) {
        assembly {
            function _callTransfer(_tokenAddress, _to, _amount) -> _isError {
                let ptr := mload(0x40)
                mstore(0x40, add(ptr, 0x60))
                mstore(ptr, 0xa9059cbb)
                mstore(add(0x20, ptr), _to)
                mstore(add(0x40, ptr), _amount)
                if call(gas(), _tokenAddress, 0, add(ptr, 0x1C), 0x44, 0x00, 0x00) {
                    if lt(returndatasize(), 0x20) {
                        _isError := iszero(extcodesize(_tokenAddress))
                        leave
                    }
                    returndatacopy(0x00, 0x00, 0x20)
                    _isError := iszero(mload(0x00))
                    leave
                }
                _isError := true
            }
            isError := _callTransfer(tokenAddress, to, amount)
        }
    }

    /**
     * @dev A gas efficient, and fallback-safe method to transfer ERC20 tokens owned by another address.
     * 
     * @param tokenAddress  The address of the token to transfer.
     * @param from          The address to transfer tokens from.
     * @param to            The address to transfer tokens to.
     * @param amount        The amount of tokens to transfer.
     * 
     * @return isError      True if there was an error transferring, false if the call was successful.
     */
    function safeTransferFrom(
        address tokenAddress,
        address from,
        address to,
        uint256 amount
    ) internal returns(bool isError) {
        assembly {
            function _callTransferFrom(_tokenAddress, _from, _to, _amount) -> _isError {
                let ptr := mload(0x40)
                mstore(0x40, add(ptr, 0x80))
                mstore(ptr, 0x23b872dd)
                mstore(add(0x20, ptr), _from)
                mstore(add(0x40, ptr), _to)
                mstore(add(0x60, ptr), _amount)
                if call(gas(), _tokenAddress, 0, add(ptr, 0x1C), 0x64, 0x00, 0x00) {
                    if lt(returndatasize(), 0x20) {
                        _isError := iszero(extcodesize(_tokenAddress))
                        leave
                    }
                    returndatacopy(0x00, 0x00, 0x20)
                    _isError := iszero(mload(0x00))
                    leave
                }
                _isError := true
            }
            isError := _callTransferFrom(tokenAddress, from, to, amount)
        }
    }

    /**
     * @dev A gas efficient, and fallback-safe method to set approval on ERC20 tokens.
     * 
     * @param tokenAddress  The address of the token to transfer.
     * @param spender       The address to allow to spend tokens.
     * @param allowance     The amount of tokens to allow `spender` to transfer.
     * 
     * @return isError      True if there was an error setting allowance, false if the call was successful.
     */
    function safeApprove(
        address tokenAddress,
        address spender,
        uint256 allowance
    ) internal returns(bool isError) {
        assembly {
            function _callApprove(_tokenAddress, _spender, _allowance) -> _isError {
                let ptr := mload(0x40)
                mstore(0x40, add(ptr, 0x60))
                mstore(ptr, 0x095ea7b3)
                mstore(add(0x20, ptr), _spender)
                mstore(add(0x40, ptr), _allowance)
                if call(gas(), _tokenAddress, 0, add(ptr, 0x1C), 0x44, 0x00, 0x00) {
                    if lt(returndatasize(), 0x20) {
                        _isError := iszero(extcodesize(_tokenAddress))
                        leave
                    }
                    returndatacopy(0x00, 0x00, 0x20)
                    _isError := iszero(mload(0x00))
                    leave
                }
                _isError := true
            }
            isError := _callApprove(tokenAddress, spender, allowance)
        }
    }

    /**
     * @dev A gas efficient, and fallback-safe method to set approval on ERC20 tokens.
     * @dev If the initial approve fails, it will retry setting the allowance to zero and then
     * @dev to the new allowance.
     * 
     * @param tokenAddress  The address of the token to transfer.
     * @param spender       The address to allow to spend tokens.
     * @param allowance     The amount of tokens to allow `spender` to transfer.
     * 
     * @return isError      True if there was an error setting allowance, false if the call was successful.
     */
    function safeApproveWithRetryAfterZero(
        address tokenAddress,
        address spender,
        uint256 allowance
    ) internal returns(bool isError) {
        assembly {
            function _callApprove(_ptr, _tokenAddress, _spender, _allowance) -> _isError {
                mstore(add(0x40, _ptr), _allowance)
                if call(gas(), _tokenAddress, 0, add(_ptr, 0x1C), 0x44, 0x00, 0x00) {
                    if lt(returndatasize(), 0x20) {
                        _isError := iszero(extcodesize(_tokenAddress))
                        leave
                    }
                    returndatacopy(0x00, 0x00, 0x20)
                    _isError := iszero(mload(0x00))
                    leave
                }
                _isError := true
            }

            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x60))
            mstore(ptr, 0x095ea7b3)
            mstore(add(0x20, ptr), spender)

            isError := _callApprove(ptr, tokenAddress, spender, allowance)
            if isError {
                pop(_callApprove(ptr, tokenAddress, spender, 0x00))
                isError := _callApprove(ptr, tokenAddress, spender, allowance)
            }
        }
    }
}