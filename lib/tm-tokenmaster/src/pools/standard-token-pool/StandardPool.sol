//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./IStandardPool.sol";
import "./DataTypes.sol";
import "../../Constants.sol";
import "../../DataTypes.sol";
import "../../Errors.sol";

import "../BondedPool.sol";

import "@limitbreak/tm-core-lib/src/token/erc20/ERC20C.sol";
import "@limitbreak/tm-core-lib/src/token/erc20/utils/SafeERC20.sol";
import "@limitbreak/tm-core-lib/src/utils/access/Ownable2Step.sol";
import "@limitbreak/tm-core-lib/src/utils/access/OwnableAccessControl.sol";
import "@limitbreak/tm-core-lib/src/utils/PausableFlags.sol";
import "@limitbreak/tm-core-lib/src/licenses/LicenseRef-PolyForm-Strict-1.0.0.sol";

/**
 * @title  StandardPool
 * @author Limit Break, Inc.
 * @notice The StandardPool contract is a TokenMaster pool token that is designed to
 *         give creators maximum flexibility on tokenomics through spreads, share of
 *         demand fees, share of spends, and fees.
 * 
 * @dev    <h4>Features</h4>
 *         - ERC20C token with full creator controls.
 *         - Deployed through TokenMasterRouter.
 *         - Market value of token floats based on the bonded market value and minted tokens.
 *             Value can increase through spreads, demand fee share, and spend share.
 *             Value can decrease through creator emissions.
 *         - Creator specified buy, sell, and spend parameters with guardrails.
 *         - Creator earnings when tokens are spent through TokenMaster.
 */
