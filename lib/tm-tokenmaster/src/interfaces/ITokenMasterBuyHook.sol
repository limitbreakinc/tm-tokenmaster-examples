//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @title  ITokenMasterBuyHook
 * @author Limit Break, Inc.
 * @notice Interface that must be implemented by contracts acting as a buy hook 
 * @notice for advanced buy orders.
 */
interface ITokenMasterBuyHook {
    function tokenMasterBuyHook(
        address tokenMasterToken,
        address buyer,
        bytes32 creatorBuyIdentifier,
        uint256 amountPurchased,
        bytes calldata hookExtraData
    ) external;
}