//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./StandardPoolCreationCode.sol";
import "../../DataTypes.sol";
import "../../Errors.sol";
import "../../interfaces/ITokenMasterFactory.sol";
import "@limitbreak/tm-core-lib/src/licenses/LicenseRef-PolyForm-Strict-1.0.0.sol";

/**
 * @title  StandardPoolFactory
 * @author Limit Break, Inc.
 * @notice Factory contract for deploying StandardPool contracts from TokenMasterRouter.
 * 
 * @dev    The `deployToken` function may only be called by the TokenMasterRouter contract
 *         which will supply the initial paired token value to the contract prior to deployment.
 */
contract StandardPoolFactory is ITokenMasterFactory {
    /// @dev The address of the TokenMasterRouter contract which is allowed to call `deployToken`.
    address private immutable ROUTER;

    /// @dev The address that contains the standard pool creation code.
    address public immutable CREATION_CODE;

    modifier onlyRouter() {
        if (msg.sender != ROUTER) {
            revert TokenMasterFactory__CallerMustBeRouter();
        }
        _;
    }

    /**
     * @notice Constructs the factory contract.
     * 
     * @dev    Throws when the router address is the zero address.
     * @dev    Throws when the router address does not have code.
     * 
     * @param tokenMasterRouter  The address of the TokenMaster Router contract.
     */
    constructor(address tokenMasterRouter) {
        if (tokenMasterRouter == address(0) || tokenMasterRouter.code.length == 0) {
            revert TokenMasterFactory__RouterAddressNotSet();
        }

        ROUTER = tokenMasterRouter;
        CREATION_CODE = address(new StandardPoolCreationCode());
    }

    /**
     * @notice Deploys a new StandardPool token with the provided parameters and returns the deployment address.
     * 
     * @param tokenSalt             The salt value for the contract creation.
     * @param poolParams            The parameters for the StandardPool pool.
     * @param pairedValueIn         The amount of paired value sent with the deployment transaction.
     * @param infrastructureFeeBPS  The infrastructure fee for the pool.
     * 
     * @return deployedAddress  The address the token contract is deployed to.
     */
    function deployToken(
        bytes32 tokenSalt,
        PoolDeploymentParameters calldata poolParams,
        uint256 pairedValueIn,
        uint256 infrastructureFeeBPS
    ) external onlyRouter returns(address deployedAddress) {
        bytes memory initCode = 
            bytes.concat(
                CREATION_CODE.code,
                abi.encode(
                    poolParams,
                    pairedValueIn,
                    infrastructureFeeBPS,
                    ROUTER
                )
            );

        assembly ("memory-safe") {
            deployedAddress := create2(0x00, add(initCode, 0x20), mload(initCode), tokenSalt)
        }
    }

    /**
     * @notice Calculates the deployment address of a StandardPool based on the deployment parameters.
     * 
     * @param tokenSalt             The salt value for the contract creation.
     * @param poolParams            The parameters for the StandardPool pool.
     * @param pairedValueIn         The amount of paired value sent with the deployment transaction.
     * @param infrastructureFeeBPS  The infrastructure fee for the pool.
     * 
     * @return deploymentAddress  Address that the contract will deploy to with the given parameters.
     */
    function computeDeploymentAddress(
        bytes32 tokenSalt,
        PoolDeploymentParameters calldata poolParams,
        uint256 pairedValueIn,
        uint256 infrastructureFeeBPS
    ) external view returns(address deploymentAddress) {
        bytes32 initCodeHash = keccak256(
            bytes.concat(
                CREATION_CODE.code,
                abi.encode(
                    poolParams,
                    pairedValueIn,
                    infrastructureFeeBPS,
                    ROUTER
                )
            )
        );

        address addressMask = ADDRESS_MASK;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x60))
            mstore8(ptr, 0xff)
            mstore(add(ptr, 0x01), shl(0x60, address()))
            mstore(add(ptr, 0x15), tokenSalt)
            mstore(add(ptr, 0x35), initCodeHash)
            deploymentAddress := and(addressMask, keccak256(ptr, 0x55))
        }
    }
}