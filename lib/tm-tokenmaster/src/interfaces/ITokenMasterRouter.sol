//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "../DataTypes.sol";
import "./ITokenMasterERC20C.sol";

/**
 * @title  ITokenMasterRouter
 * @author Limit Break, Inc.
 * @notice Interface definition for the TokenMasterRouter contract.
 */
interface ITokenMasterRouter {
    /// @dev Emitted when the TokenMaster admin updates the infrastructure fee for new token deployments.
    event InfrastructureFeeUpdated(uint16 infrastructureFeeBPS);

    /// @dev Emitted when the TokenMaster admin updates an allowed token factory.
    event AllowedTokenFactoryUpdated(address indexed tokenFactory, bool allowed);

    /// @dev Emitted when a token has been deployed.
    event TokenMasterTokenDeployed(address indexed tokenMasterToken, address indexed pairedToken, address indexed tokenFactory);

    /// @dev Emitted when a token's settings have been updated.
    event TokenSettingsUpdated(
        address indexed tokenMasterToken,
        bool blockTransactionsFromUntrustedChannels,
        bool restrictPairingToLists
    );

    /// @dev Emitted when a trusted channel has been added or removed.
    event TrustedChannelUpdated(
        address indexed tokenAddress,
        address indexed channel,
        bool allowed
    );

    /// @dev Emitted when a token's partner has proposed a new fee recipient address.
    event PartnerFeeRecipientProposed(
        address indexed tokenAddress,
        address proposedPartnerFeeRecipient
    );

    /// @dev Emitted when the creator has accepted the token partner's proposed fee recipient address.
    event PartnerFeeRecipientUpdated(
        address indexed tokenAddress,
        address partnerFeeRecipient
    );

    /// @dev Emitted when a deployer has been added or removed as an allowed deployer for tokens pairing to a creator's token.
    event AllowedPairToDeployersUpdated(
        address indexed tokenAddress,
        address indexed deployer,
        bool allowed
    );

    /// @dev Emitted when a specific token has been added or removed as an allowed token for pairing to a creator's token.
    event AllowedPairToTokensUpdated(
        address indexed tokenAddress,
        address indexed tokenAllowedToPair,
        bool allowed
    );

    /// @dev Emitted when a buy tokens order has been filled.
    event BuyOrderFilled(
        address indexed tokenMasterToken,
        address indexed buyer,
        uint256 amountPurchased,
        uint256 totalCost
    );

    /// @dev Emitted when a sell tokens order has been filled.
    event SellOrderFilled(
        address indexed tokenMasterToken,
        address indexed seller,
        uint256 amountSold,
        uint256 totalReceived
    );

    /// @dev Emitted when a spend tokens order has been filled.
    event SpendOrderFilled(
        address indexed tokenMasterToken,
        bytes32 indexed creatorSpendIdentifier,
        address indexed spender,
        uint256 amountSpent,
        uint256 multiplier
    );

    /// @dev Emitted when a order signer has been updated.
    event OrderSignerUpdated(
        address indexed tokenMasterToken,
        address indexed signer,
        bool allowed
    );

    /// @dev Emitted when an advanced buy order has been disabled or enabled.
    event BuyOrderDisabled(
        address indexed tokenMasterToken,
        bytes32 indexed creatorBuyIdentifier,
        bool disabled
    );

    /// @dev Emitted when an advanced sell order has been disabled or enabled.
    event SellOrderDisabled(
        address indexed tokenMasterToken,
        bytes32 indexed creatorSellIdentifier,
        bool disabled
    );

    /// @dev Emitted when an spend order has been disabled or enabled.
    event SpendOrderDisabled(
        address indexed tokenMasterToken,
        bytes32 indexed creatorSpendIdentifier,
        bool disabled
    );

    function buyTokens(BuyOrder calldata buyOrder) external payable;
    function buyTokensAdvanced(
        BuyOrder calldata buyOrder,
        SignedOrder calldata signedOrder,
        PermitTransfer calldata permitTransfer
    ) external payable;
    function sellTokens(SellOrder calldata sellOrder) external;
    function sellTokensAdvanced(SellOrder calldata sellOrder, SignedOrder calldata signedOrder) external;
    function spendTokens(
        SpendOrder calldata spendOrder,
        SignedOrder calldata signedOrder
    ) external;
    function deployToken(
        DeploymentParameters calldata deploymentParameters,
        SignatureECDSA calldata signature
    ) external payable;
    function updateTokenSettings(
        address tokenAddress,
        bool blockTransactionsFromUntrustedChannels,
        bool restrictPairingToLists
    ) external;
    function setOrderSigner(address tokenMasterToken, address signer, bool allowed) external;
    function setTokenAllowedPairToDeployer(address tokenAddress, address deployer, bool allowed) external;
    function setTokenAllowedPairToToken(address tokenAddress, address tokenAllowedToPair, bool allowed) external;
    function disableBuyOrder(address tokenMasterToken, SignedOrder calldata signedOrder, bool disabled) external;
    function disableSellOrder(address tokenMasterToken, SignedOrder calldata signedOrder, bool disabled) external;
    function disableSpendOrder(address tokenMasterToken, SignedOrder calldata signedOrder, bool disabled) external;
    function withdrawCreatorShare(ITokenMasterERC20C tokenMasterToken, address withdrawTo, uint256 withdrawAmount) external;
    function transferCreatorShareToMarket(ITokenMasterERC20C tokenMasterToken, uint256 transferAmount) external;
    function acceptProposedPartnerFeeReceiver(address tokenMasterToken, address expectedPartnerFeeRecipient) external;
    function partnerProposeFeeReceiver(address tokenMasterToken, address proposedPartnerFeeRecipient) external;
    function setAllowedTokenFactory(address tokenFactory, bool allowed) external;
    function setInfrastructureFee(uint16 _infrastructureFeeBPS) external;
    function withdrawFees(ITokenMasterERC20C[] calldata tokenMasterTokens) external;
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
    );
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
    );
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
    );
    function getTokenSettings(
        address tokenAddress
    ) external view returns (
        bool deployedByTokenMaster,
        bool blockTransactionsFromUntrustedChannels,
        bool restrictPairingToLists,
        address partnerFeeRecipient
    );
    function getOrderSigners(address tokenMasterToken) external view returns (address[] memory orderSigners);
    function getTrustedChannels(address tokenMasterToken) external view returns (address[] memory trustedChannels);
    function getAllowedPairToDeployers(address tokenMasterToken) external view returns (address[] memory allowedPairToDeployers);
    function getAllowedPairToTokens(address tokenMasterToken) external view returns (address[] memory allowedPairToTokens);
}