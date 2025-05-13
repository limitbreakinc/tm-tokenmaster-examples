//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./StablePool.sol";
import "@limitbreak/tm-core-lib/src/licenses/LicenseRef-PolyForm-Strict-1.0.0.sol";

/**
 * @title  StablePoolCreationCode
 * @author Limit Break, Inc.
 * @notice Stores the init code for a TokenMaster Stable Pool to use in factory deployments.
 */
contract StablePoolCreationCode {

    constructor() {
        bytes memory creationCode = type(StablePool).creationCode;
        assembly ("memory-safe") {
            return(add(0x20, creationCode), mload(creationCode))
        }
    }
}