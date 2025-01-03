//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @title  ITokenMasterOracle
 * @author Limit Break, Inc.
 * @notice Interface that must be implemented by contracts acting as an oracle
 * @notice for advanced orders.
 */
interface ITokenMasterOracle {
    function adjustValue(
        uint256 transactionType,
        address executor,
        address tokenMasterToken,
        address baseToken,
        uint256 baseValue,
        bytes calldata oracleExtraData
    ) external view returns(uint256 tokenValue);
}