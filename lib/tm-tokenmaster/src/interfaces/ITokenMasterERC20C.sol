//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @title  ITokenMasterERC20C
 * @author Limit Break, Inc.
 * @notice Interface that must be implemented by token contracts that will be
 * @notice deployed through TokenMasterRouter.
 */
interface ITokenMasterERC20C {

    /// @dev Emitted when a creator withdraws their share or when fees are withdrawn.
    event CreatorShareWithdrawn(address to, uint256 withdrawAmount, uint256 infrastructureAmount, uint256 partnerAmount);

    /// @dev Emitted when a creator transfers a portion of their share to the market bonded value. Infrastructure and partner amounts are transferred to their respective receivers.
    event CreatorShareTransferredToMarket(address to, uint256 transferAmount, uint256 infrastructureAmount, uint256 partnerAmount);
    
    function PAIRED_TOKEN() external view returns(address);
    function buyTokens(
        address buyer,
        uint256 pairedTokenIn,
        uint256 pooledTokenToBuy
    ) external payable returns(uint256 totalCost, uint256 refundByRouterAmount);
    function sellTokens(
        address seller,
        uint256 pooledTokenToSell,
        uint256 pairedTokenMinimumOut
    ) external returns (address pairedToken, uint256 pairedValueToSeller, uint256 transferByRouterAmount);
    function spendTokens(address spender, uint256 pooledTokenToSpend) external;
    function withdrawCreatorShare(
        address withdrawTo,
        uint256 withdrawAmount,
        address infrastructureFeeRecipient,
        address partnerFeeRecipient
    ) external returns (
        address pairedToken,
        uint256 transferByRouterAmountCreator,
        uint256 transferByRouterAmountInfrastructure,
        uint256 transferByRouterAmountPartner
    );
    function transferCreatorShareToMarket(
        uint256 transferAmount,
        address infrastructureFeeRecipient,
        address partnerFeeRecipient
    ) external returns(address pairedToken, uint256 transferByRouterAmountInfrastructure, uint256 transferByRouterAmountPartner);
    function withdrawFees(
        address infrastructureFeeRecipient,
        address partnerFeeRecipient
    ) external returns (
        address pairedToken,
        uint256 transferByRouterAmountInfrastructure,
        uint256 transferByRouterAmountPartner
    );
    function withdrawUnrelatedToken(address tokenAddress, address withdrawTo, uint256 withdrawAmount) external;
    function resetPairedTokenApproval() external;
    function pairedTokenShares() external view returns(uint256 marketShare, uint256 creatorShare, uint256 infrastructureShare, uint256 partnerShare);
}