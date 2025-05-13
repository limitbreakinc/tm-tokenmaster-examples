//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "@limitbreak/tm-core-lib/src/utils/structs/EnumerableSet.sol";

/**
 * @dev This struct defines storage for token settings.
 * 
 * @dev **flags**: Bit packed flags for token settings defined in constants.
 * @dev **spacer**: Unused
 * @dev **partnerFeeRecipient**: Address of the partner fee recipient for a token.
 * @dev **proposedPartnerFeeRecipient**: Address proposed by the current partner fee recipient to be the new fee recipient.
 * @dev **orderSigners**: Enumerable list of addresses that are allowed order signers.
 * @dev **trustedChannels**: Enumerable list of channels that are allowed for token transactions.
 * @dev **allowedPairToDeployers**: Enumberable list of deployers that are allowed to deploy tokens paired with the token.
 * @dev **allowedPairToTokens**: Enumberable list of tokens that are allowed to deploy as paired with the token.
 */
struct TokenSettings {
    uint8 flags;
    uint248 spacer;
    address partnerFeeRecipient;
    address proposedPartnerFeeRecipient;
    EnumerableSet.AddressSet orderSigners;
    EnumerableSet.AddressSet trustedChannels;
    EnumerableSet.AddressSet allowedPairToDeployers;
    EnumerableSet.AddressSet allowedPairToTokens;
}

/**
 * @dev This struct defines parameters used by the TokenMasterRouter and factories for deploying tokens.
 * 
 * @dev **tokenFactory**: The token factory to use to deploy a specific pool type.
 * @dev **tokenSalt**: The salt value to use when deploying the token to control the deterministic address.
 * @dev **tokenAddress**: The deterministic address of the token that will be deployed.
 * @dev **blockTransactionsFromUntrustedChannels**: Initial setting for blocking transactions from untrusted channels.
 * @dev **restrictPairingToLists**: Initial setting for restricting pairing of the new token with other tokens.
 * @dev **poolParams**: The parameters that will be sent during token contract construction.
 * @dev **maxInfrastructureFeeBPS**: The maximum infrastructure fee that is allowed without reverting the deployment.
 */
struct DeploymentParameters {
    address tokenFactory;
    bytes32 tokenSalt;
    address tokenAddress;
    bool blockTransactionsFromUntrustedChannels;
    bool restrictPairingToLists;
    PoolDeploymentParameters poolParams;
    uint16 maxInfrastructureFeeBPS;
}

/**
 * @dev This struct defines parameters that are sent by token factories to create a token contract.
 * 
 * @dev **name**: The name of the token.
 * @dev **symbol**: The symbol of the token.
 * @dev **decimals**: The number of decimals of the token.
 * @dev **initialOwner**: Address to set as the initial owner of the token.
 * @dev **pairedToken**: Address of the token to pair with the new token, for native token use `address(0)`.
 * @dev **initialPairedTokenToDeposit**: Amount of paired token to deposit to the new token pool.
 * @dev **encodedInitializationArgs**: Bytes array of ABI encoded initialization arguments to allow new pool types 
 * @dev with different types of constructor arguments that are decoded during deployment.
 * @dev **defaultTransferValidator**: Address of the initial transfer validator for a token.
 * @dev **useRouterForPairedTransfers**: If true, the pool will default to allowing the router to transfer paired tokens
 * @dev during operations that require the paired token to transfer from the pool. This is useful when pairing with
 * @dev ERC20C tokens that utilize the default operator whitelist which includes the TokenMasterRouter but does not
 * @dev include individual token pools.
 * @dev **partnerFeeRecipient**: The address that will receive partner fee shares.
 * @dev **partnerFeeBPS**: The fee rate in BPS for partner fees.
 */
struct PoolDeploymentParameters {
    string name;
    string symbol;
    uint8 tokenDecimals;
    address initialOwner;
    address pairedToken;
    uint256 initialPairedTokenToDeposit;
    bytes encodedInitializationArgs;
    address defaultTransferValidator;
    bool useRouterForPairedTransfers;
    address partnerFeeRecipient;
    uint256 partnerFeeBPS;
}

/**
 * @dev This struct defines storage for tracking advanced orders.
 * 
 * @dev **orderDisabled**: True if the order has been disabled by the creator.
 * @dev **orderTotal**: The total amount executed by all users on the order.
 * @dev **orderTotalPerWallet**: The total amount per wallet executed on the order.
 */
struct OrderTracking {
    bool orderDisabled;
    uint256 orderTotal;
    mapping (address => uint256) orderTotalPerWallet;
}

/**
 * @dev This struct defines buy order base parameters.
 * 
 * @dev **tokenMasterToken**: The address of the TokenMaster token to buy.
 * @dev **tokensToBuy**: The amount of tokens to buy.
 * @dev **pairedValueIn**: The amount of paired tokens to transfer in to the token contract for the purchase.
 */
