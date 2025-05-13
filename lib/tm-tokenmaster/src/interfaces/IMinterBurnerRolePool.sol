//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @title  IMinterBurnerRolePool
 * @author Limit Break, Inc.
 * @notice Interface definition for pools that implement external minting and burning functions.
 */
interface IMinterBurnerRolePool {
    function mint(address to, uint256 amount) external;
    function mintBatch(address[] calldata toAddresses, uint256[] calldata amounts) external;
    function burn(address from, uint256 amount) external;
}