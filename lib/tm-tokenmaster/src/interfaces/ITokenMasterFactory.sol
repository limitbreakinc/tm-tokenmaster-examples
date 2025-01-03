//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "../DataTypes.sol";

/**
 * @title  ITokenMasterFactory
 * @author Limit Break, Inc.
 * @notice Interface that must be implemented by contracts that are factories
 * @notice for tokens that will be deployed through TokenMasterRouter.
 */
interface ITokenMasterFactory {
    function deployToken(
        bytes32 tokenSalt,
        PoolDeploymentParameters calldata poolParams,
        uint256 pairedValueIn,
        uint256 infrastructureFeeBPS
    ) external returns(address deployedAddress);

    function computeDeploymentAddress(
        bytes32 tokenSalt,
        PoolDeploymentParameters calldata poolParams,
        uint256 pairedValueIn,
        uint256 infrastructureFeeBPS
    ) external view returns(address deploymentAddress);
}