contract StandardPool is BondedPool, PausableFlags, IStandardPool {

    /// @dev Guardrail for the minimum value the buy spread can be set to.
    uint16 private immutable MINIMUM_BUY_SPREAD_BPS;
    /// @dev Guardrail for the maximum value the buy spread can be set to.
    uint16 private immutable MAXIMUM_BUY_SPREAD_BPS;
    /// @dev Guardrail for buy fee BPS.
    uint16 private immutable MAXIMUM_BUY_FEE_BPS;
    /// @dev Guardrail for buy demand fee BPS.
    uint16 private immutable MAXIMUM_BUY_DEMAND_FEE_BPS;
    /// @dev Guardrail for the minimum value the sell spread can be set to.
    uint16 private immutable MINIMUM_SELL_SPREAD_BPS;
    /// @dev Guardrail for the maximum value the sell spread can be set to.
    uint16 private immutable MAXIMUM_SELL_SPREAD_BPS;
    /// @dev Guardrail for the sell fee BPS.
    uint16 private immutable MAXIMUM_SELL_FEE_BPS;
    /// @dev Guardrail for the creator share of spends.
    uint16 private immutable MAXIMUM_SPEND_CREATOR_SHARE_BPS;
    /// @dev Numerator for the rate in tokens per second that a creator earns emissions.
    uint128 private immutable CREATOR_EMISSION_RATE_NUMERATOR;
    /// @dev Denominator for the rate in tokens per second that a creator earns emissions.
    uint128 private immutable CREATOR_EMISSION_RATE_DENOMINATOR;

    /// @dev Parameters that are applied to buys.
    StandardPoolBuyParameters private buyParameters;
    /// @dev Parameters that are applied to sells.
    StandardPoolSellParameters private sellParameters;
    /// @dev Parameters that are applied to spends.
    StandardPoolSpendParameters private spendParameters;
    /// @dev Timestamp of the last creator emissions claim.
    uint48 private creatorLastEmissionsClaimTimestamp;
    /// @dev Maximum amount of tokens that a creator can claim as emissions.
    /// @dev This amount may be lowered by the contract owner but cannot be increased.
    uint256 private creatorEmissionsHardCap;
    /// @dev Total amount of creator emissions that have been claimed.
    uint256 private creatorEmissionsClaimed;
    /// @dev Amount of paired token value that is allocated to market share.
    uint256 private marketPairedTokenShare;

    constructor(
        PoolDeploymentParameters memory deploymentParams,
        uint256 pairedValueIn,
        uint256 infrastructureFeeBPS,
        address router
    ) 
    BondedPool(deploymentParams, infrastructureFeeBPS, router) 
    PausableFlags() {
     
        StandardPoolInitializationParameters memory initializationParameters = 
            abi.decode(deploymentParams.encodedInitializationArgs, (StandardPoolInitializationParameters));
        if (
            initializationParameters.minBuySpreadBPS >= BPS || initializationParameters.minSellSpreadBPS >= BPS 
            || initializationParameters.maxBuySpreadBPS >= BPS || initializationParameters.maxSellSpreadBPS >= BPS 
            || initializationParameters.maxBuyFeeBPS > BPS || initializationParameters.maxSellFeeBPS > BPS 
            || initializationParameters.maxBuyDemandFeeBPS > BPS || initializationParameters.maxSpendCreatorShareBPS > BPS
            || initializationParameters.creatorEmissionsHardCap > type(uint120).max
            || (initializationParameters.creatorEmissionRateNumerator | initializationParameters.creatorEmissionRateDenominator) 
                > type(uint128).max
            ) {
            revert TokenMasterERC20__InvalidParameters();
        }
        if (initializationParameters.initialSupplyAmount == 0) {
            revert TokenMasterERC20__InitialSupplyCannotBeZero();
        }
        if (pairedValueIn == 0) {
            revert TokenMasterERC20__InitialPairedDepositCannotBeZero();
        }
        if (pairedValueIn | initializationParameters.initialSupplyAmount > type(uint120).max) {
            revert TokenMasterERC20__InvalidPairedValues();
        }

        MINIMUM_BUY_SPREAD_BPS = uint16(initializationParameters.minBuySpreadBPS);
        MAXIMUM_BUY_SPREAD_BPS = uint16(initializationParameters.maxBuySpreadBPS);
        MAXIMUM_BUY_FEE_BPS = uint16(initializationParameters.maxBuyFeeBPS);
        MAXIMUM_BUY_DEMAND_FEE_BPS = uint16(initializationParameters.maxBuyDemandFeeBPS);
        MINIMUM_SELL_SPREAD_BPS = uint16(initializationParameters.minSellSpreadBPS);
        MAXIMUM_SELL_SPREAD_BPS = uint16(initializationParameters.maxSellSpreadBPS);
        MAXIMUM_SELL_FEE_BPS = uint16(initializationParameters.maxSellFeeBPS);
        MAXIMUM_SPEND_CREATOR_SHARE_BPS = uint16(initializationParameters.maxSpendCreatorShareBPS);
        CREATOR_EMISSION_RATE_NUMERATOR = uint128(initializationParameters.creatorEmissionRateNumerator);
        CREATOR_EMISSION_RATE_DENOMINATOR = uint128(initializationParameters.creatorEmissionRateDenominator);

        marketPairedTokenShare = pairedValueIn;
        creatorLastEmissionsClaimTimestamp = uint48(block.timestamp);
        creatorEmissionsHardCap = initializationParameters.creatorEmissionsHardCap;

        _setPausableFlags(initializationParameters.initialPausedState);

        _setBuyParameters(initializationParameters.initialBuyParameters);
        _setSellParameters(initializationParameters.initialSellParameters);
        _setSpendParameters(initializationParameters.initialSpendParameters);

        _mint(ROUTER, ONE);
        _mint(initializationParameters.initialSupplyRecipient, initializationParameters.initialSupplyAmount - ONE);
    }

    /*************************************************************************/
    /*                              POOL FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Executes a buy of tokens.
     * 
     * @dev     Throws when the creator has paused buys.
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * @dev     Throws when the amount of value in is insufficient for the tokens being bought.
     * @dev     Throws when the amount of tokens to buy exceeds the pool maximum.
     * @dev     Throws when the amount of paired tokens in will exceed the pool maximum.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Market value of the tokens has been added to market share.
     * @dev    2. Purchased tokens have been minted to the buyer.
     * 
     * @param buyer          Address of the buyer. 
     * @param pairedTokenIn  Amount of paired token transferred in for the buy.
     * @param tokensToBuy    Amount of tokens being bought.
     * 
     * @return totalCost             Total amount of buy cost including fees. 
     * @return refundByRouterAmount  Amount of paired token to be refunded by the router.
     */
    function buyTokens(
        address buyer,
        uint256 pairedTokenIn,
        uint256 tokensToBuy
    ) external payable returns (uint256 totalCost, uint256 refundByRouterAmount) {
        _requireNotPaused(PAUSE_FLAG_BUYS);
        _callerIsRouter();
        
        (
            uint16 buySpreadBPS,
            uint16 buyFeeBPS,
            uint96 buyCostPairedTokenNumerator,
            uint96 buyCostPoolTokenDenominator,
            uint16 buyDemandFeeBPS,
            uint256 expectedSupply
        ) = _loadBuyParameters();

        uint256 startPairedTokenBalance = marketPairedTokenShare;
        uint256 startTokenSupply = totalSupply();

        address cachedBuyer = buyer;
        uint256 cachedPairedTokenIn = pairedTokenIn;
        uint256 cachedTokensToBuy = tokensToBuy;

        uint256 pairedToPool = _calculatePairedToPool(cachedTokensToBuy, (startPairedTokenBalance * BPS / (BPS - buySpreadBPS)), startTokenSupply);
        uint256 pairedToCreatorShare = cachedTokensToBuy * buyCostPairedTokenNumerator / buyCostPoolTokenDenominator + pairedToPool * buyFeeBPS / BPS;

        if (expectedSupply > 0) {
            uint256 adjustedPooledTokenSupply = startTokenSupply + cachedTokensToBuy;
            if (expectedSupply < adjustedPooledTokenSupply) {
                uint256 demandFee = cachedTokensToBuy * ((startPairedTokenBalance * adjustedPooledTokenSupply / expectedSupply) - startPairedTokenBalance) / startTokenSupply;
                uint256 creatorShareOfDemandFee = demandFee * buyDemandFeeBPS / BPS;
                pairedToCreatorShare += creatorShareOfDemandFee;
                pairedToPool += (demandFee - creatorShareOfDemandFee);
            }
        }

        totalCost = pairedToPool + pairedToCreatorShare;
        uint256 refundAmount;
        if (cachedPairedTokenIn < totalCost) {
            revert TokenMasterERC20__InsufficientBuyInput();
        } else {
            unchecked {
                refundAmount = cachedPairedTokenIn - totalCost;
            }
        }

        uint256 updatedMarketPairedTokenShare = startPairedTokenBalance + pairedToPool;
        if (updatedMarketPairedTokenShare | (startTokenSupply + cachedTokensToBuy) > type(uint120).max) {
            revert TokenMasterERC20__InvalidPairedValues();
        }

        marketPairedTokenShare = updatedMarketPairedTokenShare;
        _mint(cachedBuyer, cachedTokensToBuy);

        unchecked {
            refundByRouterAmount = _transferPairedToken(cachedBuyer, refundAmount);
        }
    }

    /**
     * @notice Executes a sale of tokens.
     * 
     * @dev     Throws when the creator has paused sales.
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * @dev     Throws when the amount of value to be sent to the seller is less than their specified minimum.
     * @dev     Throws when paired with native token and the native token transfer to the seller fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Sold tokens have been burned from the seller.
     * @dev    2. Market value of the tokens, less spread, has been removed from the market share.
     * @dev    3. Market value of the tokens, less spread and fees, has been transferred to the seller.
     * 
     * @param seller                 Address of the seller.
     * @param tokensToSell           Amount of tokens being sold.
     * @param pairedTokenMinimumOut  Minimum output of paired token without reverting the transaction.
     * 
     * @return pairedToken             Address of the paired token for the pool. 
     * @return pairedValueToSeller     Amount of value received by the seller.
     * @return transferByRouterAmount  Amount of paired token to be transferred to the seller by the router.
     */
    function sellTokens(
        address seller,
        uint256 tokensToSell,
        uint256 pairedTokenMinimumOut
    ) external returns (address pairedToken, uint256 pairedValueToSeller, uint256 transferByRouterAmount) {
        _requireNotPaused(PAUSE_FLAG_SELLS);
        _callerIsRouter();

        uint256 tokenSupply = totalSupply();
        uint256 sellSpreadBPS = sellParameters.sellSpreadBPS;
        uint256 pairedTokenValue = tokensToSell * marketPairedTokenShare / tokenSupply;
        uint256 pairedValueFromMarket = pairedTokenValue * (BPS - sellSpreadBPS) / BPS;
        pairedValueToSeller = pairedTokenValue * (BPS - sellSpreadBPS - sellParameters.sellFeeBPS) / BPS;

        if (pairedValueToSeller < pairedTokenMinimumOut) {
            revert TokenMasterERC20__InsufficientSellOutput();
        }

        marketPairedTokenShare -= pairedValueFromMarket;
        _burn(seller, tokensToSell);
        
        pairedToken = PAIRED_TOKEN;
        transferByRouterAmount = _transferPairedToken(seller, pairedValueToSeller);
    }

    /**
     * @notice Executes a spend of tokens.
     * 
     * @dev     Throws when the creator has paused spends.
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Spent tokens have been burned from the spender.
     * @dev    2. Creator share of market value of tokens has been subtracted from market share.
     * 
     * @param spender        Address of the spender.
     * @param tokensToSpend  Amount of tokens being spent.
     */
    function spendTokens(address spender, uint256 tokensToSpend) external {
        _requireNotPaused(PAUSE_FLAG_SPENDS);
        _callerIsRouter();

        uint256 tokenSupply = totalSupply();
        uint256 pairedTokenValue = tokensToSpend * marketPairedTokenShare / tokenSupply;
        uint256 pairedValueFromMarket = pairedTokenValue * spendParameters.creatorShareBPS / BPS;

        marketPairedTokenShare -= pairedValueFromMarket;

        _burn(spender, tokensToSpend);
    }

    /*************************************************************************/
    /*                           CREATOR FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Sets the parameters for buy orders.
     * 
     * @dev     Throws when the caller is not the owner.
     * @dev     Throws when the settings are invalid.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Buy parameters have been stored.
     * @dev    2. A `BuyParametersUpdated` event has been emitted.
     * 
     * @param _buyParameters  The parameters to set for buy orders.
     */
    function setBuyParameters(StandardPoolBuyParameters calldata _buyParameters) external onlyOwner {
        _setBuyParameters(_buyParameters);

        emit BuyParametersUpdated();
    }

    /**
     * @notice  Sets the parameters for sell orders.
     * 
     * @dev     Throws when the caller is not the owner.
     * @dev     Throws when the settings are invalid.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Sell parameters have been stored.
     * @dev    2. A `SellParametersUpdated` event has been emitted.
     * 
     * @param _sellParameters  The parameters to set for sell orders.
     */
    function setSellParameters(StandardPoolSellParameters calldata _sellParameters) external onlyOwner {
        _setSellParameters(_sellParameters);

        emit SellParametersUpdated();
    }

    /**
     * @notice  Sets the parameters for spend orders.
     * 
     * @dev     Throws when the caller is not the owner.
     * @dev     Throws when the settings are invalid.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Spend parameters have been stored.
     * @dev    2. A `SpendParametersUpdated` event has been emitted.
     * 
     * @param _spendParameters  The parameters to set for spend orders.
     */
    function setSpendParameters(StandardPoolSpendParameters calldata _spendParameters) external onlyOwner {
        _setSpendParameters(_spendParameters);

        emit SpendParametersUpdated();
    }

    /**
     * @notice  Transfers an amount of creator share to the market share of the pool.
     * 
     * @dev     The entire infrastructure and partner shares will be withdrawn when this function is called.
     * @dev     When the paired token is ERC20 and tokens fail to transfer by the contract, the transfer
     * @dev     will fall back to attempting to transfer by the router contract.
     * 
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * @dev     Throws when the amount to transfer exceeds the creator share.
     * @dev     Throws when the paired token is native and a share transfer fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Transfer amount has been added to market share.
     * @dev    2. Partner fees have been transferred to the partner fee receiver.
     * @dev    3. Infrastructure fees have been transferred to the infrastructure fee receiver.
     * @dev    4. A `CreatorShareWithdrawn` event has been emitted.
     * 
     * @param transferAmount              Amount to transfer from creator share to market.
     * @param infrastructureFeeRecipient  Address of the infra fee receipient.
     * @param partnerFeeRecipient         Address of the partner fee recipient.
     * 
     * @return pairedToken                           Address of the paired token for router transfers.
     * @return transferByRouterAmountInfrastructure  Amount of paired token to transfer to infra by router.
     * @return transferByRouterAmountPartner         Amount of paired token to transfer to partner by router.
     */
    function transferCreatorShareToMarket(
        uint256 transferAmount,
        address infrastructureFeeRecipient,
        address partnerFeeRecipient
    ) 
    external virtual override(BondedPool, ITokenMasterERC20C) 
    returns (address pairedToken, uint256 transferByRouterAmountInfrastructure, uint256 transferByRouterAmountPartner) {
        _callerIsRouter();

        (
            uint256 _creatorShare,
            uint256 _infrastructureShare,
            uint256 _partnerShare
        ) = _creatorPairedTokenShare();

        if (transferAmount > _creatorShare) {
            revert TokenMasterERC20__WithdrawOrTransferAmountGreaterThanShare();
        } else if (transferAmount < _creatorShare) {
            unchecked {
                // Entire infrastructure/partner fee is withdrawn even when creator transfers a partial amount
                // set creator share fee paid adjustment to the amount remaining to account for the
                // fees already being paid on that portion.
                creatorShareFeesPaidAdjustment = _creatorShare - transferAmount;
            }
        } else {
            // Creator is transfering their entire share, reset creator share fee paid adjustment to zero
            creatorShareFeesPaidAdjustment = 0;
        }

        unchecked {
            marketPairedTokenShare += transferAmount;
        }

        pairedToken = PAIRED_TOKEN;
        transferByRouterAmountInfrastructure = _transferPairedToken(infrastructureFeeRecipient, _infrastructureShare);
        transferByRouterAmountPartner = _transferPairedToken(partnerFeeRecipient, _partnerShare);

        emit CreatorShareTransferredToMarket(address(this), transferAmount, _infrastructureShare, _partnerShare);
    }

    /**
     * @notice  Sets a new cap for creator emissions.
     * 
     * @dev     Throws when the caller is not the owner of the pool.
     * @dev     Throws when the new hard cap amount is greater than the current amount.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Emissions hard cap has been lowered.
     * @dev    2. A `CreatorEmissionsHardCapUpdated` event has been emitted.
     * 
     * @param newHardCapAmount  Amount to set as the emissions hard cap.
     */
    function setEmissionsHardCap(uint256 newHardCapAmount) external onlyOwner {
        if (newHardCapAmount > creatorEmissionsHardCap) {
            revert TokenMasterERC20__NewHardCapGreaterThanCurrent();
        }
        creatorEmissionsHardCap = newHardCapAmount;

        emit CreatorEmissionsHardCapUpdated(newHardCapAmount);
    }

    /**
     * @notice  Claims available creator emissions.
     * 
     * @dev     Allows creator to forfeit an amount of tokens from the current claim. Forfeitted
     * @dev     tokens do not count against the hard cap amount but do require the creator to wait
     * @dev     for the emissions to accrue again over time. This allows a creator to defer the claim
     * @dev     to a later time.
     * 
     * @dev     Throws when the caller is not the owner of the pool.
     * @dev     Throws when the amount to forfeit is greater than the claimable amount.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The last claim timestamp and creator emissions claimed state has been updated.
     * @dev    2. Emissions have been minted to the claim to address.
     * @dev    2. A `CreatorEmissionsClaimed` event has been emitted.
     * 
     * @param claimTo        Address to send creator emissions being claimed to.
     * @param forfeitAmount  Amount of tokens to forfeit from the claim.
     */
    function claimEmissions(address claimTo, uint256 forfeitAmount) external onlyOwner {
        (uint256 claimAmount, uint256 cachedCreatorEmissionsClaimed) = _calculateCreatorEmissionsClaimable();
        if (forfeitAmount > claimAmount) {
            revert TokenMasterERC20__ForfeitAmountGreaterThanClaimable();
        }
        creatorLastEmissionsClaimTimestamp = uint48(block.timestamp);
        unchecked {
            claimAmount -= forfeitAmount;
        }
        creatorEmissionsClaimed = cachedCreatorEmissionsClaimed + claimAmount;
        _mint(claimTo, claimAmount);

        emit CreatorEmissionsClaimed(claimTo, claimAmount, forfeitAmount);
    }

    /*************************************************************************/
    /*                             VIEW FUNCTIONS                            */
    /*************************************************************************/

    /**
     * @notice  Returns the current settings for buy orders.
     * 
     * @return _buyParameters  The current buy parameters.
     */
    function getBuyParameters() external view returns(StandardPoolBuyParameters memory _buyParameters) {
        _buyParameters = buyParameters;
    }

    /**
     * @notice  Returns the current settings for sell orders.
     * 
     * @return _sellParameters  The current sell parameters.
     */
    function getSellParameters() external view returns(StandardPoolSellParameters memory _sellParameters) {
        _sellParameters = sellParameters;
    }

    /**
     * @notice  Returns the current settings for spend orders.
     * 
     * @return _spendParameters  The current spend parameters.
     */
    function getSpendParameters() external view returns(StandardPoolSpendParameters memory _spendParameters) {
        _spendParameters = spendParameters;
    }

    /**
     * @notice  Returns the current status of creator emissions.
     * 
     * @return claimed                         Amount of creator emissions that have been claimed.
     * @return claimable                       Amount of creator emissions that are claimable.
     * @return hardCap                         Hard cap on total creator emissions that may be claimed.
     * @return lastClaim                       Timestamp that the creator last claimed emissions.
     * @return creatorEmissionRateNumerator    Numerator for the rate in tokens per second that a creator earns emissions.
     * @return creatorEmissionRateDenominator  Denominator for the rate in tokens per second that a creator earns emissions.
     */
    function getCreatorEmissions() external view returns(
        uint256 claimed,
        uint256 claimable,
        uint256 hardCap,
        uint48 lastClaim,
        uint128 creatorEmissionRateNumerator,
        uint128 creatorEmissionRateDenominator
    ) {
        (claimable,claimed) = _calculateCreatorEmissionsClaimable();
        hardCap = creatorEmissionsHardCap;
        lastClaim = creatorLastEmissionsClaimTimestamp;
        creatorEmissionRateNumerator = CREATOR_EMISSION_RATE_NUMERATOR;
        creatorEmissionRateDenominator = CREATOR_EMISSION_RATE_DENOMINATOR;
    }

    /**
     * @notice  Returns the current target supply of a standard pool.
     * 
     * @return useTargetSupply  True if the pool is using a target supply for demand fees.
     * @return target           The current target supply amount.
     */
    function targetSupply() external view returns(bool useTargetSupply, uint256 target) {
        (,,,,,target) = _loadBuyParameters();
        useTargetSupply = target != 0;
    }
    
    /**
     * @notice  Returns the guardrails for parameters that may be set by the creator.
     * 
     * @return minBuySpreadBPS          The minimum spread rate in BPS for buys that may be set by the creator.
     * @return maxBuySpreadBPS          The maximum spread rate in BPS for buys that may be set by the creator.
     * @return maxBuyFeeBPS             The maximum buy fee rate in BPS that may be set by the creator.
     * @return maxBuyDemandFeeBPS       The maximum buy demand fee rate in BPS that may be set by the creator.
     * @return minSellSpreadBPS         The minimum spread rate in BPS for sells that may be set by the creator.
     * @return maxSellSpreadBPS         The maximum spread rate in BPS for sells that may be set by the creator.
     * @return maxSellFeeBPS            The maximum sell fee rate in BPS that may be set by the creator.
     * @return maxSpendCreatorShareBPS  The maximum creator share rate in BPS for spends that may be set by the creator.
     */
    function getParameterGuardrails() external view returns(
        uint16 minBuySpreadBPS,
        uint16 maxBuySpreadBPS,
        uint16 maxBuyFeeBPS,
        uint16 maxBuyDemandFeeBPS,
        uint16 minSellSpreadBPS,
        uint16 maxSellSpreadBPS,
        uint16 maxSellFeeBPS,
        uint16 maxSpendCreatorShareBPS
    ) {
        minBuySpreadBPS = MINIMUM_BUY_SPREAD_BPS;
        maxBuySpreadBPS = MAXIMUM_BUY_SPREAD_BPS;
        maxBuyFeeBPS = MAXIMUM_BUY_FEE_BPS;
        maxBuyDemandFeeBPS = MAXIMUM_BUY_DEMAND_FEE_BPS;
        minSellSpreadBPS = MINIMUM_SELL_SPREAD_BPS;
        maxSellSpreadBPS = MAXIMUM_SELL_SPREAD_BPS;
        maxSellFeeBPS = MAXIMUM_SELL_FEE_BPS;
        maxSpendCreatorShareBPS = MAXIMUM_SPEND_CREATOR_SHARE_BPS;
    }

    /*************************************************************************/
    /*                           INTERNAL FUNCTIONS                          */
    /*************************************************************************/

    /**
     * @dev  Returns the market share of the paired token which is tracked as a state variable.
     */
    function _bondedMarketValue() internal virtual view override returns(uint256) {
        return marketPairedTokenShare;
    }

    /**
     * @notice  Calculates the amount of creator emissions that are currently claimable.
     * 
     * @return claimable                      Amount of emissions currently claimable.
     * @return cachedCreatorEmissionsClaimed  Amount of emissions already claimed.
     */
    function _calculateCreatorEmissionsClaimable() internal view returns(uint256 claimable, uint256 cachedCreatorEmissionsClaimed) {
        claimable = CREATOR_EMISSION_RATE_NUMERATOR * (block.timestamp - creatorLastEmissionsClaimTimestamp) / CREATOR_EMISSION_RATE_DENOMINATOR;
        uint256 cachedCreatorEmissionsHardCap = creatorEmissionsHardCap;
        cachedCreatorEmissionsClaimed = creatorEmissionsClaimed;
        if (cachedCreatorEmissionsClaimed > cachedCreatorEmissionsHardCap) {
            claimable = 0;
        } else {
            unchecked {
                uint256 maxClaimable = cachedCreatorEmissionsHardCap - cachedCreatorEmissionsClaimed;
                if (claimable > maxClaimable) {
                    claimable = maxClaimable;
                }
            }
        }
    }

    /**
     * @dev  Validates the buy parameters being set do not exceed guardrails and stores them.
     * 
     * @dev  Throws when a setting exceeds a guardrail.
     * 
     * @param _buyParameters  The parameters to set for buy orders.
     */
    function _setBuyParameters(StandardPoolBuyParameters memory _buyParameters) internal {
        if (
            _buyParameters.buySpreadBPS > MAXIMUM_BUY_SPREAD_BPS 
            || _buyParameters.buySpreadBPS < MINIMUM_BUY_SPREAD_BPS
            || _buyParameters.buyFeeBPS > MAXIMUM_BUY_FEE_BPS
            || _buyParameters.buyDemandFeeBPS > MAXIMUM_BUY_DEMAND_FEE_BPS
            || _buyParameters.buyCostPoolTokenDenominator == 0
        ) {
            revert TokenMasterERC20__InvalidParameters();
        }
        if (
            _buyParameters.useTargetSupply && _buyParameters.targetSupplyBaselineScaleFactor > MAX_BASELINE_SCALE_FACTOR
        ) {
            revert TokenMasterERC20__InvalidParameters();
        }

        buyParameters = _buyParameters;
    }

    /**
     * @dev  Validates the sell parameters being set do not exceed guardrails and stores them.
     * 
     * @dev  Throws when a setting exceeds a guardrail.
     * 
     * @param _sellParameters  The parameters to set for sell orders.
     */
    function _setSellParameters(StandardPoolSellParameters memory _sellParameters) internal {
        if (
            _sellParameters.sellSpreadBPS < MINIMUM_SELL_SPREAD_BPS
            || _sellParameters.sellSpreadBPS > MAXIMUM_SELL_SPREAD_BPS
            || _sellParameters.sellFeeBPS > MAXIMUM_SELL_FEE_BPS 
            || (_sellParameters.sellSpreadBPS + _sellParameters.sellFeeBPS) > BPS
        ) {
            revert TokenMasterERC20__InvalidParameters();
        }
        sellParameters = _sellParameters;
    }

    /**
     * @dev  Validates the spend parameters being set do not exceed guardrails and stores them.
     * 
     * @dev  Throws when a setting exceeds a guardrail.
     * 
     * @param _spendParameters  The parameters to set for spend orders.
     */
    function _setSpendParameters(StandardPoolSpendParameters memory _spendParameters) internal {
        if (_spendParameters.creatorShareBPS > MAXIMUM_SPEND_CREATOR_SHARE_BPS) {
            revert TokenMasterERC20__InvalidParameters();
        }
        spendParameters = _spendParameters;
    }

    /**
     * @dev  Loads buy parameters from storage onto stack for executing a buy.
     * 
     * @return buySpreadBPS                 Spread rate in BPS for the cost of tokens above the current market value.
     * @return buyFeeBPS                    Buy fee rate in BPS that will be applied to a buy order.
     * @return buyCostPairedTokenNumerator  The numerator for the ratio of paired token to pool token as an additional buy fee.
     * @return buyCostPoolTokenDenominator  The denominator for the ratio of paired token to pool token as an additional buy fee.
     * @return buyDemandFeeBPS              Rate in BPS of the amount of demand fee that is allocated to the creator.
     * @return expectedSupply               The expected supply of the token based on target supply values. Zero if target supply is not used.
     */
    function _loadBuyParameters() internal view returns(
        uint16 buySpreadBPS,
        uint16 buyFeeBPS,
        uint96 buyCostPairedTokenNumerator,
        uint96 buyCostPoolTokenDenominator,
        uint16 buyDemandFeeBPS,
        uint256 expectedSupply
    ) {
        buySpreadBPS = buyParameters.buySpreadBPS;
        buyFeeBPS = buyParameters.buyFeeBPS;
        buyCostPairedTokenNumerator = buyParameters.buyCostPairedTokenNumerator;
        buyCostPoolTokenDenominator = buyParameters.buyCostPoolTokenDenominator;
        if (buyParameters.useTargetSupply) {
            buyDemandFeeBPS = buyParameters.buyDemandFeeBPS;
            unchecked {
                expectedSupply = buyParameters.targetSupplyBaseline * 10 ** buyParameters.targetSupplyBaselineScaleFactor;
                uint256 targetSupplyBaselineTimestamp = buyParameters.targetSupplyBaselineTimestamp;
                if (targetSupplyBaselineTimestamp < block.timestamp) {
                    expectedSupply +=
                        buyParameters.targetSupplyGrowthRatePerSecond * (block.timestamp - buyParameters.targetSupplyBaselineTimestamp);
                }
            }
        }
    }

    /**
     * @dev  Internal override of `_requireCallerHasPausePermissions` to check the caller is the owner for PausableFlags.
     */
    function _requireCallerHasPausePermissions() internal view override {
        _checkOwner();
    }

    /**
     * @dev  Extends the ERC165 interface support check with additional interfaces supported by StandardPool.
     * 
     * @param interfaceId The interface id
     */
    function _supportsInterfaceExtended(bytes4 interfaceId) internal virtual view override returns (bool) {
        return 
        interfaceId == type(IStandardPool).interfaceId ||
        interfaceId == type(ICreatorEmissionsPool).interfaceId;
    }
}