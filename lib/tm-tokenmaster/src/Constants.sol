//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/// @dev Constant value for BPS where 1 BPS is 0.01%
uint16 constant BPS = 100_00;
/// @dev Constant value for zero.
uint256 constant ZERO = 0;
/// @dev Constant value for one.
uint256 constant ONE = 1;
// Target supply baseline is a uint48 multiplied by 10 ^ scale factor
// Limiting scale factor to 62 prevents an overflow of expected supply 
// since type(uint48).max * 10**62 equals 2.81e76.
// To overflow with target supply growth rate the current timestamp would need to exceed
// the baseline timestamp by 3.5e40 years.
uint16 constant MAX_BASELINE_SCALE_FACTOR = 62;

/// @dev Pausable flag to pause buys in a TokenMaster token.
uint256 constant PAUSE_FLAG_BUYS = 1 << 0;
/// @dev Pausable flag to pause sells in a TokenMaster token.
uint256 constant PAUSE_FLAG_SELLS = 1 << 1;
/// @dev Pausable flag to pause spends in a TokenMaster token.
uint256 constant PAUSE_FLAG_SPENDS = 1 << 2;

/// @dev EIP-712 typehash for deployments that require signature validation.
bytes32 constant DEPLOYMENT_TYPEHASH = keccak256("DeploymentParameters(address tokenFactory,bytes32 tokenSalt,address tokenAddress,bool blockTransactionsFromUntrustedChannels,bool restrictPairingToLists)");
/// @dev EIP-712 typehash for advanced buy orders.
bytes32 constant BUY_TYPEHASH = keccak256("BuyTokenMasterToken(bytes32 creatorBuyIdentifier,address tokenMasterToken,address tokenMasterOracle,address baseToken,uint256 baseValue,uint256 maxPerWallet,uint256 maxTotal,uint256 expiration,address hook,address cosigner)");
/// @dev EIP-712 typehash for advanced sell orders.
bytes32 constant SELL_TYPEHASH = keccak256("SellTokenMasterToken(bytes32 creatorSellIdentifier,address tokenMasterToken,address tokenMasterOracle,address baseToken,uint256 baseValue,uint256 maxPerWallet,uint256 maxTotal,uint256 expiration,address hook,address cosigner)");
/// @dev EIP-712 typehash for spend orders.
bytes32 constant SPEND_TYPEHASH = keccak256("SpendTokenMasterToken(bytes32 creatorSpendIdentifier,address tokenMasterToken,address tokenMasterOracle,address baseToken,uint256 baseValue,uint256 maxPerWallet,uint256 maxTotal,uint256 expiration,address hook,address cosigner)");
/// @dev EIP-712 tyephash for cosignatures.
bytes32 constant COSIGNATURE_TYPEHASH = keccak256("Cosignature(uint8 v,bytes32 r,bytes32 s,uint256 expiration,address executor)");
/// @dev EIP-712 typehash for advanced PermitC transfers.
bytes32 constant PERMITTED_TRANSFER_ADDITIONAL_DATA_BUY_TYPEHASH = keccak256("PermitTransferFromWithAdditionalData(uint256 tokenType,address token,uint256 id,uint256 amount,uint256 nonce,address operator,uint256 expiration,uint256 masterNonce,AdvancedBuyOrder advancedBuyOrder)AdvancedBuyOrder(address tokenMasterToken,uint256 tokensToBuy,uint256 pairedValueIn,bytes32 creatorBuyIdentifier,address hook,uint8 buyOrderSignatureV,bytes32 buyOrderSignatureR,bytes32 buyOrderSignatureS)");
/// @dev EIP-712 typehash for the advanced data struct in PermitC advanced transfers.
bytes32 constant PERMITTED_TRANSFER_BUY_TYPEHASH = keccak256("AdvancedBuyOrder(address tokenMasterToken,uint256 tokensToBuy,uint256 pairedValueIn,bytes32 creatorBuyIdentifier,address hook,uint8 buyOrderSignatureV,bytes32 buyOrderSignatureR,bytes32 buyOrderSignatureS)");

