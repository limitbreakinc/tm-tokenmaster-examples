//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "../Constants.sol";
import "../DataTypes.sol";
import "../Errors.sol";

import "../interfaces/ITokenMasterERC20C.sol";

import "@limitbreak/tm-core-lib/src/token/erc20/ERC20C.sol";
import "@limitbreak/tm-core-lib/src/token/erc20/utils/SafeERC20.sol";
import "@limitbreak/tm-core-lib/src/utils/access/Ownable2Step.sol";
import "@limitbreak/tm-core-lib/src/utils/access/OwnableAccessControl.sol";

/**
 * @title  BondedPool
 * @author Limit Break, Inc.
 * @notice The BondedPool contract implements common code for all tokens deployed by TokenMaster.
 * 
 * @dev    Specific pool implementations must implement additional functionality to comply with 
 * @dev    ITokenMasterERC20C and may extend or override BondedPool logic.
 */
abstract contract BondedPool is Ownable2Step, OwnableAccessControl, ERC20C, ITokenMasterERC20C {

    /// @dev The number of decimals for the ERC20 token.
    uint8 internal immutable DECIMALS;
    /// @dev Address of the token paired with the pool.
    address public immutable PAIRED_TOKEN;
    /// @dev Address of the TokenMasterRouter.
    address internal immutable ROUTER;
    /// @dev Infrastructure fee rate in BPS.
    uint16 internal immutable INFRASTRUCTURE_FEE_BPS;
    /// @dev Partner fee rate in BPS.
    uint16 internal immutable PARTNER_FEE_BPS;

    /// @dev Amount of creator share that has already paid infra/partner fees.
    uint256 internal creatorShareFeesPaidAdjustment;

    /// @dev Internal function pointer to the shares function, set during contract construction to either ERC20 or native token version.
    function() internal view returns(uint256,uint256,uint256) internal immutable _creatorPairedTokenShare;
    /// @dev Internal function pointer to the paired token transfer function, set during contract construction for ERC20 or native transfers.
    function(address,uint256) internal returns(uint256) internal immutable _transferPairedToken;

    constructor(
        PoolDeploymentParameters memory deploymentParams,
        uint256 infrastructureFeeBPS,
        address router
    )
    ERC20C(deploymentParams.name, deploymentParams.symbol)
    Ownable(deploymentParams.initialOwner)
    CreatorTokenBase(deploymentParams.defaultTransferValidator) {

        if (
            infrastructureFeeBPS > BPS || 
            (
                deploymentParams.partnerFeeBPS > 0 && 
                (deploymentParams.partnerFeeRecipient == address(0) || deploymentParams.partnerFeeBPS > BPS)
            )
        ) {
            revert TokenMasterERC20__InvalidParameters();
        }

        DECIMALS = deploymentParams.tokenDecimals;
        PAIRED_TOKEN = deploymentParams.pairedToken;
        ROUTER = router;
        INFRASTRUCTURE_FEE_BPS = uint16(infrastructureFeeBPS);
        PARTNER_FEE_BPS = uint16(deploymentParams.partnerFeeBPS);

        if (deploymentParams.pairedToken == address(0)) {
            if (deploymentParams.useRouterForPairedTransfers) {
                revert TokenMasterERC20__InvalidParameters();
            }
            _creatorPairedTokenShare = _creatorPairedTokenShareNative;
            _transferPairedToken = _transferPairedTokenNative;
        } else {
            _creatorPairedTokenShare = _creatorPairedTokenShareERC20;
            if (deploymentParams.useRouterForPairedTransfers) {
                _transferPairedToken = _transferPairedTokenERC20RouterTransfer;
                SafeERC20.safeApprove(PAIRED_TOKEN, ROUTER, type(uint256).max);
            } else {
                _transferPairedToken = _transferPairedTokenERC20PoolTransfer;
            }
        }
    }

    /*************************************************************************/
    /*                           CREATOR FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Withdraws an amount of creator share to an address specified by the creator.
     * 
     * @dev     The entire infrastructure and partner shares will be withdrawn when this function is called.
     * @dev     When the paired token is ERC20 and tokens fail to transfer by the contract, the transfer
     * @dev     will fall back to attempting to transfer by the router contract.
     * 
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * @dev     Throws when the amount to withdraw exceeds the creator share.
     * @dev     Throws when the paired token is native and a share transfer fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Withdraw amount has been transferred to the withdraw to address.
     * @dev    2. Partner fees have been transferred to the partner fee receiver.
     * @dev    3. Infrastructure fees have been transferred to the infrastructure fee receiver.
     * @dev    4. A `CreatorShareWithdrawn` event has been emitted.
     * 
     * @param withdrawTo                  Address to withdraw creator share to.
     * @param withdrawAmount              Amount to withdraw from creator share.
     * @param infrastructureFeeRecipient  Address of the infra fee receipient.
     * @param partnerFeeRecipient         Address of the partner fee recipient.
     * 
     * @return pairedToken                           Address of the paired token for router transfers.
     * @return transferByRouterAmountCreator         Amount of paired token to transfer to creator by router.
     * @return transferByRouterAmountInfrastructure  Amount of paired token to transfer to infra by router.
     * @return transferByRouterAmountPartner         Amount of paired token to transfer to partner by router.
     */
    function withdrawCreatorShare(
        address withdrawTo,
        uint256 withdrawAmount,
        address infrastructureFeeRecipient,
        address partnerFeeRecipient
    ) external  virtual  returns (
        address pairedToken,
        uint256 transferByRouterAmountCreator,
        uint256 transferByRouterAmountInfrastructure,
        uint256 transferByRouterAmountPartner
    ) {
        _callerIsRouter();

        (
            uint256 _creatorShare,
            uint256 _infrastructureShare,
            uint256 _partnerShare
        ) = _creatorPairedTokenShare();

        if (withdrawAmount > _creatorShare) {
            revert TokenMasterERC20__WithdrawOrTransferAmountGreaterThanShare();
        } else if (withdrawAmount < _creatorShare) {
            unchecked {
                // Entire infrastructure/partner fee is withdrawn even when creator withdraws a partial amount
                // set creator share fee paid adjustment to the amount remaining to account for the
                // fees already being paid on that portion.
                creatorShareFeesPaidAdjustment = _creatorShare - withdrawAmount;
            }
        } else {
            // Creator is withdrawing their entire share, reset creator share fee paid adjustment to zero
            creatorShareFeesPaidAdjustment = 0;
        }
        
        pairedToken = PAIRED_TOKEN;
        transferByRouterAmountCreator = _transferPairedToken(withdrawTo, withdrawAmount);
        transferByRouterAmountInfrastructure = _transferPairedToken(infrastructureFeeRecipient, _infrastructureShare);
        transferByRouterAmountPartner = _transferPairedToken(partnerFeeRecipient, _partnerShare);

        emit CreatorShareWithdrawn(withdrawTo, withdrawAmount, _infrastructureShare, _partnerShare);
    }

    /**
     * @notice  Transfers an amount of creator share to the market. This function is disabled by 
     * @notice  default and must be overriden by a pool implementation to be utilized.
     * 
     * @dev     Throws when not implemented by a pool implementation.
     */
    function transferCreatorShareToMarket(
        uint256 /*transferAmount*/,
        address /*infrastructureFeeRecipient*/,
        address /*partnerFeeRecipient*/
    ) external virtual returns (
        address /*pairedToken*/,
        uint256 /*transferByRouterAmountInfrastructure*/,
        uint256 /*transferByRouterAmountPartner*/
    ) {
        revert TokenMasterERC20__OperationNotSupportedByPool();
    }

    /**
     * @notice  Withdraws partner and infrastructure fees for the pool.
     * 
     * @dev     When the paired token is ERC20 and tokens fail to transfer by the contract, the transfer
     * @dev     will fall back to attempting to transfer by the router contract.
     * 
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * @dev     Throws when the paired token is native and a share transfer fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Partner fees have been transferred to the partner fee receiver.
     * @dev    2. Infrastructure fees have been transferred to the infrastructure fee receiver.
     * @dev    3. A `CreatorShareWithdrawn` event has been emitted.
     * 
     * @param infrastructureFeeRecipient  Address of the infra fee receipient.
     * @param partnerFeeRecipient         Address of the partner fee recipient.
     * 
     * @return pairedToken                           Address of the paired token for router transfers.
     * @return transferByRouterAmountInfrastructure  Amount of paired token to transfer to infra by router.
     * @return transferByRouterAmountPartner         Amount of paired token to transfer to partner by router.
     */
    function withdrawFees(
        address infrastructureFeeRecipient,
        address partnerFeeRecipient
    ) external virtual returns (
        address pairedToken,
        uint256 transferByRouterAmountInfrastructure,
        uint256 transferByRouterAmountPartner
    ) {
        _callerIsRouter();

        (
            uint256 _creatorShare,
            uint256 _infrastructureShare,
            uint256 _partnerShare
        ) = _creatorPairedTokenShare();

        // Entire infrastructure/partner fee is withdrawn set creator share fee paid
        // adjustment to the total creator share to account for fees being paid
        creatorShareFeesPaidAdjustment = _creatorShare;

        pairedToken = PAIRED_TOKEN;
        transferByRouterAmountInfrastructure = _transferPairedToken(infrastructureFeeRecipient, _infrastructureShare);
        transferByRouterAmountPartner = _transferPairedToken(partnerFeeRecipient, _partnerShare);
        emit CreatorShareWithdrawn(address(this), 0, _infrastructureShare, _partnerShare);
    }

    /**
     * @notice  Withdraws an unrelated ERC20 or native token from the pool.
     * 
     * @dev     Throws when the caller is not the owner of the pool.
     * @dev     Throws when the token is the paired token.
     * @dev     Throws when the token fails to transfer.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The unrelated token has been transferred to the withdraw to address.
     * 
     * @param tokenAddress    Address of the token to withdraw from the pool
     * @param withdrawTo      Adress to withdraw the token to.
     * @param withdrawAmount  Amount of the token to withdraw.
     */
    function withdrawUnrelatedToken(
        address tokenAddress, 
        address withdrawTo, 
        uint256 withdrawAmount
    ) external virtual onlyOwner {
        if (tokenAddress == PAIRED_TOKEN) {
            revert TokenMasterERC20__CannotWithdrawPairedToken();
        }
        if (tokenAddress == address(0)) {
            (bool success, ) = withdrawTo.call{value: withdrawAmount}("");
            if (!success) {
                revert TokenMasterERC20__NativeTransferFailed();
            }
        } else {
            bool isError = SafeERC20.safeTransfer(tokenAddress, withdrawTo, withdrawAmount);
            if (isError) {
                revert TokenMasterERC20__ERC20TransferFailed();
            }
        }
    }

    /*************************************************************************/
    /*                            ROUTER FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Sets a max approval for the TokenMasterRouter to transfer the paired token from the pool.
     * 
     * @dev     Called by router when the current approval is insufficient for an attempted transfer.
     * @dev     This may be caused by a token that is initially set to handle transfers by the pool but has to
     * @dev     fall back to router transfers due to ERC20C whitelist transfer restrictions or when a paired token
     * @dev     does not treat `type(uint256).max` as an unlimited approval and the volume of transfers has diminished
     * @dev     the approved amount to the point where it needs to be updated.
     * 
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * @dev     Throws when the approval call fails to reset the approval.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The paired token approval for the router has been set to max approval.
     */
    function resetPairedTokenApproval() external {
        _callerIsRouter();
        bool isError = SafeERC20.safeApproveWithRetryAfterZero(PAIRED_TOKEN, ROUTER, type(uint256).max);
        if (isError) {
            revert TokenMasterERC20__FailedToSetApproval();
        }
    }

    /*************************************************************************/
    /*                             VIEW FUNCTIONS                            */
    /*************************************************************************/

    /**
     * @notice  Returns the current share splits for the paired token.
     * 
     * @return marketShare          Amount of paired token bonded to market value.
     * @return creatorShare         Amount of paired token allocated to the creator.
     * @return infrastructureShare  Amount of paired token allocated to infrastructure fees.
     * @return partnerShare         Amount of paired token allocated to partner fees.
     */
    function pairedTokenShares() external view returns(
        uint256 marketShare,
        uint256 creatorShare,
        uint256 infrastructureShare,
        uint256 partnerShare
    ) {
        marketShare = _bondedMarketValue();
        (creatorShare,infrastructureShare,partnerShare) = _creatorPairedTokenShare();
    }

    /*************************************************************************/
    /*                           INTERNAL FUNCTIONS                          */
    /*************************************************************************/

    /**
     * @dev  Returns the current bonded market value.
     * @dev  This function must be implemented by each pool type based on the conditions that determine
     * @dev  bonded value in the pool.
     */
    function _bondedMarketValue() internal virtual view returns(uint256);

    /**
     * @dev  Internal function assigned to `_creatorPairedTokenShare` function pointer when the paired
     * @dev  token is an ERC20 token.
     * 
     * @dev  Returns the token shares based on the balance of the ERC20 paired token minus
     * @dev  the bonded market value.
     * 
     * @return creatorShare         Amount of paired token allocated to the creator.
     * @return infrastructureShare  Amount of paired token allocated to infrastructure fees.
     * @return partnerShare         Amount of paired token allocated to partner fees.
     */
    function _creatorPairedTokenShareERC20() private view returns(
        uint256 creatorShare,
        uint256 infrastructureShare,
        uint256 partnerShare
    ) {
        (creatorShare, infrastructureShare, partnerShare) = _calculateShareSplit(
            IERC20(PAIRED_TOKEN).balanceOf(address(this)) - _bondedMarketValue()
        );
    }

    /**
     * @dev  Internal function assigned to `_creatorPairedTokenShare` function pointer when the paired
     * @dev  token is the native token.
     * 
     * @dev  Returns the token shares based on the pool's native token balance minus
     * @dev  the bonded market value.
     * 
     * @return creatorShare         Amount of paired token allocated to the creator.
     * @return infrastructureShare  Amount of paired token allocated to infrastructure fees.
     * @return partnerShare         Amount of paired token allocated to partner fees.
     */
    function _creatorPairedTokenShareNative() private view returns(
        uint256 creatorShare,
        uint256 infrastructureShare,
        uint256 partnerShare
    ) {
        (creatorShare, infrastructureShare, partnerShare) = _calculateShareSplit(
            address(this).balance - _bondedMarketValue()
        );
    }

    /**
     * @dev  Calculates the split of non-bonded value between the creator, infrastructure and partner.
     * @dev  Adjusts for the amount of creator share that has already paid infrastructure and partner
     * @dev  fees.
     * 
     * @param totalShare  Total amount of value to split between creator, infra, and partner.
     * 
     * @return creatorShare         Amount of paired token allocated to the creator.
     * @return infrastructureShare  Amount of paired token allocated to infrastructure fees.
     * @return partnerShare         Amount of paired token allocated to partner fees.
     */
    function _calculateShareSplit(uint256 totalShare) private view returns (
        uint256 creatorShare,
        uint256 infrastructureShare,
        uint256 partnerShare
    ) {
        unchecked {
            uint256 _creatorShareFeesPaidAdjustment = creatorShareFeesPaidAdjustment;
            totalShare -= creatorShareFeesPaidAdjustment;
            infrastructureShare = totalShare * INFRASTRUCTURE_FEE_BPS / BPS;
            totalShare -= infrastructureShare;
            partnerShare = totalShare * PARTNER_FEE_BPS / BPS;
            creatorShare = totalShare - partnerShare + _creatorShareFeesPaidAdjustment;
        }
    }

    /**
     * @dev  Internal function assigned to the `_transferPairedToken` function pointer when paired with
     * @dev  an ERC20 token and deployment parameters specify that tokens are to be transferred by the router.
     * 
     * @dev  This function simply returns the transfer amount parameter as the transfer by router amount 
     * @dev  to inform the router that it will be required to transfer the tokens.
     */
    function _transferPairedTokenERC20RouterTransfer(address, uint256 amount) private pure returns (uint256 transferByRouterAmount) {
        transferByRouterAmount = amount;
    }

    /**
     * @dev  Intern function assigned to the `_transferPairedToken` function pointer when paired with
     * @dev  an ERC20 token and deployment parameters specify that tokens are to be transferred by the pool.
     * 
     * @dev  This function will attempt to transfer tokens, if the transfer fails it will fall back to assigning 
     * @dev  the transfer amount to transfer by router amount to inform the router that it will be required to
     * @dev  transfer the tokens.
     * 
     * @param to      Address to transfer the paired tokens to.
     * @param amount  Amount of paired tokens to transfer.
     */
    function _transferPairedTokenERC20PoolTransfer(address to, uint256 amount) private returns (uint256 transferByRouterAmount) {
        if (amount == 0) return 0;

        bool isError = SafeERC20.safeTransfer(PAIRED_TOKEN, to, amount);
        if (isError) {
            // fallback to transfer by router
            transferByRouterAmount = amount;
        }
    }

    /**
     * @dev  Intern function assigned to the `_transferPairedToken` function pointer when paired with
     * @dev  the native token.
     * 
     * @dev  Throws when the native token transfer fails.
     * 
     * @param to      Address to transfer the paired tokens to.
     * @param amount  Amount of paired tokens to transfer.
     */
    function _transferPairedTokenNative(address to, uint256 amount) private returns (uint256 transferByRouterAmount) {
        if (amount == 0) return 0;

        (bool success, ) = to.call{value: amount}("");
        if (!success) {
            revert TokenMasterERC20__NativeTransferFailed();
        }
    }

    /**
     * @dev  Throws when the caller is not the TokenMasterRouter.
     */
    function _callerIsRouter() internal view {
        if (msg.sender != ROUTER) {
            revert TokenMasterERC20__CallerMustBeRouter();
        }
    }

    /*************************************************************************/
    /*                             TOKEN FUNCTIONS                           */
    /*************************************************************************/

    function decimals() public view override returns (uint8) {
        return DECIMALS;
    }

    /**
     * @notice Indicates whether the contract implements the specified interface.
     * @dev Overrides supportsInterface in ERC165.
     * @param interfaceId The interface id
     * @return true if the contract implements the specified interface, false otherwise
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return 
        interfaceId == type(ITokenMasterERC20C).interfaceId || 
        _supportsInterfaceExtended(interfaceId) ||
        super.supportsInterface(interfaceId);
    }

    /**
     * @dev  Implements ERC20C transfer validation logic for token mints.
     */
    function _validateMint(address /*caller*/, address to, uint256 tokenId, uint256 amount, uint256 value) internal override {
        _preValidateTransfer(ROUTER, address(0), to, tokenId, amount, value);
    }

    /**
     * @dev  Implements ERC20C transfer validation logic for token burns.
     */
    function _validateBurn(address /*caller*/, address from, uint256 tokenId, uint256 amount, uint256 value) internal override {
        _preValidateTransfer(ROUTER, from, address(0), tokenId, amount, value);
    }

    /**
     * @dev  Overrides the ownable renounce ownership function to avoid inadvertent ownership renouncing as TokenMaster
     * @dev  tokens should generally not be unowned in order to manage features like order signing in TokenMasterRouter.
     * @dev  Creators should weigh all implications of their token being unowned before implementing any sort of 
     * @dev  ownership receiver to transfer the ownership to that would be the equivalent of burning ownership.
     */
    function renounceOwnership() public pure override {
        revert TokenMasterERC20__RenounceNotAllowed();
    }

    /**
     * @dev  Internal override of `_requireCallerIsContractOwner` to check the caller is the owner for OwnablePermissions.
     */
    function _requireCallerIsContractOwner() internal view override {
        _checkOwner();
    }

    /**
     * @dev  Internal function that may be overriden to extend the ERC165 interface support check in
     * @dev  pool implementations that have additional interfaces that are supported.
     */
    function _supportsInterfaceExtended(bytes4 /*interfaceId*/) internal virtual view returns (bool) {
        return false;
    }
}