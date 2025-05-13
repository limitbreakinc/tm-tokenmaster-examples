//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./StandardPool.sol";
import "@limitbreak/tm-core-lib/src/licenses/LicenseRef-PolyForm-Strict-1.0.0.sol";

/**
 * @title  StandardPoolCreationCode
 * @author Limit Break, Inc.
 * @notice Stores the creation code for a TokenMaster Standard Pool to use in factory deployments.
 */
contract StandardPoolCreationCode {

    constructor() {
        bytes memory creationCode = type(StandardPool).creationCode;
        assembly ("memory-safe") {
            return(add(0x20, creationCode), mload(creationCode))
        }
    }
}