/// @dev Role constant for roles in a token to grant an address the ability to manage orders.
bytes32 constant ORDER_MANAGER_ROLE = bytes32(bytes4(keccak256("ORDER_MANAGER")));

/// @dev Base amount of calldata expected for a buy order when not being called by a trusted forwarder.
// | 4        | 96       | = 100 bytes
// | selector | buyOrder |
uint256 constant BASE_MSG_LENGTH_BUY_ORDER = 100;
/// @dev Base amount of calldata expected for an advanced buy order when not being called by a trusted forwarder.
// | 4        | 96       | 32                 | 32                    | 640         | 192            | = 996 bytes
// | selector | buyOrder | signedOrder Offset | permitTransfer Offset | signedOrder | permitTransfer |
uint256 constant BASE_MSG_LENGTH_BUY_ORDER_ADVANCED = 996;
/// @dev Base amount of calldata expected for a sell order when not being called by a trusted forwarder.
// | 4        | 96        | = 100 bytes
// | selector | sellOrder |
uint256 constant BASE_MSG_LENGTH_SELL_ORDER = 100;
/// @dev Base amount of calldata expected for an advanced sell order when not being called by a trusted forwarder.
// | 4        | 96        | 32                 | 640         | = 772 bytes
// | selector | sellOrder | signedOrder Offset | signedOrder |
uint256 constant BASE_MSG_LENGTH_SELL_ORDER_ADVANCED = 772;
/// @dev Base amount of calldata expected for a spend order when not being called by a trusted forwarder.
// | 4        | 96         | 32                 | 640         | = 772 bytes
// | selector | spendOrder | signedOrder Offset | signedOrder |
uint256 constant BASE_MSG_LENGTH_SPEND_ORDER = 772;
/// @dev Base amount of calldata expected for a token deployment when not being called by a trusted forwarder.
// | 4        | 32                         | 96        | 672                  | = 996 bytes
// | selector | deploymentParmeters Offset | signature | deploymentParameters |
uint256 constant BASE_MSG_LENGTH_DEPLOY_TOKEN = 804;

/// @dev Token setting flag to indicate a token was deployed by TokenMaster.
uint8 constant FLAG_DEPLOYED_BY_TOKENMASTER = 1 << 0;
/// @dev Token setting flag to block transactions from untrusted channels.
uint8 constant FLAG_BLOCK_TRANSACTIONS_FROM_UNTRUSTED_CHANNELS = 1 << 1;
/// @dev Token setting flag to restrict pairing of the token to only allowed addresses.
uint8 constant FLAG_RESTRICT_PAIRING_TO_LISTS = 1 << 2;

/// @dev Base role constant for the TokenMaster Admin in the Role Server.
bytes32 constant TOKENMASTER_ADMIN_BASE_ROLE = keccak256("TOKENMASTER_ADMIN_ROLE");
/// @dev Base role constant for the TokenMaster Deployment Signer in the Role Server.
bytes32 constant TOKENMASTER_SIGNER_BASE_ROLE = keccak256("TOKENMASTER_SIGNER_ROLE");
/// @dev Base role constant for the TokenMaster Fee Receiver in the Role Server.
bytes32 constant TOKENMASTER_FEE_RECEIVER_BASE_ROLE = keccak256("TOKENMASTER_FEE_RECEIVER");
/// @dev Base role constant for the TokenMaster Fee Collector in the Role Server.
bytes32 constant TOKENMASTER_FEE_COLLECTOR_BASE_ROLE = keccak256("TOKENMASTER_FEE_COLLECTOR");

/// @dev Transaction type value passed to a TokenMasterOracle when the transaction being executed is a buy.
uint256 constant ORACLE_BUY_TRANSACTION_TYPE = 0;
/// @dev Transaction type value passed to a TokenMasterOracle when the transaction being executed is a sell.
uint256 constant ORACLE_SELL_TRANSACTION_TYPE = 1;
/// @dev Transaction type value passed to a TokenMasterOracle when the transaction being executed is a spend.
uint256 constant ORACLE_SPEND_TRANSACTION_TYPE = 2;

/// @dev Constant value for the maximum address value for masking in factories.
address constant ADDRESS_MASK = address(type(uint160).max);
