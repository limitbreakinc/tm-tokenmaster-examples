//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @title  ITokenMasterSpendHook
 * @author Limit Break, Inc.
 * @notice Interface that must be implemented by contracts acting as a spend hook 
 * @notice for spend orders.
 */
interface ITokenMasterSpendHook {
    function tokenMasterSpendHook(
        address tokenMasterToken,
        address spender,
        bytes32 creatorSpendIdentifier,
        uint256 multiplier,
        bytes calldata hookExtraData
    ) external;
}