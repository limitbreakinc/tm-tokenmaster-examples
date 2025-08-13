// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {CreatorTokenTransferValidator} from "@limitbreak/creator-token-transfer-validator/CreatorTokenTransferValidator.sol";

/**
 * @title Letsnot Transfer Validator
 * @author YGG
 * @notice This contract is the main Transfer Validator for the Letsnot token.
 * @dev This contract inherits from the standard `CreatorTokenTransferValidator`
 * provided by Limit Break. We are not adding any custom logic to this contract directly.
 * Instead, we are using the built-in "Authorizer" functionality to delegate the
 * custom rule-checking to our `LetsnotAuthorizer` contract.
 *
 * This demonstrates the modularity of the Limit Break system. We can keep the
 * main validator contract standard and clean, while encapsulating our unique
 * business logic in separate, focused Authorizer contracts.
 */
contract LetsnotTransferValidator is CreatorTokenTransferValidator {
    /**
     * @notice The constructor simply calls the parent `CreatorTokenTransferValidator` constructor.
     * @param defaultOwner The initial owner of the validator's default list.
     * @param eoaRegistry The address of the EOA Registry contract (a public good by Limit Break).
     * @param name A name for the validator.
     * @param version The version of the validator.
     */
    constructor(
        address defaultOwner,
        address eoaRegistry,
        string memory name,
        string memory version
    ) CreatorTokenTransferValidator(defaultOwner, eoaRegistry, name, version) {}
}
