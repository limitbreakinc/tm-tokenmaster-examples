//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./PromotionalPool.sol";
import "@limitbreak/tm-core-lib/src/licenses/LicenseRef-PolyForm-Strict-1.0.0.sol";

/**
 * @title  PromotionalPoolCreationCode
 * @author Limit Break, Inc.
 * @notice Stores the init code for a TokenMaster Promotional Pool to use in factory deployments.
 */
contract PromotionalPoolCreationCode {

    constructor() {
        bytes memory creationCode = type(PromotionalPool).creationCode;
        assembly ("memory-safe") {
            return(add(0x20, creationCode), mload(creationCode))
        }
    }
}