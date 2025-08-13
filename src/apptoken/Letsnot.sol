// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20C} from "@limitbreak/tm-core-lib/src/token/erc20/ERC20C.sol";
import {Ownable} from "@limitbreak/tm-core-lib/src/utils/access/Ownable.sol";
import {CreatorTokenBase} from "@limitbreak/tm-core-lib/src/utils/token/CreatorTokenBase.sol";
import {LetsnotTransferValidator} from "./LetsnotTransferValidator.sol";
import {LetsnotAuthorizer} from "./LetsnotAuthorizer.sol";

/**
 * @title Letsnot Token
 * @author YGG
 * @notice This is an example implementation of an ERC-20C "Creator Token".
 *
 * @dev WHAT IS THE DIFFERENCE BETWEEN ERC-20 and ERC-20C?
 *
 * An ERC-20 is a standard for fungible tokens on Ethereum. It defines a common
 * list of rules that all tokens can follow, which simplifies interactions
 * between tokens and dApps (like wallets or decentralized exchanges). The standard
 * `transfer` and `transferFrom` functions in ERC-20 have no restrictions; if you
 * own the tokens (or have an allowance), you can transfer them.
 *
 * ERC-20C is an extension of the ERC-20 standard, created by Limit Break. The "C"
 * stands for "Creator". It introduces a powerful feature: **programmable transfer rules**.
 * This means the token creator can define custom on-chain logic that determines
 * *if*, *when*, and *how* a token can be transferred.
 *
 * This contract, `Letsnot`, inherits from `ERC20C`. This is the primary difference.
 * Instead of just inheriting from a standard ERC20 implementation, we inherit
 * functionality that allows us to connect this token to a "Transfer Validator".
 *
 * The Transfer Validator is an external smart contract that holds all the custom
 * rules for transferring the token. Every time `transfer` or `transferFrom` is called
 * on this token, the token first calls the validator to ask "Is this transfer allowed?".
 * This allows for the complex rules you requested, like time-locks, VIP tier checks, etc.
 */
contract Letsnot is ERC20C, Ownable {
    /**
     * @notice The Transfer Validator contract that enforces custom transfer rules.
     */
    LetsnotTransferValidator public transferValidator;

    /**
     * @notice The Authorizer contract that contains our specific custom logic.
     * @dev In the Limit Break ecosystem, Validators can delegate rule-checking to
     *      one or more "Authorizer" contracts. This makes the system modular.
     */
    LetsnotAuthorizer public authorizer;

    /**
     * @notice The constructor initializes the token and sets up the transfer validation system.
     * @param creator The address that will be the owner of this contract.
     * @param name The name of the token (e.g., "Letsnot").
     * @param symbol The symbol of the token (e.g., "$LETSNOT").
     */
    constructor(
        address creator,
        string memory name,
        string memory symbol
    )
        // This calls the constructor of the ERC20C contract, setting the token's name and symbol.
        ERC20C(name, symbol)
        // This calls the constructor of the CreatorTokenBase, which is a parent of ERC20C.
        // It's used to set up the core creator token functionality. We pass address(0)
        // because we will set our specific validator right after this.
        CreatorTokenBase(address(0))
        // This sets the owner of the contract. The owner has special privileges,
        // like being able to change the transfer validator.
        Ownable(creator)
    {
        // 1. DEPLOY THE VALIDATOR: Here, we create a new instance of our `LetsnotTransferValidator`.
        // This is the contract that all transfers will be checked against.
        // The EOA Registry address is a public contract provided by Limit Break for on-chain checks.
        transferValidator = new LetsnotTransferValidator(
            creator,
            0xE0A0004Dfa318fc38298aE81a666710eaDCEba5C,
            "Letsnot Validator",
            "1"
        );

        // 2. DEPLOY THE AUTHORIZER: We create a new instance of our `LetsnotAuthorizer`,
        // which contains our custom 7-day hold logic. We pass it the address of the
        // validator we just created so it knows which contract to communicate with.
        authorizer = new LetsnotAuthorizer(address(transferValidator));

        // 3. LINK TOKEN TO VALIDATOR: We call `setTransferValidator` (a function from CreatorTokenBase)
        // to tell this token contract which validator to use for all future transfers.
        setTransferValidator(address(transferValidator));

        // 4. LINK VALIDATOR TO AUTHORIZER: We tell the validator that our `authorizer` contract
        // is an approved source of transfer authorizations. `addAccountsToAuthorizers` is a function
        // on the standard CreatorTokenTransferValidator. The `0` refers to the default list ID.
        address[] memory authorizers = new address[](1);
        authorizers[0] = address(authorizer);
        transferValidator.addAccountsToAuthorizers(0, authorizers);

        // Mint the initial supply of tokens to the deployer of the contract.
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    /**
     * @dev This is a "hook", a function that is automatically called by the parent `ERC20C`
     * contract after every successful transfer. This is another key feature of ERC-20C that
     * is not present in standard ERC-20.
     * We use this hook to notify our Authorizer that a transfer has occurred, so it can
     * update the holding timer for the recipient.
     * @param to The address that received the tokens.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        // We only care about setting the start time for the new holder.
        authorizer.setHoldStartTime(to);
    }

    /**
     * @dev This function is required by the `CreatorTokenBase` contract. It's used
     * internally by the framework to check if the caller has ownership permissions.
     * By inheriting from `Ownable`, we can simply implement this by checking against
     * the `owner()` function provided by `Ownable`.
     */
    function _requireCallerIsContractOwner() internal view override {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }
}
