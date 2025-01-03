//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./Constants.sol";
import "./DataTypes.sol";
import "./Errors.sol";
import "./interfaces/ITokenMasterRouter.sol";
import "./interfaces/ITokenMasterFactory.sol";
import "./interfaces/ITokenMasterOracle.sol";
import "./interfaces/ITokenMasterBuyHook.sol";
import "./interfaces/ITokenMasterSellHook.sol";
import "./interfaces/ITokenMasterSpendHook.sol";
import "./interfaces/ITokenMasterERC20C.sol";
import "./libraries/LibOwnership.sol";
import "@limitbreak/tm-core-lib/src/utils/security/RoleSetClient.sol";
import "@limitbreak/tm-core-lib/src/utils/structs/EnumerableSet.sol";
import "@limitbreak/tm-core-lib/src/utils/cryptography/EfficientHash.sol";
import "@limitbreak/tm-core-lib/src/utils/security/TstorishReentrancyGuard.sol";
import "@limitbreak/permit-c/openzeppelin-optimized/EIP712.sol";
import "@limitbreak/tm-core-lib/src/token/erc20/utils/SafeERC20.sol";
import "@limitbreak/tm-core-lib/src/token/erc20/IERC20.sol";
import "@limitbreak/permit-c/interfaces/IPermitC.sol";
import "@limitbreak/trusted-forwarder/TrustedForwarderERC2771Context.sol";
import "@limitbreak/tm-core-lib/src/licenses/LicenseRef-PolyForm-Strict-1.0.0.sol";

/**
 * @title  TokenMasterRouter
 * @author Limit Break, Inc.
 * @notice The TokenMasterRouter contract is designed to deploy, manage and transact with ERC20C tokens that 
 *         are paired with another asset.
 * 
 * @dev    <h4>Features</h4>
 *         - Deployment of ERC20C tokens.
 *         - Creator controls for token pairing.
 *         - Buy, sell and spend tokens created through TokenMasterRouter.
 *         - Advanced order hooks for buying, selling and spending tokens.
 *         - Oracle adjustments for advanced order cost thresholds.
 * 
 * @dev    <h4>Details</h4>
 *         Pairing Restrictions:
 *         TokenMasterRouter gives ERC20C token creators the ability to enforce pairing restrictions for their
 *         tokens with the ability to restrict new pair deployments to originating from a creator's Trusted Forwarder
 *         which allows the creator to sign off on the specific deployment parameters, restrict pairing to only tokens
 *         deployed by the creator, restrict what deployers may deploy a new pair, and restrict to specific token 
 *         addresses being deployed using the new token's deterministic deployment address.
 *         
 *         By default, any ERC20 token that has not restricted its pairing will be eligible to be used as a paired
 *         token.
 * 
 *         Tokens launched through TokenMasterRouter can be restricted to only trade through authorized 
 *         Trusted Forwarders for order attribution, permissioning and analytics.
 * 
 *         For the security of ERC20C tokens that whitelist TokenMasterRouter, transactions executing through 
 *         TokenMasterRouter must be from pairs that were deployed by TokenMasterRouter and the factory used for
 *         deployment must be an allowed factory set by the `TOKENMASTER_ADMIN_ROLE`.
 * 
 *         Buy / Sell / Spend Tokens:
 *         Tokens deployed through TokenMasterRouter are special ERC20C token contracts that are paired with 
 *         another token. Allowed factories may deploy pools with different mechanics - for example, one factory's
 *         tokens may have a fluctuating price based on buying and selling while another factory is fully stable.
 *         Buys will exchange a quantity of the paired token for the token being purchased, sells will exchange 
 *         the token for the paired token, and spends remove tokens from the spender's account with an event 
 *         emission for offchain actions by the creator and/or an onchain hook being executed.
 * 
 *         Advanced orders must be signed by an account that is authorized by the creator as an order signer.
 *         Advanced buys and sells execute an onchain hook, spends may execute an onchain hook but also emit an
 *         event the creator can utilize for offchain purposes. Advanced transactions include a `hookExtraData`
 *         parameter to provide additional data to the hook contract that is called.
 * 
 *         Oracles: 
 *         Advanced orders may include an oracle contract address that adjusts the token cost of an order
 *         based on any factor that is relevant to the transaction being executed. The `oracleExtraData`
 *         parameter can be used provide additional data to the oracle contract that is called.
 */