struct BuyOrder {
    address tokenMasterToken;
    uint256 tokensToBuy;
    uint256 pairedValueIn;
}

/**
 * @dev This struct defines a permit transfer parameters.
 * 
 * @dev **permitProcessor**: The address of the PermitC-compliant permit processor to use for the transfer.
 * @dev **nonce**: The permit nonce to use for the permit transfer signature validation.
 * @dev **permitAmount**: The amount that the permit was signed for.
 * @dev **expiration**: The time, in seconds since the Unix epoch, that the permit will expire.
 * @dev **signedPermit**: The permit signature bytes authorizing the transfer.
 */
struct PermitTransfer {
    address permitProcessor;
    uint256 nonce;
    uint256 permitAmount;
    uint256 expiration;
    bytes signedPermit;
}

/**
 * @dev This struct defines sell order base parameters.
 * 
 * @dev **tokenMasterToken**: The address of the TokenMaster token to sell.
 * @dev **tokensToSell**: The amount of tokens to sell.
 * @dev **minimumOut**: The minimum output of paired tokens to be received by the seller without the transaction reverting.
 */
struct SellOrder {
    address tokenMasterToken;
    uint256 tokensToSell;
    uint256 minimumOut;
}

/**
 * @dev This struct defines spend order base parameters.
 * 
 * @dev **tokenMasterToken**: The address of the TokenMaster token to spend.
 * @dev **multiplier**: The multiplier of the signed spend order's `baseValue`, adjusted by an oracle if specified, to be spent.
 * @dev **maxAmountToSpend**: The maximum amount the spender will spend on the order without the transaction reverting.
 */
struct SpendOrder {
    address tokenMasterToken;
    uint256 multiplier;
    uint256 maxAmountToSpend;
}

/**
 * @dev This struct defines advanced order execution parameters.
 * 
 * @dev **creatorIdentifier**: A value specified by the creator to identify the order for any onchain or offchain benefits
 * @dev to the order executor for executing the order.
 * @dev **tokenMasterOracle**: An address for an onchain oracle that can adjust the `baseValue` for an advanced order.
 * @dev **baseToken**: An address for a token to base the `baseValue` on when adjusting value through a TokenMaster Oracle.
 * @dev **baseValue**: The amount of token required for the order to be executed.
 * @dev If `tokenMasterOracle` is set to `address(0)`, the `baseToken` will not be utilized and the advanced order will 
 * @dev execute with `baseValue` being the amount of the TokenMaster token to be required for the order.
 * @dev **maxPerWallet**: The maximum amount per wallet that can be executed on the order. For buy and sell advanced orders
 * @dev this amount is in the TokenMaster token amount, for spend orders it is multipliers.
 * @dev **maxPerWallet**: The maximum amount for all wallets that can be executed on the order. For buy and sell advanced orders
 * @dev this amount is in the TokenMaster token amount, for spend orders it is multipliers.
 * @dev **expiration**: The time, in seconds since the Unix epoch, that the order will expire.
 * @dev **hook**: An address for an onchain hook for an order to execute after the buy, sell or spend is executed.
 * @dev **signature**: The signature from an allowed order signer to authorize the order.
 * @dev **cosignature**: The cosignature from the cosigner specified by the order signer.
 * @dev **hookExtraData**: Extra data to send with the call to the onchain hook contract.
 * @dev **oracleExtraData**: Extra data to send with the call to the oracle contract.
 */
struct SignedOrder {
    bytes32 creatorIdentifier;
    address tokenMasterOracle;
    address baseToken;
    uint256 baseValue;
    uint256 maxPerWallet;
    uint256 maxTotal;
    uint256 expiration;
    address hook;
    SignatureECDSA signature;
    Cosignature cosignature;
    bytes hookExtraData;
    bytes oracleExtraData;
}

/**
 * @dev The `v`, `r`, and `s` components of an ECDSA signature.  For more information
 *      [refer to this article](https://medium.com/mycrypto/the-magic-of-digital-signatures-on-ethereum-98fe184dc9c7).
 */
struct SignatureECDSA {
    uint256 v;
    bytes32 r;
    bytes32 s;
}

/**
 * @dev This struct defines the cosignature for verifying an order that is a cosigned order.
 *
 * @dev **signer**: The address that signed the cosigned order. This must match the cosigner that is part of the order signature.
 * @dev **expiration**: The time, in seconds since the Unix epoch, that the cosignature will expire.
 * @dev The `v`, `r`, and `s` components of an ECDSA signature.  For more information
 *      [refer to this article](https://medium.com/mycrypto/the-magic-of-digital-signatures-on-ethereum-98fe184dc9c7).
 */
struct Cosignature {
    address signer;
    uint256 expiration;
    uint256 v;
    bytes32 r;
    bytes32 s;
}