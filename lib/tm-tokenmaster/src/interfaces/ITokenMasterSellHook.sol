//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @title  ITokenMasterSellHook
 * @author Limit Break, Inc.
 * @notice Interface that must be implemented by contracts acting as a sell hook 
 * @notice for advanced sell orders.
 */
interface ITokenMasterSellHook {
    function tokenMasterSellHook(
        address tokenMasterToken,
        address seller,
        bytes32 creatorSellIdentifier,
        uint256 amountSold,
        bytes calldata hookExtraData
    ) external;
}