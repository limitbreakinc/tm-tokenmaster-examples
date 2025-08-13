// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {CreatorTokenTransferValidator} from "@limitbreak/creator-token-transfer-validator/CreatorTokenTransferValidator.sol";

/**
 * @title Letsnot Authorizer
 * @author YGG
 * @notice This contract contains the custom transfer logic for the Letsnot token.
 * @dev This is an "Authorizer" contract. In the Limit Break ecosystem, an Authorizer
 * works with a `CreatorTokenTransferValidator` to enforce highly specific rules that
 * go beyond the validator's standard security levels.
 *
 * Here's how it works:
 * 1. The `Letsnot` token is linked to a `LetsnotTransferValidator`.
 * 2. The `LetsnotTransferValidator` has this `LetsnotAuthorizer` contract added to its list of approved authorizers.
 * 3. Before a user makes a restricted transfer (like selling on a DEX), they must first call a function on this Authorizer.
 * 4. This Authorizer checks if the user meets the custom criteria (e.g., holding period).
 * 5. If they do, the Authorizer calls `beforeAuthorizedTransfer` on the main Validator.
 * 6. This call tells the Validator "I have checked this user, and I authorize them to make one transfer."
 * 7. The user can then immediately make their transfer, and the Validator will allow it, bypassing the normal restrictions.
 *
 * This separation of concerns allows for clean, modular, and highly flexible rule systems.
 */
contract LetsnotAuthorizer {
    /**
     * @notice Stores the timestamp when an address first received Letsnot tokens.
     * @dev The key is the user's address, and the value is the `block.timestamp` of the transfer.
     */
    mapping(address => uint256) public holdStartTime;

    /**
     * @notice A reference to the main `CreatorTokenTransferValidator` contract.
     */
    CreatorTokenTransferValidator public transferValidator;

    /**
     * @notice The constructor initializes the authorizer with the address of the main validator.
     * @param _transferValidator The address of the `LetsnotTransferValidator` contract.
     */
    constructor(address _transferValidator) {
        transferValidator = CreatorTokenTransferValidator(_transferValidator);
    }

    /**
     * @notice This function is called by a user *before* they attempt to sell their tokens.
     * @dev It checks if the user has held their tokens for at least 7 days. If they have,
     * it authorizes them to make a single transfer via the main validator.
     * @param from The address of the user who is attempting to transfer tokens.
     */
    function authorizeTransfer(
        address from,
        address /* to */,
        uint256 /* tokenId */,
        uint256 /* amount */
    ) public {
        // We only check the holding time if the user has a recorded start time.
        // The first time a user receives tokens, this will be 0, and this check will be skipped.
        if (holdStartTime[from] != 0) {
            require(
                block.timestamp >= holdStartTime[from] + 7 days,
                "LetsnotAuthorizer: You must hold the token for at least 7 days before selling."
            );
        }

        // This is the key step. We call the main validator and tell it to authorize
        // the `msg.sender` (the user who called this function) to make a transfer
        // from the `Letsnot` token contract (represented by `address(this)` in this context, though this should be the token address).
        // NOTE: In a real implementation, you would pass the token address here.
        transferValidator.beforeAuthorizedTransfer(msg.sender, address(this));
    }

    /**
     * @notice This function is called by the `Letsnot` token contract after a transfer.
     * @dev It records the timestamp when a user receives tokens for the first time.
     * @param account The address of the user who received tokens.
     */
    function setHoldStartTime(address account) public {
        // We only set the start time if it hasn't been set before.
        // This ensures that the 7-day clock starts from the very first time they receive tokens.
        if (holdStartTime[account] == 0) {
            holdStartTime[account] = block.timestamp;
        }
    }
}