contract TokenMasterRouter is ITokenMasterRouter, RoleSetClient, TrustedForwarderERC2771Context, EIP712, TstorishReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    /// @dev Current infrastructure fee that will be included in newly deployed tokens.
    uint16 public infrastructureFeeBPS;
    /// @dev Mapping of allowed token factories, set by the TokenMaster Admin
    mapping (address => bool) public allowedTokenFactory;
    /// @dev Mapping of token settings set by the token owner or admin.
    mapping (address => TokenSettings) private tokenSettings;
    /// @dev Mapping of advanced order data to track amounts and status.
    mapping (bytes32 => OrderTracking) public orderTracking;

    /// @dev Role for the TokenMaster Admin in the Role Server.
    bytes32 private immutable TOKENMASTER_ADMIN_ROLE;
    /// @dev Role for the TokenMaster Deployment Signer in the Role Server.
    bytes32 private immutable TOKENMASTER_SIGNER_ROLE;
    /// @dev Role for the TokenMaster Fee Receiver in the Role Server.
    bytes32 private immutable TOKENMASTER_FEE_RECEIVER_ROLE;
    /// @dev Role for the TokenMaster Fee Collector in the Role Server.
    bytes32 private immutable TOKENMASTER_FEE_COLLECTOR_ROLE;

    modifier onlyAdminAuthority() {
        if (msg.sender != _getRoleHolder(TOKENMASTER_ADMIN_ROLE)) {
            revert TokenMasterRouter__CallerNotAllowed();
        }
        _;
    }

    constructor(
        address roleServer,
        bytes32 roleSet,
        address trustedForwarderFactory
    )
        RoleSetClient(roleServer, roleSet)
        TrustedForwarderERC2771Context(trustedForwarderFactory) 
        EIP712("TokenMasterRouter", "1") {

        TOKENMASTER_ADMIN_ROLE = _hashRoleSetRole(roleSet, TOKENMASTER_ADMIN_BASE_ROLE);
        TOKENMASTER_SIGNER_ROLE = _hashRoleSetRole(roleSet, TOKENMASTER_SIGNER_BASE_ROLE);
        TOKENMASTER_FEE_RECEIVER_ROLE = _hashRoleSetRole(roleSet, TOKENMASTER_FEE_RECEIVER_BASE_ROLE);
        TOKENMASTER_FEE_COLLECTOR_ROLE = _hashRoleSetRole(roleSet, TOKENMASTER_FEE_COLLECTOR_BASE_ROLE);
    }

    /**
     * @dev  Initializes role configuration during TokenMasterRouter deployment.
     */
    function _setupRoles(bytes32 roleSet) internal override {
        _setupRole(_hashRoleSetRole(roleSet, TOKENMASTER_ADMIN_BASE_ROLE), 0);
        _setupRole(_hashRoleSetRole(roleSet, TOKENMASTER_SIGNER_BASE_ROLE), 0);
        _setupRole(_hashRoleSetRole(roleSet, TOKENMASTER_FEE_RECEIVER_BASE_ROLE), 1 hours);
        _setupRole(_hashRoleSetRole(roleSet, TOKENMASTER_FEE_COLLECTOR_BASE_ROLE), 24 hours);
    }

    /*************************************************************************/
    /*                     BUY / SELL / SPEND FUNCTIONS                      */
    /*************************************************************************/

    /**
     * @notice  Executes a buy order for a token deployed through TokenMaster.
     * 
     * @dev     Throws when reentering the TokenMasterRouter contract before a prior call ends.
     * @dev     Throws when the calldata length does not match the expected length.
     * @dev     Throws when the token being purchased was not deployed through TokenMaster.
     * @dev     Throws when the token is configured to block transactions from untrusted
     * @dev     channels and the caller is not a trusted channel.
     * @dev     Throws when native value is sent for a token that is paired with an ERC20.
     * @dev     Throws when an ERC20 paired token fails to transfer to the token contract.
     * @dev     Throws when a refund is required by the router and the refund transfer fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Paired value is transferred from the buyer to the token contract.
     * @dev    2. Tokens are minted to the buyer.
     * @dev    3. A `BuyOrderFilled` event has been emitted.
     * 
     * @param  buyOrder  Basic buy order details.
     */
    function buyTokens(BuyOrder calldata buyOrder) external payable nonReentrant {
        address executor = _getExecutor(BASE_MSG_LENGTH_BUY_ORDER);

        (
            ITokenMasterERC20C tokenMasterToken,
        ) = _validateTokenSettingsForTransaction(buyOrder.tokenMasterToken);
        address pairedToken = tokenMasterToken.PAIRED_TOKEN();
        uint256 pairedValueIn = _transferPairedValueToPool(pairedToken, address(tokenMasterToken), executor, buyOrder.pairedValueIn);

        _executeBuy(tokenMasterToken, executor, pairedValueIn, buyOrder.tokensToBuy, pairedToken);
    }

    /**
     * @notice  Executes an advanced buy order for a token deployed through TokenMaster.
     * 
     * @dev     Throws when reentering the TokenMasterRouter contract before a prior call ends.
     * @dev     Throws when the calldata length does not match the expected length.
     * @dev     Throws when the token being purchased was not deployed through TokenMaster.
     * @dev     Throws when the token is configured to block transactions from untrusted
     * @dev     channels and the caller is not a trusted channel.
     * @dev     Throws when native value is sent for a token that is paired with an ERC20.
     * @dev     Throws when an ERC20 paired token fails to transfer to the token contract.
     * @dev     Throws when a refund is required by the router and the refund transfer fails.
     * @dev     If the advanced buy includes an advanced order -
     * @dev         Throws when the order has expired.
     * @dev         Throws when the order is not signed by an authorized signer.
     * @dev         Throws when a cosigner is specified and the cosignature is invalid.
     * @dev         Throws when the buy amount does not meet the order minimum.
     * @dev         Throws when the order has been disabled.
     * @dev         Throws when the order has a maximum total and the buy will exceed it.
     * @dev         Throws when the order has a maximum per wallet and the buy will exceed it.
     * @dev         Throws when the hook call reverts.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Paired value is transferred from the buyer to the token contract.
     * @dev    2. Tokens are minted to the buyer.
     * @dev    3. A `BuyOrderFilled` event has been emitted.
     * @dev    4. Buy hook is called if the advanced buy includes an advanced order.
     * 
     * @param  buyOrder        Basic buy order details.
     * @param  signedOrder     Advanced order details and signatures.
     * @param  permitTransfer  Permit transfer details if executing a permit transfer.
     */
    function buyTokensAdvanced(
        BuyOrder calldata buyOrder,
        SignedOrder calldata signedOrder,
        PermitTransfer calldata permitTransfer
    ) external payable nonReentrant {
        address executor = _getExecutor(
            _addAdjustedBytesLength(
                _addAdjustedBytesLength(
                    _addAdjustedBytesLength(
                        BASE_MSG_LENGTH_BUY_ORDER_ADVANCED,
                        permitTransfer.signedPermit.length
                    ),
                    signedOrder.oracleExtraData.length
                ),
                signedOrder.hookExtraData.length
            )
        );

        (
            ITokenMasterERC20C tokenMasterToken,
            TokenSettings storage settings
        ) = _validateTokenSettingsForTransaction(buyOrder.tokenMasterToken);
        address pairedToken = tokenMasterToken.PAIRED_TOKEN();

        uint256 pairedValueIn;
        if (permitTransfer.permitProcessor == address(0)) {
            pairedValueIn = _transferPairedValueToPool(pairedToken, address(tokenMasterToken), executor, buyOrder.pairedValueIn); 
        } else {
            pairedValueIn = _permitTransferTokensToBuy(
                executor,
                pairedToken,
                address(tokenMasterToken),
                buyOrder,
                signedOrder,
                permitTransfer
            );
        }

        (uint256 tokensToBuy, bool executeHook) = _validateBuyParameters(
            address(tokenMasterToken),
            settings.orderSigners,
            executor,
            buyOrder.tokensToBuy,
            signedOrder
        );

        _executeBuy(tokenMasterToken, executor, pairedValueIn, tokensToBuy, pairedToken);

        if (executeHook) {
            ITokenMasterBuyHook(signedOrder.hook).tokenMasterBuyHook(
                address(tokenMasterToken),
                executor,
                signedOrder.creatorIdentifier,
                tokensToBuy,
                signedOrder.hookExtraData
            );
        }
    }

    /**
     * @notice  Executes a sell order for a token deployed through TokenMaster.
     * 
     * @dev     Throws when reentering the TokenMasterRouter contract before a prior call ends.
     * @dev     Throws when the calldata length does not match the expected length.
     * @dev     Throws when the token being sold was not deployed through TokenMaster.
     * @dev     Throws when the token is configured to block transactions from untrusted
     * @dev     channels and the caller is not a trusted channel.
     * @dev     Throws when a transfer is required by the router and the transfer fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Sold tokens are burned by the token contract.
     * @dev    2. Paired tokens are transferred to the seller.
     * @dev    3. A `SellOrderFilled` event has been emitted.
     * 
     * @param  sellOrder  Basic sell order details.
     */
    function sellTokens(SellOrder calldata sellOrder) external nonReentrant {
        address executor = _getExecutor(BASE_MSG_LENGTH_SELL_ORDER);

        (
            ITokenMasterERC20C tokenMasterToken,
        ) = _validateTokenSettingsForTransaction(sellOrder.tokenMasterToken);

        _executeSell(tokenMasterToken, executor, sellOrder);
    }

    /**
     * @notice  Executes an advanced sell order for a token deployed through TokenMaster.
     * 
     * @dev     Throws when reentering the TokenMasterRouter contract before a prior call ends.
     * @dev     Throws when the calldata length does not match the expected length.
     * @dev     Throws when the token being sold was not deployed through TokenMaster.
     * @dev     Throws when the token is configured to block transactions from untrusted
     * @dev     channels and the caller is not a trusted channel.
     * @dev     Throws when a transfer is required by the router and the transfer fails.
     * @dev     Throws when the order has expired.
     * @dev     Throws when the order is not signed by an authorized signer.
     * @dev     Throws when a cosigner is specified and the cosignature is invalid.
     * @dev     Throws when the sell amount does not meet the order minimum.
     * @dev     Throws when the order has been disabled.
     * @dev     Throws when the order has a maximum total and the sell will exceed it.
     * @dev     Throws when the order has a maximum per wallet and the sell will exceed it.
     * @dev     Throws when the hook call reverts.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Sold tokens are burned by the token contract.
     * @dev    2. Paired tokens are transferred to the seller.
     * @dev    3. A `SellOrderFilled` event has been emitted.
     * @dev    4. Sell hook is called.
     * 
     * @param  sellOrder    Basic sell order details.
     * @param  signedOrder  Advanced order details and signatures.
     */
    function sellTokensAdvanced(SellOrder calldata sellOrder, SignedOrder calldata signedOrder) external nonReentrant {
        address executor = _getExecutor(
            _addAdjustedBytesLength(
                _addAdjustedBytesLength(
                    BASE_MSG_LENGTH_SELL_ORDER_ADVANCED,
                    signedOrder.oracleExtraData.length
                ),
                signedOrder.hookExtraData.length
            )
        );
        
        (
            ITokenMasterERC20C tokenMasterToken,
            TokenSettings storage settings
        ) = _validateTokenSettingsForTransaction(sellOrder.tokenMasterToken);

        _validateSellParameters(
            address(tokenMasterToken),
            settings.orderSigners,
            executor,
            sellOrder.tokensToSell,
            signedOrder
        );

        _executeSell(tokenMasterToken, executor, sellOrder);

        ITokenMasterSellHook(signedOrder.hook).tokenMasterSellHook(
            address(tokenMasterToken),
            executor,
            signedOrder.creatorIdentifier,
            sellOrder.tokensToSell,
            signedOrder.hookExtraData
        );
    }

    /**
     * @notice  Executes a spend order for a token deployed through TokenMaster.
     * 
     * @dev     Tokens spent are calculated by the base value on the signed order, adjusted
     * @dev     by an oracle if specified by the creator, times the multiplier on the spend
     * @dev     order.
     * 
     * @dev     Throws when reentering the TokenMasterRouter contract before a prior call ends.
     * @dev     Throws when the calldata length does not match the expected length.
     * @dev     Throws when the token being spent was not deployed through TokenMaster.
     * @dev     Throws when the token is configured to block transactions from untrusted
     * @dev     channels and the caller is not a trusted channel.
     * @dev     Throws when the order has expired.
     * @dev     Throws when the order is not signed by an authorized signer.
     * @dev     Throws when a cosigner is specified and the cosignature is invalid.
     * @dev     Throws when the amount to spend exceeds the user specified maximum.
     * @dev     Throws when the order has been disabled.
     * @dev     Throws when the order has a maximum total and the sell will exceed it.
     * @dev     Throws when the order has a maximum per wallet and the sell will exceed it.
     * @dev     Throws when the hook call reverts.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Spent tokens are burned by the token contract.
     * @dev    2. A `SpendOrderFilled` event has been emitted.
     * @dev    3. Spend hook is called, if spend order includes a hook.
     * 
     * @param  spendOrder   Basic spend details.
     * @param  signedOrder  Advanced spend details and signature.
     */
    function spendTokens(
        SpendOrder calldata spendOrder,
        SignedOrder calldata signedOrder
    ) external nonReentrant {
        address executor = _getExecutor(
            _addAdjustedBytesLength(
                _addAdjustedBytesLength(
                    BASE_MSG_LENGTH_SPEND_ORDER,
                    signedOrder.oracleExtraData.length
                ),
                signedOrder.hookExtraData.length
            )
        );

        (
            ITokenMasterERC20C tokenMasterToken,
            TokenSettings storage settings
        ) = _validateTokenSettingsForTransaction(spendOrder.tokenMasterToken);

        (uint256 amountToSpend, uint256 multiplier) = _validateSpendParameters(
            settings.orderSigners,
            executor,
            spendOrder,
            signedOrder
        );

        if (amountToSpend > spendOrder.maxAmountToSpend) {
            revert TokenMasterRouter__AmountToSpendExceedsMax();
        }

        tokenMasterToken.spendTokens(executor, amountToSpend);

        if (signedOrder.hook != address(0)) {
            ITokenMasterSpendHook(signedOrder.hook).tokenMasterSpendHook(
                address(tokenMasterToken),
                executor,
                signedOrder.creatorIdentifier,
                multiplier,
                signedOrder.hookExtraData
            );
        }

        emit SpendOrderFilled(address(tokenMasterToken), signedOrder.creatorIdentifier, executor, amountToSpend, multiplier);
    }

    /*************************************************************************/
    /*                           CREATOR FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Deploys a TokenMaster token using the parameters specified by the deployer.
     * 
     * @dev     Token deployments are deterministic, the provided address in deployment 
     * @dev     parameters *MUST* match the actual deployment address from the factory.
     * 
     * @dev     Partner fee recipient may only be changed after deployment by the 
     * @dev     the current partner proposing and the token owner accepting the 
     * @dev     proposed recipient. If no partner address is specified or the recipient
     * @dev     is a contract that cannot call the proposal function then the address
     * @dev     will not be changeable in the future. 
     * 
     * @dev     Throws when the calldata length does not match the expected length.
     * @dev     Throws when the paired token is configured to block transactions from 
     * @dev     untrusted channels and the caller is not a trusted channel.
     * @dev     Throws when the paired token is configured to limit pairings to lists
     * @dev     and the deployer or deterministic address of the token being deployed
     * @dev     are not on the list.
     * @dev     Throws when the specified token factory is not allowed by TokenMaster.
     * @dev     Throws when a signing authority is configured and the provided 
     * @dev     signature is not valid.
     * @dev     Throws when the initial paired value fails to transfer to the token 
     * @dev     contract address.
     * @dev     Throws when deploying a native-backed token and the supplied value
     * @dev     is not equal to the initial pairing amount.
     * @dev     Throws when the specified maximum infrastructure fee is less than
     * @dev     the current infrastructure fee setting.
     * @dev     Throws when the actual deployed address does not match the supplied
     * @dev     token address value.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Initial paired value is transferred to the deployed token.
     * @dev    2. The token contract is created.
     * @dev    3. The token is marked as deployed by TokenMaster and initial settings stored.
     * @dev    4. A `TokenMasterTokenDeployed` event has been emitted.
     * 
     * @param  deploymentParameters  The parameters for the token being deployed.
     * @param  signature             If a signing authority is set, the signature from 
     *                               the signing authority.
     *                               If no signing authority is set, this may be any value.
     */
    function deployToken(
        DeploymentParameters calldata deploymentParameters,
        SignatureECDSA calldata signature
    ) external payable {
        address deployer = _getExecutor(
            _addAdjustedBytesLength(
                _addAdjustedBytesLength(
                    _addAdjustedBytesLength(
                        BASE_MSG_LENGTH_DEPLOY_TOKEN,
                        bytes(deploymentParameters.poolParams.name).length
                    ),
                    bytes(deploymentParameters.poolParams.symbol).length
                ),
                deploymentParameters.poolParams.encodedInitializationArgs.length
            )
        );

        _validateTokenSettingsForDeployment(
            deployer,
            deploymentParameters.tokenAddress,
            deploymentParameters.poolParams.pairedToken
        );

        if (!allowedTokenFactory[deploymentParameters.tokenFactory]) {
            revert TokenMasterRouter__TokenFactoryNotAllowed();
        }

        address signerAuthority = _getRoleHolder(TOKENMASTER_SIGNER_ROLE);

        if (signerAuthority != address(0)) {
            _validateDeploymentSignature(deploymentParameters, signature, signerAuthority);
        }

        uint256 pairedTokenIn = _transferPairedValueToPool(
            deploymentParameters.poolParams.pairedToken,
            deploymentParameters.tokenAddress,
            deployer,
            deploymentParameters.poolParams.initialPairedTokenToDeposit
        );
        if (deploymentParameters.poolParams.pairedToken == address(0)) {
            if (msg.value != deploymentParameters.poolParams.initialPairedTokenToDeposit) {
                revert TokenMasterRouter__InvalidMessageValue();
            }
            (bool success,) = deploymentParameters.tokenAddress.call{value: msg.value}("");
            if (!success) {
                revert TokenMasterRouter__FailedToDepositInitialPairedFunds();
            }
        }

        uint16 _infrastructureFeeBPS = infrastructureFeeBPS;
        if (_infrastructureFeeBPS > deploymentParameters.maxInfrastructureFeeBPS) {
            revert TokenMasterRouter__InvalidInfrastructureFeeBPS();
        }

        address tokenMasterToken = ITokenMasterFactory(deploymentParameters.tokenFactory).deployToken(
            deploymentParameters.tokenSalt,
            deploymentParameters.poolParams,
            pairedTokenIn,
            _infrastructureFeeBPS
        );

        if (tokenMasterToken == address(0) || tokenMasterToken != deploymentParameters.tokenAddress) {
            revert TokenMasterRouter__DeployedTokenAddressMismatch();
        }

        uint8 flags = FLAG_DEPLOYED_BY_TOKENMASTER;
        if (deploymentParameters.blockTransactionsFromUntrustedChannels) {
            flags |= FLAG_BLOCK_TRANSACTIONS_FROM_UNTRUSTED_CHANNELS;
        }
        if (deploymentParameters.restrictPairingToLists) {
            flags |= FLAG_RESTRICT_PAIRING_TO_LISTS;
        }
        tokenSettings[tokenMasterToken].flags = flags;
        tokenSettings[tokenMasterToken].partnerFeeRecipient = deploymentParameters.poolParams.partnerFeeRecipient;

        emit TokenMasterTokenDeployed(tokenMasterToken, deploymentParameters.poolParams.pairedToken, deploymentParameters.tokenFactory);
    }

    /**
     * @notice  Updates settings for a token for any transaction executed on TokenMasterRouter.
     * 
     * @dev     Settings may be set for tokens that were not deployed through TokenMaster
     * @dev     so that a token owner may control pairings for their token.
     * 
     * @dev     Throws when the caller is not the token, owner or an admin for the token.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Token settings have been updated.
     * @dev    2. A `TokenSettingsUpdated` event has been emitted.
     * 
     * @param  tokenAddress                            The address of the token to set settings for.
     * @param  blockTransactionsFromUntrustedChannels  If true, requires transactions to be executed through 
     *                                                 a trusted channel.
     * @param  restrictPairingToLists                  If true, tokens can only be deployed if the deployer or 
     *                                                 token address are on an approved list.
     */
    function updateTokenSettings(
        address tokenAddress,
        bool blockTransactionsFromUntrustedChannels,
        bool restrictPairingToLists
    ) external {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdmin(tokenAddress);

        TokenSettings storage settings = tokenSettings[tokenAddress];
        settings.flags = 
            _setFlag(
                _setFlag(
                    settings.flags,
                    FLAG_BLOCK_TRANSACTIONS_FROM_UNTRUSTED_CHANNELS,
                    blockTransactionsFromUntrustedChannels
                ),
                FLAG_RESTRICT_PAIRING_TO_LISTS,
                restrictPairingToLists
            );
        
        emit TokenSettingsUpdated(tokenAddress, blockTransactionsFromUntrustedChannels, restrictPairingToLists);
    }

    /**
     * @notice  Sets or removes an address as an allowed signer for advanced orders for a token.
     * 
     * @dev     Throws when the caller is not the token, owner or an admin for the token.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The signer list for the token has been updated.
     * @dev    2. A `OrderSignerUpdated` event has been emitted.
     * 
     * @param  tokenMasterToken  The address of the token to update the signer for.
     * @param  signer            The address of the account to set or remove as a signer.
     * @param  allowed           If true, adds the account as a signer. If false, removes the account.
     */
    function setOrderSigner(address tokenMasterToken, address signer, bool allowed) external {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdmin(tokenMasterToken);

        if (allowed) {
            if (tokenSettings[tokenMasterToken].orderSigners.add(signer)) {
                emit OrderSignerUpdated(tokenMasterToken, signer, allowed);
            }
        } else {
            if (tokenSettings[tokenMasterToken].orderSigners.remove(signer)) {
                emit OrderSignerUpdated(tokenMasterToken, signer, allowed);
            }
        }
    }

    /**
     * @notice  Sets or removes an address as a trusted channel for a token.
     * 
     * @dev     Throws when the caller is not the token, owner or an admin for the token.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The trusted channel list for the token has been updated.
     * @dev    2. A `TrustedChannelUpdated` event has been emitted.
     * 
     * @param  tokenAddress  The address of the token to update the trusted channels for.
     * @param  channel       The address of the channel to set or remove as trusted.
     * @param  allowed       If true, adds the channel as a trusted. If false, removes the channel.
     */
    function setTokenAllowedTrustedChannel(address tokenAddress, address channel, bool allowed) external {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdmin(tokenAddress);

        if (allowed) {
            if (tokenSettings[tokenAddress].trustedChannels.add(channel)) {
                emit TrustedChannelUpdated(tokenAddress, channel, allowed);
            }
        } else {
            if (tokenSettings[tokenAddress].trustedChannels.remove(channel)) {
                emit TrustedChannelUpdated(tokenAddress, channel, allowed);
            }
        }
    }

    /**
     * @notice  Sets or removes an address as an allowed pair deployer.
     * 
     * @dev     Allowed pair deployers are allowed to deploy a token on TokenMaster
     * @dev     that pairs to the specified token when the token has pairing restrictions
     * @dev     enabled.
     * 
     * @dev     Throws when the caller is not the token, owner or an admin for the token.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The allowed pair to deployer list for the token has been updated.
     * @dev    2. A `AllowedPairToDeployersUpdated` event has been emitted.
     * 
     * @param  tokenAddress  The address of the token to update the allowed pair deployers for.
     * @param  deployer      The address of the deployer to set or remove as allowed.
     * @param  allowed       If true, adds the deployer as a allowed. If false, removes the deployer.
     */
    function setTokenAllowedPairToDeployer(address tokenAddress, address deployer, bool allowed) external {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdmin(tokenAddress);

        if (allowed) {
            if (tokenSettings[tokenAddress].allowedPairToDeployers.add(deployer)) {
                emit AllowedPairToDeployersUpdated(tokenAddress, deployer, allowed);
            }
        } else {
            if (tokenSettings[tokenAddress].allowedPairToDeployers.remove(deployer)) {
                emit AllowedPairToDeployersUpdated(tokenAddress, deployer, allowed);
            }
        }
    }

    /**
     * @notice  Sets or removes an address as an allowed pair token.
     * 
     * @dev     Allowed pair tokens are specific token addresses that are allowed to be 
     * @dev     with the specified token as the paired token. Token deployments in 
     * @dev     TokenMaster are deterministic so all of the settings may be validated
     * @dev     and the address precomputed to add as an allowed pair to token before
     * @dev     the token is deployed.
     * 
     * @dev     Throws when the caller is not the token, owner or an admin for the token.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The allowed pair to token list for the token has been updated.
     * @dev    2. A `AllowedPairToTokensUpdated` event has been emitted.
     * 
     * @param  tokenAddress        The address of the token to update the allowed pair tokens for.
     * @param  tokenAllowedToPair  The address of the token to set or remove as allowed.
     * @param  allowed             If true, adds the token as a allowed. If false, removes the token.
     */
    function setTokenAllowedPairToToken(address tokenAddress, address tokenAllowedToPair, bool allowed) external {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdmin(tokenAddress);

        if (allowed) {
            if (tokenSettings[tokenAddress].allowedPairToTokens.add(tokenAllowedToPair)) {
                emit AllowedPairToTokensUpdated(tokenAddress, tokenAllowedToPair, allowed);
            }
        } else {
            if (tokenSettings[tokenAddress].allowedPairToTokens.remove(tokenAllowedToPair)) {
                emit AllowedPairToTokensUpdated(tokenAddress, tokenAllowedToPair, allowed);
            }
        }
    }

    /**
     * @notice  Disables or re-enables a specific advanced buy order.
     *  
     * @dev     Throws when the caller is not the token, owner, an admin, or
     * @dev     order manager role holder for the token.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The specified order has been disabled or re-enabled.
     * @dev    2. A `BuyOrderDisabled` event has been emitted.
     * 
     * @param  tokenMasterToken  The address of the token to disable or re-enable the advanced order for.
     * @param  signedOrder       The advanced order details.
     * @param  disabled          If true, the order is disabled. If false, the order is re-enabled.
     */
    function disableBuyOrder(address tokenMasterToken, SignedOrder calldata signedOrder, bool disabled) external {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdminOrRole(
            tokenMasterToken,
            ORDER_MANAGER_ROLE
        );

        bytes32 buyOrderHash = _hashSignedOrder(BUY_TYPEHASH, tokenMasterToken, signedOrder);
        
        orderTracking[buyOrderHash].orderDisabled = disabled;
        emit BuyOrderDisabled(tokenMasterToken, signedOrder.creatorIdentifier, disabled);
    }

    /**
     * @notice  Disables or re-enables a specific advanced sell order.
     *  
     * @dev     Throws when the caller is not the token, owner, an admin, or
     * @dev     order manager role holder for the token.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The specified order has been disabled or re-enabled.
     * @dev    2. A `SellOrderDisabled` event has been emitted.
     * 
     * @param  tokenMasterToken  The address of the token to disable or re-enable the advanced order for.
     * @param  signedOrder       The advanced order details.
     * @param  disabled          If true, the order is disabled. If false, the order is re-enabled.
     */
    function disableSellOrder(address tokenMasterToken, SignedOrder calldata signedOrder, bool disabled) external {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdminOrRole(
            tokenMasterToken,
            ORDER_MANAGER_ROLE
        );

        bytes32 sellOrderHash = _hashSignedOrder(SELL_TYPEHASH, tokenMasterToken, signedOrder);
        
        orderTracking[sellOrderHash].orderDisabled = disabled;
        emit SellOrderDisabled(tokenMasterToken, signedOrder.creatorIdentifier, disabled);
    }

    /**
     * @notice  Disables or re-enables a specific spend order.
     *  
     * @dev     Throws when the caller is not the token, owner, an admin, or
     * @dev     order manager role holder for the token.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The specified order has been disabled or re-enabled.
     * @dev    2. A `SpendOrderDisabled` event has been emitted.
     * 
     * @param  tokenMasterToken  The address of the token to disable or re-enable the advanced order for.
     * @param  signedOrder       The advanced order details.
     * @param  disabled          If true, the order is disabled. If false, the order is re-enabled.
     */
    function disableSpendOrder(address tokenMasterToken, SignedOrder calldata signedOrder, bool disabled) external {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdminOrRole(
            tokenMasterToken,
            ORDER_MANAGER_ROLE
        );

        bytes32 spendOrderHash = _hashSignedOrder(SPEND_TYPEHASH, tokenMasterToken, signedOrder);
        
        orderTracking[spendOrderHash].orderDisabled = disabled;
        emit SpendOrderDisabled(tokenMasterToken, signedOrder.creatorIdentifier, disabled);
    }

    /**
     * @notice  Withdraws an amount of creator earnings from a TokenMaster token to a specified address.
     * 
     * @dev     Partner earnings and infrastructure fees are withdrawn at the same time.
     * 
     * @dev     Throws when the caller is not the token, owner or an admin for the token.
     * @dev     Throws when paired tokens are to be transferred by the router and a transfer fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The amount of creator share has been withdrawn.
     * @dev    2. The partner share has been withdrawn.
     * @dev    3. The infrastructure fees have been withdrawn.
     * 
     * @param  tokenMasterToken  The address of the token to withdraw creator share from.
     * @param  withdrawTo        The address to withdraw creator share to.
     * @param  withdrawAmount    The amount of creator share to withdraw.
     */
    function withdrawCreatorShare(ITokenMasterERC20C tokenMasterToken, address withdrawTo, uint256 withdrawAmount) external nonReentrant {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdmin(address(tokenMasterToken));
        
        address partnerFeeRecipient = tokenSettings[address(tokenMasterToken)].partnerFeeRecipient;
        address infrastructureFeeRecipient = _getRoleHolder(TOKENMASTER_FEE_RECEIVER_ROLE);
        (
            address pairedToken,
            uint256 transferByRouterAmountCreator,
            uint256 transferByRouterAmountInfrastructure,
            uint256 transferByRouterAmountPartner
        ) = tokenMasterToken.withdrawCreatorShare(withdrawTo, withdrawAmount, infrastructureFeeRecipient, partnerFeeRecipient);

        if (transferByRouterAmountCreator > 0) {
            _transferPoolPairedToken(
                tokenMasterToken,
                pairedToken,
                withdrawTo,
                transferByRouterAmountCreator
            );
        }

        if (transferByRouterAmountInfrastructure > 0) {
            _transferPoolPairedToken(
                tokenMasterToken,
                pairedToken,
                infrastructureFeeRecipient,
                transferByRouterAmountInfrastructure
            );
        }

        if (transferByRouterAmountPartner > 0) {
            _transferPoolPairedToken(
                tokenMasterToken,
                pairedToken,
                partnerFeeRecipient,
                transferByRouterAmountPartner
            );
        }
    }

    /**
     * @notice  Transfers an amount of creator earnings for a TokenMaster token to the token's market share.
     * 
     * @dev     Partner earnings and infrastructure fees are withdrawn during this transaction.
     * 
     * @dev     Throws when the caller is not the token, owner or an admin for the token.
     * @dev     Throws when paired tokens are to be transferred by the router and a transfer fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The amount of creator share has been transfered to market share.
     * @dev    2. The partner share has been withdrawn.
     * @dev    3. The infrastructure fees have been withdrawn.
     * 
     * @param  tokenMasterToken  The address of the token to transfer creator share to market share on.
     * @param  transferAmount    The amount of creator share to transfer to the market share.
     */
    function transferCreatorShareToMarket(ITokenMasterERC20C tokenMasterToken, uint256 transferAmount) external nonReentrant {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdmin(address(tokenMasterToken));
        
        address partnerFeeRecipient = tokenSettings[address(tokenMasterToken)].partnerFeeRecipient;
        address infrastructureFeeRecipient = _getRoleHolder(TOKENMASTER_FEE_RECEIVER_ROLE);
        (
            address pairedToken,
            uint256 transferByRouterAmountInfrastructure,
            uint256 transferByRouterAmountPartner
        ) = tokenMasterToken.transferCreatorShareToMarket(transferAmount, infrastructureFeeRecipient, partnerFeeRecipient);

        if (transferByRouterAmountInfrastructure > 0) {
            _transferPoolPairedToken(
                tokenMasterToken,
                pairedToken,
                infrastructureFeeRecipient,
                transferByRouterAmountInfrastructure
            );
        }

        if (transferByRouterAmountPartner > 0) {
            _transferPoolPairedToken(
                tokenMasterToken,
                pairedToken,
                partnerFeeRecipient,
                transferByRouterAmountPartner
            );
        }
    }

    /**
     * @notice  Accepts a proposed partner fee receiver update from the partner fee receiver.
     * 
     * @dev     Throws when the caller is not the token, owner or an admin for the token.
     * @dev     Throws when the proposed partner fee recipient address is the zero address.
     * @dev     Throws when the proposed partner fee recipient address does not match the expected address.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The partner fee recipient has been updated.
     * @dev    2. A `PartnerFeeRecipientUpdated` event has been emitted.
     * 
     * @param  tokenMasterToken             The address of the token to accept the proposed fee receiver on.
     * @param  expectedPartnerFeeRecipient  The address the caller expects to be the proposed address.
     */
    function acceptProposedPartnerFeeReceiver(address tokenMasterToken, address expectedPartnerFeeRecipient) external {
        LibOwnership.requireCallerIsTokenOrContractOwnerOrAdmin(tokenMasterToken);

        TokenSettings storage settings = tokenSettings[tokenMasterToken];
        address proposedPartnerFeeRecipient = settings.proposedPartnerFeeRecipient;
        if (
            proposedPartnerFeeRecipient == address(0)
            || proposedPartnerFeeRecipient != expectedPartnerFeeRecipient
        ) {
            revert TokenMasterRouter__InvalidRecipient();
        }
        settings.partnerFeeRecipient = proposedPartnerFeeRecipient;
        settings.proposedPartnerFeeRecipient = address(0);

        emit PartnerFeeRecipientUpdated(tokenMasterToken, proposedPartnerFeeRecipient);
    }

    /*************************************************************************/
    /*                           PARTNER FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Proposes a new partner fee receiver for a token.
     * 
     * @dev     Throws when the caller is not the current partner fee receiver.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The proposed partner fee recipient has been updated.
     * @dev    2. A `PartnerFeeRecipientProposed` event has been emitted.
     * 
     * @param  tokenMasterToken             The address of the token to propose the fee receiver on.
     * @param  proposedPartnerFeeRecipient  The address to propose.
     */
    function partnerProposeFeeReceiver(
        address tokenMasterToken,
        address proposedPartnerFeeRecipient
    ) external {
        TokenSettings storage settings = tokenSettings[tokenMasterToken];
        address partnerFeeRecipient = settings.partnerFeeRecipient;

        if (msg.sender != partnerFeeRecipient) {
            revert TokenMasterRouter__CallerNotAllowed();
        }
        
        settings.proposedPartnerFeeRecipient = proposedPartnerFeeRecipient;
        emit PartnerFeeRecipientProposed(tokenMasterToken, proposedPartnerFeeRecipient);
    }

    /*************************************************************************/
    /*                          FEE MGMT FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Withdraws partner shares and infrastructure fees from many TokenMaster tokens.
     * 
     * @dev     Throws when the caller is not the TokenMaster fee collector or partner fee recipient.
     * @dev     Throws when a transfer is to be made by the router and the transfer fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Partner fees for each token have been transferred to their receiver.
     * @dev    2. Infrastructure fees for each token have been transferred to the fee receiver.
     * 
     * @param  tokenMasterTokens  Array of token addresses to withdraw fees from.
     */
    function withdrawFees(ITokenMasterERC20C[] calldata tokenMasterTokens) external nonReentrant {
        bool authorized = msg.sender == _getRoleHolder(TOKENMASTER_FEE_COLLECTOR_ROLE);
        address infrastructureFeeRecipient = _getRoleHolder(TOKENMASTER_FEE_RECEIVER_ROLE);
        for (uint256 i; i < tokenMasterTokens.length; ++i) {
            ITokenMasterERC20C tokenMasterToken = tokenMasterTokens[i];
            TokenSettings storage settings = tokenSettings[address(tokenMasterToken)];
            address partnerFeeRecipient = settings.partnerFeeRecipient;

            if (!authorized) {
                if (msg.sender != partnerFeeRecipient) {
                    revert TokenMasterRouter__CallerNotAllowed();
                }
            }
            
            (
                address pairedToken,
                uint256 transferByRouterAmountInfrastructure,
                uint256 transferByRouterAmountPartner
            ) = tokenMasterToken.withdrawFees(infrastructureFeeRecipient, partnerFeeRecipient);

            if (transferByRouterAmountInfrastructure > 0) {
                _transferPoolPairedToken(
                    tokenMasterToken,
                    pairedToken,
                    infrastructureFeeRecipient,
                    transferByRouterAmountInfrastructure
                );
            }

            if (transferByRouterAmountPartner > 0) {
                _transferPoolPairedToken(
                    tokenMasterToken,
                    pairedToken,
                    partnerFeeRecipient,
                    transferByRouterAmountPartner
                );
            }
        }
    }

    /*************************************************************************/
    /*                             ADMIN FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Sets or removes an allowed token factory for token deployments.
     * 
     * @dev     Throws when the caller is not the TokenMaster admin.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The token factory allowed state has been updated.
     * @dev    2. A `AllowedTokenFactoryUpdated` event has been emitted.
     * 
     * @param  tokenFactory  Address of the token factory to update.
     * @param  allowed       If true, the factory will be allowed to deploy tokens.
     */
    function setAllowedTokenFactory(
        address tokenFactory,
        bool allowed
    ) external onlyAdminAuthority {
        allowedTokenFactory[tokenFactory] = allowed;

        emit AllowedTokenFactoryUpdated(tokenFactory, allowed);
    }

    /**
     * @notice  Sets the infrastructure fee for new TokenMaster deployments.
     * 
     * @dev     Throws when the caller is not the TokenMaster admin.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The infrastructure fee has been updated for new deployments.
     * @dev    2. A `InfrastructureFeeUpdated` event has been emitted.
     * 
     * @param  _infrastructureFeeBPS  The fee rate, in BPS, to apply to new deployments.
     */
    function setInfrastructureFee(uint16 _infrastructureFeeBPS) external onlyAdminAuthority {
        if (_infrastructureFeeBPS > BPS) {
            revert TokenMasterRouter__InvalidInfrastructureFeeBPS();
        }

        infrastructureFeeBPS = _infrastructureFeeBPS;
        emit InfrastructureFeeUpdated(_infrastructureFeeBPS);
    }

    /*************************************************************************/
    /*                            VIEW FUNCTIONS                             */
    /*************************************************************************/

    /**
     * @notice  Gets the current status of a buy order and checks signature, cosignature validity.
     * 
     * @dev     Throws when the a supplied signature has an invalid `v` value.
     * @dev     Throws when a signed order has a cosignature and the cosignature is expired.
     * 
     * @param  tokenMasterToken  The address of the token the buy order is for.
     * @param  signedOrder       The signed buy order to get tracking data for.
     * @param  buyer             The address of the buyer.
     * 
     * @return  totalBought        If the buy order has a max total, the amount that has been purchased.
     * @return  totalWalletBought  If the buy order has a max per wallet, the amount that has been purchased by the buyer.
     * @return  orderDisabled      True if the order has been disabled by the creator.
     * @return  signatureValid     True if the supplied signature is valid for the order.
     * @return  cosignatureValid   True if there is no cosignature required or if the cosignature is valid for the order.
     */
    function getBuyTrackingData(
        address tokenMasterToken,
        SignedOrder calldata signedOrder,
        address buyer
    ) external view returns (
        uint256 totalBought,
        uint256 totalWalletBought,
        bool orderDisabled,
        bool signatureValid,
        bool cosignatureValid
    ) {
        bytes32 buyOrderHash = _hashSignedOrder(BUY_TYPEHASH, tokenMasterToken, signedOrder);
        OrderTracking storage orderData = orderTracking[buyOrderHash];
        orderDisabled = orderData.orderDisabled;
        totalBought = orderData.orderTotal;
        totalWalletBought = orderData.orderTotalPerWallet[buyer];
        if (signedOrder.expiration >= block.timestamp) {
            signatureValid = _validateOrderSignature(
                tokenSettings[tokenMasterToken].orderSigners,
                buyOrderHash,
                signedOrder.signature
            );
            if (signedOrder.cosignature.signer == address(0)) {
                cosignatureValid = true;
            } else {
                cosignatureValid = _validateCosignature(buyer, signedOrder.signature, signedOrder.cosignature);
            }
        }
    }

    /**
     * @notice  Gets the current status of a sell order and checks signature, cosignature validity.
     * 
     * @dev     Throws when the a supplied signature has an invalid `v` value.
     * @dev     Throws when a signed order has a cosignature and the cosignature is expired.
     * 
     * @param  tokenMasterToken  The address of the token the sell order is for.
     * @param  signedOrder       The signed sell order to get tracking data for.
     * @param  seller            The address of the seller.
     * 
     * @return  totalSold         If the sell order has a max total, the amount that has been sold.
     * @return  totalWalletSold   If the sell order has a max per wallet, the amount that has been sold by the seller.
     * @return  orderDisabled     True if the order has been disabled by the creator.
     * @return  signatureValid    True if the supplied signature is valid for the order.
     * @return  cosignatureValid  True if there is no cosignature required or if the cosignature is valid for the order.
     */
    function getSellTrackingData(
        address tokenMasterToken,
        SignedOrder calldata signedOrder,
        address seller
    ) external view returns (
        uint256 totalSold,
        uint256 totalWalletSold,
        bool orderDisabled,
        bool signatureValid,
        bool cosignatureValid
    ) {
        bytes32 sellOrderHash = _hashSignedOrder(SELL_TYPEHASH, tokenMasterToken, signedOrder);
        OrderTracking storage orderData = orderTracking[sellOrderHash];
        orderDisabled = orderData.orderDisabled;
        totalSold = orderData.orderTotal;
        totalWalletSold = orderData.orderTotalPerWallet[seller];
        if (signedOrder.expiration >= block.timestamp) {
            signatureValid = _validateOrderSignature(
                tokenSettings[tokenMasterToken].orderSigners,
                sellOrderHash,
                signedOrder.signature
            );
            if (signedOrder.cosignature.signer == address(0)) {
                cosignatureValid = true;
            } else {
                cosignatureValid = _validateCosignature(seller, signedOrder.signature, signedOrder.cosignature);
            }
        }
    }

    /**
     * @notice  Gets the current status of a spend order and checks signature, cosignature validity.
     * 
     * @dev     Throws when the a supplied signature has an invalid `v` value.
     * @dev     Throws when a signed order has a cosignature and the cosignature is expired.
     * 
     * @param  tokenMasterToken  The address of the token the spend order is for.
     * @param  signedOrder       The signed spend order to get tracking data for.
     * @param  spender            The address of the spender.
     * 
     * @return  totalMultipliersSpent        If the spend order has a max total, the amount of multipliers spent.
     * @return  totalWalletMultipliersSpent  If the spend order has a max per wallet, the amount of multipliers spent by the spender.
     * @return  orderDisabled                True if the order has been disabled by the creator.
     * @return  signatureValid               True if the supplied signature is valid for the order.
     * @return  cosignatureValid             True if there is no cosignature required or if the cosignature is valid for the order.
     */
    function getSpendTrackingData(
        address tokenMasterToken,
        SignedOrder calldata signedOrder,
        address spender
    ) external view returns (
        uint256 totalMultipliersSpent,
        uint256 totalWalletMultipliersSpent,
        bool orderDisabled,
        bool signatureValid,
        bool cosignatureValid
    ) {
        bytes32 spendOrderHash = _hashSignedOrder(SPEND_TYPEHASH, tokenMasterToken, signedOrder);
        OrderTracking storage orderData = orderTracking[spendOrderHash];
        orderDisabled = orderData.orderDisabled;
        totalMultipliersSpent = orderData.orderTotal;
        totalWalletMultipliersSpent = orderData.orderTotalPerWallet[spender];
        if (signedOrder.expiration >= block.timestamp) {
            signatureValid = _validateOrderSignature(
                tokenSettings[tokenMasterToken].orderSigners,
                spendOrderHash,
                signedOrder.signature
            );
            if (signedOrder.cosignature.signer == address(0)) {
                cosignatureValid = true;
            } else {
                cosignatureValid = _validateCosignature(spender, signedOrder.signature, signedOrder.cosignature);
            }
        }
    }

    /**
     * @notice  Gets the current settings for a token.
     * 
     * @param tokenAddress  The address of the token to get settings for.
     * 
     * @return deployedByTokenMaster                   True if the token was deployed through TokenMaster.
     * @return blockTransactionsFromUntrustedChannels  True if transactions must be executed through a trusted channel.
     * @return restrictPairingToLists                  True if tokens pairing with the token must be on an approved list.
     * @return partnerFeeRecipient                     The address of the partner fee recipient.
     */
    function getTokenSettings(
        address tokenAddress
    ) external view returns (
        bool deployedByTokenMaster,
        bool blockTransactionsFromUntrustedChannels,
        bool restrictPairingToLists,
        address partnerFeeRecipient
    ) {
        TokenSettings storage settings = tokenSettings[tokenAddress];

        uint8 flags = settings.flags;
        deployedByTokenMaster = _isFlagSet(flags, FLAG_DEPLOYED_BY_TOKENMASTER);
        blockTransactionsFromUntrustedChannels = _isFlagSet(flags, FLAG_BLOCK_TRANSACTIONS_FROM_UNTRUSTED_CHANNELS);
        restrictPairingToLists = _isFlagSet(flags, FLAG_RESTRICT_PAIRING_TO_LISTS);

        partnerFeeRecipient = settings.partnerFeeRecipient;
    }

    /**
     * @notice  Returns an array of all active order signers for a token.
     * 
     * @param tokenMasterToken  The address of the token to get signers for.
     * 
     * @return orderSigners  An array of signer addresses.
     */
    function getOrderSigners(address tokenMasterToken) external view returns (address[] memory orderSigners) {
        orderSigners = tokenSettings[tokenMasterToken].orderSigners.values();
    }

    /**
     * @notice  Returns an array of trusted channels for a token.
     * 
     * @param tokenMasterToken  The address of the token to get trusted channels for.
     * 
     * @return trustedChannels  An array of trusted channel addresses.
     */
    function getTrustedChannels(address tokenMasterToken) external view returns (address[] memory trustedChannels) {
        trustedChannels = tokenSettings[tokenMasterToken].trustedChannels.values();
    }

    /**
     * @notice  Returns an array of all active pair deployers for a token.
     * 
     * @param tokenMasterToken  The address of the token to get pair deployers for.
     * 
     * @return allowedPairToDeployers  An array of pair deployer addresses.
     */
    function getAllowedPairToDeployers(address tokenMasterToken) external view returns (address[] memory allowedPairToDeployers) {
        allowedPairToDeployers = tokenSettings[tokenMasterToken].allowedPairToDeployers.values();
    }

    /**
     * @notice  Returns an array of all active token addresses that may pair to a token.
     * 
     * @param tokenMasterToken  The address of the token to get pair token addresses for.
     * 
     * @return allowedPairToTokens  An array of token addresses that may pair to the TokenMaster token.
     */
    function getAllowedPairToTokens(address tokenMasterToken) external view returns (address[] memory allowedPairToTokens) {
        allowedPairToTokens = tokenSettings[tokenMasterToken].allowedPairToTokens.values();
    }

    /*************************************************************************/
    /*                           INTERNAL FUNCTIONS                          */
    /*************************************************************************/

    /**
     * @dev  Validates that a token was deployed by TokenMaster and, if untrusted channels are blocked,
     * @dev  that the caller is a trusted channel.
     * 
     * @return tokenMasterToken  Cast version of the token address to ITokenMasterERC20C for stack optimization.
     * @return settings          Storage pointer to the token settings for stack optimization.
     */
    function _validateTokenSettingsForTransaction(
        address token
    ) internal view returns (ITokenMasterERC20C tokenMasterToken, TokenSettings storage settings) {
        tokenMasterToken = ITokenMasterERC20C(token);
        settings = tokenSettings[token];

        uint8 flags = settings.flags;
        if (!_isFlagSet(flags, FLAG_DEPLOYED_BY_TOKENMASTER)) {
            revert TokenMasterRouter__TokenNotDeployedByTokenMaster();
        }
        if (_isFlagSet(flags, FLAG_BLOCK_TRANSACTIONS_FROM_UNTRUSTED_CHANNELS)) {
            if (!settings.trustedChannels.contains(msg.sender)) {
                revert TokenMasterRouter__TransactionOriginatedFromUntrustedChannel();
            }
        }
    }

    /**
     * @dev  Validates the paired token's settings to ensure the deployment being executed
     * @dev  is permitted by the paired token's creator.
     */
    function _validateTokenSettingsForDeployment(
        address deployer,
        address tokenAddress,
        address pairedToken
    ) internal view {
        TokenSettings storage settings = tokenSettings[pairedToken];

        uint8 flags = settings.flags;
        if (_isFlagSet(flags, FLAG_BLOCK_TRANSACTIONS_FROM_UNTRUSTED_CHANNELS)) {
            if (!settings.trustedChannels.contains(msg.sender)) {
                revert TokenMasterRouter__TransactionOriginatedFromUntrustedChannel();
            }
        }
        if (_isFlagSet(flags, FLAG_RESTRICT_PAIRING_TO_LISTS)) {
            if (!LibOwnership.isCallerTokenOrContractOwnerOrAdmin(deployer, pairedToken)) {
                if (!settings.allowedPairToDeployers.contains(deployer)) {
                    if (!settings.allowedPairToTokens.contains(tokenAddress)) {
                        revert TokenMasterRouter__PairedTokenPairingRestricted();
                    }
                }
            }
        }
    }

    /**
     * @dev  Transfers an amount of the paired token from the executor to the TokenMaster token.
     * 
     * @dev  Throws when native value is sent for a token that is paired with an ERC20.
     * @dev  Throws when an ERC20 paired token fails to transfer to the token contract.
     * @dev  Throws when the paired token balance in the pool decreases after the transfer.
     * 
     * @param  pairedToken       Address of the paired token to transfer to the pool.
     * @param  tokenMasterToken  Address of the TokenMaster token to transfer paired tokens to.
     * @param  executor          Address of the account executing the transaction to withdraw paired tokens from.
     * @param  transferAmount    Amount of tokens to transfer to the pool.
     * 
     * @return pairedValueIn  The amount of paired value that has been sent to the pool.
     */
    function _transferPairedValueToPool(
        address pairedToken,
        address tokenMasterToken,
        address executor,
        uint256 transferAmount
    ) internal returns (uint256 pairedValueIn) {
        pairedValueIn = msg.value;
        if (pairedToken != address(0)) {
            if (msg.value > 0) {
                revert TokenMasterRouter__NativeValueNotAllowedOnERC20();
            }
            uint256 pairedBalanceBefore = IERC20(pairedToken).balanceOf(address(tokenMasterToken));
            bool isError = SafeERC20.safeTransferFrom(pairedToken, executor, address(tokenMasterToken), transferAmount);
            if (isError) {
                revert TokenMasterRouter__FailedToTransferPairedToken();
            }
            uint256 pairedBalanceAfter = IERC20(pairedToken).balanceOf(address(tokenMasterToken));
            if (pairedBalanceAfter < pairedBalanceBefore) {
                revert TokenMasterRouter__FailedToTransferPairedToken();
            }
            unchecked {
                pairedValueIn = pairedBalanceAfter - pairedBalanceBefore;
            }
        }
    }

    /**
     * @dev  Transfers an amount of the paired token from the executor to the TokenMaster token
     * @dev  using PermitC's permit transfer function.
     * 
     * @dev  Throws when the paired token address is the native token.
     * @dev  Throws when an ERC20 paired token fails to transfer to the token contract.
     * @dev  Throws when the paired token balance in the pool decreases after the transfer.
     * 
     * @param  executor          Address of the account executing the transaction to withdraw paired tokens from.
     * @param  pairedToken       Address of the paired token to transfer to the pool.
     * @param  tokenMasterToken  Address of the TokenMaster token to transfer paired tokens to.
     * @param  buyOrder          Basic buy order details.
     * @param  signedOrder       Advanced order details and signatures.
     * @param  permitTransfer    Permit transfer details for the permit transfer.
     * 
     * @return pairedValueIn  The amount of paired value that has been sent to the pool.
     */
    function _permitTransferTokensToBuy(
        address executor,
        address pairedToken,
        address tokenMasterToken,
        BuyOrder calldata buyOrder,
        SignedOrder calldata signedOrder,
        PermitTransfer calldata permitTransfer
    ) internal returns (uint256 pairedValueIn) {
        if (pairedToken == address(0)) {
            revert TokenMasterRouter__PermitNotCompatibleWithNativeValue();
        }

        uint256 pairedBalanceBefore = IERC20(pairedToken).balanceOf(tokenMasterToken);

        bool isError = IPermitC(permitTransfer.permitProcessor).permitTransferFromWithAdditionalDataERC20(
            pairedToken,
            permitTransfer.nonce,
            permitTransfer.permitAmount,
            permitTransfer.expiration,
            executor,
            tokenMasterToken,
            buyOrder.pairedValueIn,
            _hashBuyOrderPermitAdvancedData(buyOrder, signedOrder),
            PERMITTED_TRANSFER_ADDITIONAL_DATA_BUY_TYPEHASH,
            permitTransfer.signedPermit
        );
        if (isError) {
            revert TokenMasterRouter__PermitTransferFailed();
        }

        uint256 pairedBalanceAfter = IERC20(pairedToken).balanceOf(tokenMasterToken);
        if (pairedBalanceAfter < pairedBalanceBefore) {
            revert TokenMasterRouter__FailedToTransferPairedToken();
        }

        unchecked {
            pairedValueIn = pairedBalanceAfter - pairedBalanceBefore;
        }
    }

    /**
     * @dev  Executes a buy for tokens from a TokenMaster token.
     * 
     * @param  tokenMasterToken  The token to buy tokens of.
     * @param  pairedValueIn     Amount of paired value to buy tokens with.
     * @param  tokensToBuy       Amount of tokens to purchase.
     * @param  pairedToken       Address of the token paired with the TokenMaster token.
     */
    function _executeBuy(
        ITokenMasterERC20C tokenMasterToken,
        address executor,
        uint256 pairedValueIn,
        uint256 tokensToBuy,
        address pairedToken
    ) internal {
        (
            uint256 totalCost,
            uint256 refundByRouterAmount
        ) = tokenMasterToken.buyTokens{value: msg.value}(executor, pairedValueIn, tokensToBuy);

        if (refundByRouterAmount > 0) {
            _transferPoolPairedToken(
                tokenMasterToken,
                pairedToken,
                executor,
                refundByRouterAmount
            );
        }

        emit BuyOrderFilled(address(tokenMasterToken), executor, tokensToBuy, totalCost);
    }

    /**
     * @dev  Validation function for an advanced buy order.
     * 
     * @dev  Throws when the order has expired.
     * @dev  Throws when the order is not signed by an authorized signer.
     * @dev  Throws when a cosigner is specified and the cosignature is invalid.
     * @dev  Throws when the buy amount does not meet the order minimum.
     * @dev  Throws when the order has been disabled.
     * @dev  Throws when the order has a maximum total and the buy will exceed it.
     * @dev  Throws when the order has a maximum per wallet and the buy will exceed it.
     * 
     * @param  tokenMasterToken  The token to buy tokens of.
     * @param  orderSigners      Storage pointer for allowed signer addresses.
     * @param  executor          Address of the advanced order buyer.
     * @param  orderTokensToBuy  Amount of tokens being bought.
     * @param  signedOrder       Advanced order details and signatures.
     * 
     * @return  tokensToBuy  Amount of tokens being purchased, returned for stack optimization.
     * @return  executeHook  If true, the advanced order hook will execute after the buy.
     */
    function _validateBuyParameters(
        address tokenMasterToken,
        EnumerableSet.AddressSet storage orderSigners,
        address executor,
        uint256 orderTokensToBuy,
        SignedOrder calldata signedOrder
    ) internal returns (uint256 tokensToBuy, bool executeHook) {
        tokensToBuy = orderTokensToBuy;
        executeHook = signedOrder.hook != address(0);
        if (executeHook) {
            if (signedOrder.expiration < block.timestamp) {
                revert TokenMasterRouter__OrderExpired();
            }
            bytes32 orderHash = _hashSignedOrder(BUY_TYPEHASH, tokenMasterToken, signedOrder);

            if (!_validateOrderSignature(orderSigners, orderHash, signedOrder.signature)) {
                revert TokenMasterRouter__OrderSignerUnauthorized();
            }
            if (signedOrder.cosignature.signer != address(0)) {
                if (!_validateCosignature(executor, signedOrder.signature, signedOrder.cosignature)) {
                    revert TokenMasterRouter__CosignatureInvalid();
                }
            }

            uint256 minimumToBuy = signedOrder.baseValue;
            if (signedOrder.tokenMasterOracle != address(0)) {
                minimumToBuy = ITokenMasterOracle(signedOrder.tokenMasterOracle).adjustValue(
                    ORACLE_BUY_TRANSACTION_TYPE,
                    executor,
                    tokenMasterToken,
                    signedOrder.baseToken,
                    signedOrder.baseValue,
                    signedOrder.oracleExtraData
                );
            }

            if (tokensToBuy < minimumToBuy) {
                revert TokenMasterRouter__OrderDoesNotMeetMinimum();
            }

            OrderTracking storage orderData = orderTracking[orderHash];
            if (orderData.orderDisabled) {
                revert TokenMasterRouter__OrderDisabled();
            }
            if (signedOrder.maxTotal > 0) {
                uint256 newTotal = orderData.orderTotal + tokensToBuy;
                if (newTotal > signedOrder.maxTotal) {
                    revert TokenMasterRouter__OrderMaxTotalExceeded();
                }
                orderData.orderTotal = newTotal;
            }
            if (signedOrder.maxPerWallet > 0) {
                uint256 newTotal = orderData.orderTotalPerWallet[executor] + tokensToBuy;
                if (newTotal > signedOrder.maxPerWallet) {
                    revert TokenMasterRouter__OrderMaxPerWalletExceeded();
                }
                orderData.orderTotalPerWallet[executor] = newTotal;
            }
        }
    }

    /**
     * @dev  Validation function for an advanced sell order.
     * 
     * @dev  Throws when the order has expired.
     * @dev  Throws when the order is not signed by an authorized signer.
     * @dev  Throws when a cosigner is specified and the cosignature is invalid.
     * @dev  Throws when the sell amount does not meet the order minimum.
     * @dev  Throws when the order has been disabled.
     * @dev  Throws when the order has a maximum total and the sell will exceed it.
     * @dev  Throws when the order has a maximum per wallet and the sell will exceed it.
     * 
     * @param  tokenMasterToken  The token to buy tokens of.
     * @param  orderSigners      Storage pointer for allowed signer addresses.
     * @param  executor          Address of the advanced order seller.
     * @param  tokensToSell      Amount of tokens being sold.
     * @param  signedOrder       Advanced order details and signatures.
     */
    function _validateSellParameters(
        address tokenMasterToken,
        EnumerableSet.AddressSet storage orderSigners,
        address executor,
        uint256 tokensToSell,
        SignedOrder calldata signedOrder
    ) internal {
        if (signedOrder.expiration < block.timestamp) {
            revert TokenMasterRouter__OrderExpired();
        }
        bytes32 orderHash = _hashSignedOrder(SELL_TYPEHASH, tokenMasterToken, signedOrder);

        if (!_validateOrderSignature(orderSigners, orderHash, signedOrder.signature)) {
            revert TokenMasterRouter__OrderSignerUnauthorized();
        }
        if (signedOrder.cosignature.signer != address(0)) {
            if (!_validateCosignature(executor, signedOrder.signature, signedOrder.cosignature)) {
                revert TokenMasterRouter__CosignatureInvalid();
            }
        }

        uint256 minimumToSell = signedOrder.baseValue;
        if (signedOrder.tokenMasterOracle != address(0)) {
            minimumToSell = ITokenMasterOracle(signedOrder.tokenMasterOracle).adjustValue(
                ORACLE_SELL_TRANSACTION_TYPE,
                executor,
                tokenMasterToken,
                signedOrder.baseToken,
                signedOrder.baseValue,
                signedOrder.oracleExtraData
            );
        }

        if (tokensToSell < minimumToSell) {
            revert TokenMasterRouter__OrderDoesNotMeetMinimum();
        }

        OrderTracking storage orderData = orderTracking[orderHash];
        if (orderData.orderDisabled) {
            revert TokenMasterRouter__OrderDisabled();
        }
        if (signedOrder.maxTotal > 0) {
            uint256 newTotal = orderData.orderTotal + tokensToSell;
            if (newTotal > signedOrder.maxTotal) {
                revert TokenMasterRouter__OrderMaxTotalExceeded();
            }
            orderData.orderTotal = newTotal;
        }
        if (signedOrder.maxPerWallet > 0) {
            uint256 newTotal = orderData.orderTotalPerWallet[executor] + tokensToSell;
            if (newTotal > signedOrder.maxPerWallet) {
                revert TokenMasterRouter__OrderMaxPerWalletExceeded();
            }
            orderData.orderTotalPerWallet[executor] = newTotal;
        }
    }

    /**
     * @dev  Executes a sell for tokens from a TokenMaster token.
     * 
     * @param  tokenMasterToken  The token to buy tokens of.
     * @param  executor          Address of the seller.
     * @param  sellOrder         Basic sell order details.
     */
    function _executeSell(
        ITokenMasterERC20C tokenMasterToken,
        address executor,
        SellOrder calldata sellOrder
    ) internal {
        (
            address pairedToken,
            uint256 totalReceived,
            uint256 transferByRouterAmount
        ) = tokenMasterToken.sellTokens(executor, sellOrder.tokensToSell, sellOrder.minimumOut);

        emit SellOrderFilled(address(tokenMasterToken), executor, sellOrder.tokensToSell, totalReceived);

        if (transferByRouterAmount > 0) {
            _transferPoolPairedToken(
                tokenMasterToken,
                pairedToken,
                executor,
                transferByRouterAmount
            );
        }
    }

    /**
     * @dev  Validation function for an advanced sell order.
     * 
     * @dev  Throws when the order has expired.
     * @dev  Throws when the order is not signed by an authorized signer.
     * @dev  Throws when a cosigner is specified and the cosignature is invalid.
     * @dev  Throws when the amount to spend exceeds the user specified maximum.
     * @dev  Throws when the order has been disabled.
     * @dev  Throws when the order has a maximum total and the sell will exceed it.
     * @dev  Throws when the order has a maximum per wallet and the sell will exceed it.
     * 
     * @param  orderSigners  Storage pointer for allowed signer addresses.
     * @param  executor      Address of the spender.
     * @param  spendOrder    Basic spend details.
     * @param  signedOrder   Advanced spend details and signature.
     * 
     * @return  adjustedAmountToSpend  Amount to spend, adjusted by oracle if necessary.
     * @return  multiplier             Multiplier of spend order being executed.
     */
    function _validateSpendParameters(
        EnumerableSet.AddressSet storage orderSigners,
        address executor,
        SpendOrder calldata spendOrder,
        SignedOrder calldata signedOrder
    ) internal returns (uint256 adjustedAmountToSpend, uint256 multiplier) {
        if (signedOrder.expiration < block.timestamp) {
            revert TokenMasterRouter__OrderExpired();
        }
        bytes32 spendOrderHash = _hashSignedOrder(SPEND_TYPEHASH, spendOrder.tokenMasterToken, signedOrder);

        if (!_validateOrderSignature(orderSigners, spendOrderHash, signedOrder.signature)) {
            revert TokenMasterRouter__OrderSignerUnauthorized();
        }
        if (signedOrder.cosignature.signer != address(0)) {
            if (!_validateCosignature(executor, signedOrder.signature, signedOrder.cosignature)) {
                revert TokenMasterRouter__CosignatureInvalid();
            }
        }

        multiplier = spendOrder.multiplier;
        adjustedAmountToSpend = signedOrder.baseValue * multiplier;
        if (signedOrder.tokenMasterOracle != address(0)) {
            adjustedAmountToSpend = ITokenMasterOracle(signedOrder.tokenMasterOracle).adjustValue(
                ORACLE_SPEND_TRANSACTION_TYPE,
                executor,
                spendOrder.tokenMasterToken,
                signedOrder.baseToken,
                adjustedAmountToSpend,
                signedOrder.oracleExtraData
            );
        }

        OrderTracking storage orderData = orderTracking[spendOrderHash];
        if (orderData.orderDisabled) {
            revert TokenMasterRouter__OrderDisabled();
        }
        if (signedOrder.maxTotal > 0) {
            uint256 newTotal = orderData.orderTotal + multiplier;
            if (newTotal > signedOrder.maxTotal) {
                revert TokenMasterRouter__OrderMaxTotalExceeded();
            }
            orderData.orderTotal = newTotal;
        }
        if (signedOrder.maxPerWallet > 0) {
            uint256 newTotal = orderData.orderTotalPerWallet[executor] + multiplier;
            if (newTotal > signedOrder.maxPerWallet) {
                revert TokenMasterRouter__OrderMaxPerWalletExceeded();
            }
            orderData.orderTotalPerWallet[executor] = newTotal;
        }
    }

    /**
     * @dev  Hashes an advanced order for EIP-712 signature validation.
     * 
     * @param  typehash          The EIP712 struct typehash for the order type.
     * @param  tokenMasterToken  Address of the TokenMaster token the advanced order is for.
     * @param  signedOrder       Advanced order details.
     * 
     * @return  orderHash  The struct hash for EIP-712 signature validation.
     */
    function _hashSignedOrder(
        bytes32 typehash,
        address tokenMasterToken,
        SignedOrder calldata signedOrder
    ) internal pure returns (bytes32 orderHash) {
        orderHash = EfficientHash.efficientHashElevenStep2(
            EfficientHash.efficientHashElevenStep1(
                typehash,
                signedOrder.creatorIdentifier,
                bytes32(uint256(uint160(tokenMasterToken))),
                bytes32(uint256(uint160(signedOrder.tokenMasterOracle))),
                bytes32(uint256(uint160(signedOrder.baseToken))),
                bytes32(signedOrder.baseValue),
                bytes32(signedOrder.maxPerWallet),
                bytes32(signedOrder.maxTotal)
            ),
            bytes32(signedOrder.expiration),
            bytes32(uint256(uint160(signedOrder.hook))),
            bytes32(uint256(uint160(signedOrder.cosignature.signer)))
        );
    }

    /**
     * @dev  Hashes the advanced permit transfer data for a PermitC transfer of paired tokens.
     * 
     * @param  buyOrder     Basic buy details.
     * @param  signedOrder  Advanced order details.
     * 
     * @return  hash  The struct hash validation in PermitC.
     */
    function _hashBuyOrderPermitAdvancedData(
        BuyOrder calldata buyOrder,
        SignedOrder calldata signedOrder
    ) internal pure returns(bytes32 hash) {
        hash = EfficientHash.efficientHashNineStep2(
            EfficientHash.efficientHashNineStep1(
                PERMITTED_TRANSFER_BUY_TYPEHASH,
                bytes32(uint256(uint160(buyOrder.tokenMasterToken))),
                bytes32(buyOrder.tokensToBuy),
                bytes32(buyOrder.pairedValueIn),
                signedOrder.creatorIdentifier,
                bytes32(uint256(uint160(signedOrder.hook))),
                bytes32(signedOrder.signature.v),
                signedOrder.signature.r
            ),
            signedOrder.signature.s
        );
    }

    /**
     * @dev  Validates that an order signature is from an allowed order signer for the TokenMaster token.
     * 
     * @dev  Throws when the signature's supplied `v` value is greater than 255.
     * 
     * @param  orderSigners      Storage pointer for allowed signer addresses.
     * @param  orderHash         The order struct hash for EIP-712 signature validation.
     * @param  signature         Signature r, s, and v values for signer address recovery.
     * 
     * @return  isValid  True if the recovered signing address is a valid signer.
     */
    function _validateOrderSignature(
        EnumerableSet.AddressSet storage orderSigners,
        bytes32 orderHash,
        SignatureECDSA calldata signature
    ) internal view returns (bool isValid) {
        if (signature.v > type(uint8).max) {
            revert Error__InvalidSignatureV();
        }
        
        address signer = ecrecover(_hashTypedDataV4(orderHash), uint8(signature.v), signature.r, signature.s);

        isValid = orderSigners.contains(signer);
    }

    /**
     * @dev  Validates that an authority signature if signing authority is enabled for token deployments.
     * 
     * @dev  Throws when the signature's supplied `v` value is greater than 255.
     * 
     * @param  digest     EIP-712 digest for signer address recovery.
     * @param  signature  Signature r, s, and v values for signer address recovery.
     * @param  authority  The signing authority set in the role server.
     * 
     * @return  isValid  True if the recovered signing address is the signing authority.
     */
    function _validateAuthoritySignature(
        bytes32 digest,
        SignatureECDSA calldata signature,
        address authority
    ) internal pure returns (bool isValid) {
        if (signature.v > type(uint8).max) {
            revert Error__InvalidSignatureV();
        }

        isValid = authority == ecrecover(digest, uint8(signature.v), signature.r, signature.s);
    }

    /**
     * @dev  Validates that a cosignature is valid for an advanced order.
     * 
     * @dev  Throws when the cosignature has expired.
     * @dev  Throws when the signature's supplied `v` value is greater than 255.
     * 
     * @param  executor     Address of the transaction executor.
     * @param  signature    Signature r, s, and v values for the advanced order.
     * @param  cosignature  Cosignature to validate.
     * 
     * @return  isValid  True if the cosignature is valid.
     */
    function _validateCosignature(
        address executor,
        SignatureECDSA calldata signature,
        Cosignature calldata cosignature
    ) internal view returns (bool isValid) {
        if (cosignature.expiration < block.timestamp) {
            revert TokenMasterRouter__CosignatureExpired();
        }
        if (cosignature.v > type(uint8).max) {
            revert Error__InvalidSignatureV();
        }

        bytes32 cosignatureHash = _hashTypedDataV4(
            EfficientHash.efficientHash(
                COSIGNATURE_TYPEHASH,
                bytes32(signature.v),
                signature.r,
                signature.s,
                bytes32(cosignature.expiration),
                bytes32(uint256(uint160(executor)))
            )
        );

        isValid = ecrecover(cosignatureHash, uint8(cosignature.v), cosignature.r, cosignature.s) == cosignature.signer;
    }

    /**
     * @dev  Transfers an amount of paired token from a TokenMaster token to a recipient.
     * @dev  This function will attempt to reset token approvals to handle unusual approval 
     * @dev  formats in paired tokens.
     * 
     * @dev  Throws when the transfer fails.
     * 
     * @param  tokenMasterToken  Address of the TokenMaster token to transfer paired tokens from.
     * @param  pairedToken       Address of the paired token to transfer from the pool.
     * @param  to                Address to send the paired tokens to.
     * @param  amount            Amount of tokens to transfer from the pool.
     */
    function _transferPoolPairedToken(
        ITokenMasterERC20C tokenMasterToken,
        address pairedToken,
        address to,
        uint256 amount
    ) internal {
        bool isError = SafeERC20.safeTransferFrom(pairedToken, address(tokenMasterToken), to, amount);
        if (isError) {
            // Potential approval issue with non-standard ERC20 paired token
            // attempt to reset approvals and transfer again.
            tokenMasterToken.resetPairedTokenApproval();
            isError = SafeERC20.safeTransferFrom(pairedToken, address(tokenMasterToken), to, amount);
            if (isError) {
                revert TokenMasterRouter__FailedToTransferPairedToken();
            }
        }
    }

    /**
     * @dev  Returns the executor for a transaction with trusted forwarder context if appended data length is 20 bytes.
     *
     * @dev  Throws when appended data length is not zero or 20 bytes.
     * 
     * @param expectedDataLength  The length of calldata expected for the transaction.
     * 
     * @return executor  The address of the executor for the transaction.
     */
    function _getExecutor(
        uint256 expectedDataLength
    ) internal view returns(address executor) {
        unchecked {
            uint256 appendedDataLength = msg.data.length - expectedDataLength;
            executor = msg.sender;
            if (appendedDataLength > 0) {
                if (appendedDataLength != 20) revert TokenMasterRouter__BadCalldataLength();
                executor = _msgSender();
            }
        }
    }

    /**
     * @dev  Convenience function to adjust a calldata parameter's expected length rounding up to 
     * @dev  the nearest 32 byte amount.
     * 
     * @dev  Throws when the supplied bytes length is greater than type(uint32).max.
     * 
     * @param  currentDataLength  Current length of expected calldata.
     * @param  bytesLength        Length of the bytes field.
     * 
     * @return  totalLength  Length of expected calldata with the bytes length rounded up.
     */
    function _addAdjustedBytesLength(uint256 currentDataLength, uint256 bytesLength) internal pure returns (uint256 totalLength) {
        if (bytesLength > type(uint32).max) {
            revert TokenMasterRouter__BadCalldataLength();
        }
        unchecked {
            totalLength = currentDataLength + ((bytesLength + 31) & ~uint256(31));
        }
    }

    /**
     * @dev  Hashes the deployment parameters and validates the signature against the signing authority.
     * 
     * @dev  Throws when the signature is not from the signing authority.
     * 
     * @param  deploymentParameters  The parameters for the token being deployed.
     * @param  signature             The signature from the signing authority.
     * @param  deploymentAuthority   The address set as the signing authority for deployments in the role server.
     */
    function _validateDeploymentSignature(
        DeploymentParameters calldata deploymentParameters,
        SignatureECDSA calldata signature,
        address deploymentAuthority
    ) internal view {
        bytes32 digest = _hashTypedDataV4(
            _hashDeploymentParameters(deploymentParameters)
        );

        if (!_validateAuthoritySignature(digest, signature, deploymentAuthority)) {
            revert TokenMasterRouter__InvalidDeploymentSignature();
        }
    }

    /**
     * @dev  Hashes the deployment parameters for a new TokenMaster token deployment for EIP-712 signature validation.
     * 
     * @param  deploymentParameters  The parameters for the token being deployed.
     * 
     * @return  hash  The struct hash of the deployment parameters.
     */
    function _hashDeploymentParameters(DeploymentParameters calldata deploymentParameters) internal pure returns (bytes32 hash) {
        hash = EfficientHash.efficientHash(
            DEPLOYMENT_TYPEHASH,
            bytes32(uint256(uint160(deploymentParameters.tokenFactory))),
            deploymentParameters.tokenSalt,
            bytes32(uint256(uint160(deploymentParameters.tokenAddress))),
            bytes32(uint256(deploymentParameters.blockTransactionsFromUntrustedChannels ? 1 : 0)),
            bytes32(uint256(deploymentParameters.restrictPairingToLists ? 1 : 0))
        );
    }

    /**
     * @dev  Returns true if the `flagValue` has the `flag` set, false otherwise.
     *
     * @dev  This function uses the bitwise AND operator to check if the `flag` is set in `flagValue`.
     *
     * @param flagValue  The value to check for the presence of the `flag`.
     * @param flag       The flag to check for in the `flagValue`.
     */
    function _isFlagSet(uint8 flagValue, uint8 flag) internal pure returns (bool flagSet) {
        flagSet = (flagValue & flag) != 0;
    }

    /**
     * @dev  Sets the `flag` in `flagValue` to `flagSet` and returns the updated value.
     * 
     * @dev  This function uses the bitwise OR and AND operators to set or unset the `flag` in `flagValue`.
     *
     * @param flagValue The value to set the `flag` in.
     * @param flag      The flag to set in the `flagValue`.
     * @param flagSet   True to set the `flag`, false to unset the `flag`.
     */
    function _setFlag(uint8 flagValue, uint8 flag, bool flagSet) internal pure returns (uint8) {
        if (flagSet) {
            return (flagValue | flag);
        } else {
            unchecked {
                return (flagValue & (255 - flag));
            }
        }
    }
}