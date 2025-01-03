//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/// @dev Thrown when a signature `v` value exceeds 255.
error Error__InvalidSignatureV();

// TokenMaster Errors
/// @dev Thrown when a deployment call is made to a token factory and it does not originate from the TokenMasterRouter.
error TokenMasterFactory__CallerMustBeRouter();
/// @dev Thrown when deploying a token factory and the TokenMasterRouter address is not set in the factory configuration contract.
error TokenMasterFactory__RouterAddressNotSet();

/// @dev Thrown when the amount of tokens to be spent exceeds the maximum amount specified by the spender.
error TokenMasterRouter__AmountToSpendExceedsMax();
/// @dev Thrown when calldata length does not match the expected calldata length.
error TokenMasterRouter__BadCalldataLength();
/// @dev Thrown when a caller is attempting to execute a permissioned function they are not permitted for.
error TokenMasterRouter__CallerNotAllowed();
/// @dev Thrown when the block time is after the expiration of a cosignature.
error TokenMasterRouter__CosignatureExpired();
/// @dev Thrown when a cosigner is specified on an advanced order and the cosignature is invalid.
error TokenMasterRouter__CosignatureInvalid();
/// @dev Thrown when the deterministic address specified in deployment parameters does not match the address returned from a token factory.
error TokenMasterRouter__DeployedTokenAddressMismatch();
/// @dev Thrown when a new TokenMaster token deployment expects to deposit native funds to the pool and the funds fail to transfer.
error TokenMasterRouter__FailedToDepositInitialPairedFunds();
/// @dev Thrown when the paired token value fails to transfer to or from a pool.
error TokenMasterRouter__FailedToTransferPairedToken();
/// @dev Thrown when deployment signing is enabled and the supplied signature is invalid.
error TokenMasterRouter__InvalidDeploymentSignature();
/// @dev Thrown when the TokenMaster admin sets the infrastructure fee greater than 10_000 or during deployment when the current fee exceeds the max specified fee.
error TokenMasterRouter__InvalidInfrastructureFeeBPS();
/// @dev Thrown when a TokenMaster token owner attempts to accept the zero address as the new partner fee recipient.
error TokenMasterRouter__InvalidRecipient();
/// @dev Thrown when the message value for a deployment pairing with native tokens does not match the specified initial paired token to deposit.
error TokenMasterRouter__InvalidMessageValue();
/// @dev Thrown when transferring ERC20 tokens to a pool and native value is sent with the call to the router.
error TokenMasterRouter__NativeValueNotAllowedOnERC20();
/// @dev Thrown when an advanced order has expired.
error TokenMasterRouter__OrderExpired();
/// @dev Thrown when an advanced order has been disabled.
error TokenMasterRouter__OrderDisabled();
/// @dev Thrown when the amount of tokens being bought or sold on an advanced order does not meet the order's minimum amount.
error TokenMasterRouter__OrderDoesNotMeetMinimum();
/// @dev Thrown when the cumulative amount being bought, sold or spent on an advanced order exceeds the order's maximum total.
error TokenMasterRouter__OrderMaxTotalExceeded();
/// @dev Thrown when the cumulative amount being bought, sold or spent on an advanced order by a user exceeds the order's maximum for one user.
error TokenMasterRouter__OrderMaxPerWalletExceeded();
/// @dev Thrown when the supplied signature for an advanced order recovers to an address that is not authorized as an order signer.
error TokenMasterRouter__OrderSignerUnauthorized();
/// @dev Thrown when pairing with a token that has enabled pairing restrictions and the deployer or token are not specified as allowed.
error TokenMasterRouter__PairedTokenPairingRestricted();
/// @dev Thrown when attempting to use PermitC transfers with a token that is paired with the chain native token.
error TokenMasterRouter__PermitNotCompatibleWithNativeValue();
/// @dev Thrown when the permit transfer fails to execute the transfer of tokens to the pool.
error TokenMasterRouter__PermitTransferFailed();
/// @dev Thrown when deploying a token with a token factory specified that is not allowed by TokenMasterRouter.
error TokenMasterRouter__TokenFactoryNotAllowed();
/// @dev Thrown when attempting to buy, sell or spend a token that was not deployed with TokenMaster.
error TokenMasterRouter__TokenNotDeployedByTokenMaster();
/// @dev Thrown when a token has disabled transactions from untrusted channels and the call originates from a caller that is not trusted.
error TokenMasterRouter__TransactionOriginatedFromUntrustedChannel();

/// @dev Thrown when an address other than the router calls a function in a token that must be called by the router.
error TokenMasterERC20__CallerMustBeRouter();
/// @dev Thrown when attempting to withdraw an unrelated token from the pool and the address specified is the paired token.
error TokenMasterERC20__CannotWithdrawPairedToken();
/// @dev Thrown when attempting to withdraw an unrelated ERC20 token from the pool and the transfer fails.
error TokenMasterERC20__ERC20TransferFailed();
/// @dev Thrown when attempting to reset the token approval for the router to transfer paired tokens and the approval fails.
error TokenMasterERC20__FailedToSetApproval();
/// @dev Thrown when attempting to forfeit claimable emissions in an amount greater than the current claimable amount.
error TokenMasterERC20__ForfeitAmountGreaterThanClaimable();
/// @dev Thrown when the initial paired amount supplied is zero.
error TokenMasterERC20__InitialPairedDepositCannotBeZero();
/// @dev Thrown when the initial supply amount specified is zero.
error TokenMasterERC20__InitialSupplyCannotBeZero();
/// @dev Thrown when the amount of value supplied for a purchase of tokens is insufficient for the cost.
error TokenMasterERC20__InsufficientBuyInput();
/// @dev Thrown when the output value of paired tokens does not meet the sellers supplied minimum output.
error TokenMasterERC20__InsufficientSellOutput();
/// @dev Thrown when attempting to deploy or purchase an exceptionally large quantity of tokens that could destablize the token.
error TokenMasterERC20__InvalidPairedValues();
/// @dev Thrown when parameters that are being set are not within a valid range.
error TokenMasterERC20__InvalidParameters();
/// @dev Thrown when a transfer of native token value fails to execute.
error TokenMasterERC20__NativeTransferFailed();
/// @dev Thrown when adjusting the hard cap on claimable emissions and the value supplied is greater than the current cap.
error TokenMasterERC20__NewHardCapGreaterThanCurrent();
/// @dev Thrown when attempting to renounce ownership of a token contract.
error TokenMasterERC20__RenounceNotAllowed();
/// @dev Thrown when attempting to withdraw or transfer a creator share to market in an amount greater than the current creator share.
error TokenMasterERC20__WithdrawOrTransferAmountGreaterThanShare();

/// @dev Thrown when calling a function in a token contract that is not supported by the pool type.
error TokenMasterERC20__OperationNotSupportedByPool();
/// @dev Thrown when deploying a pool and an insufficient amount of value is provided for the initial supply requested.
error TokenMasterERC20__InsufficientSeedFunding();
/// @dev Thrown when multiple arrays are expected to be of equal lengths and their lengths are not equal.
error TokenMasterERC20__ArrayLengthMismatch();