//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./IStablePool.sol";
import "./DataTypes.sol";
import "../../Constants.sol";
import "../../DataTypes.sol";
import "../../Errors.sol";

import "../BondedPool.sol";

import "@limitbreak/tm-core-lib/src/token/erc20/ERC20C.sol";
import "@limitbreak/tm-core-lib/src/token/erc20/utils/SafeERC20.sol";
import "@limitbreak/tm-core-lib/src/utils/access/Ownable2Step.sol";
import "@limitbreak/tm-core-lib/src/utils/access/OwnableAccessControl.sol";
import "@limitbreak/tm-core-lib/src/licenses/LicenseRef-PolyForm-Strict-1.0.0.sol";

/**
 * @title  StablePool
 * @author Limit Break, Inc.
 * @notice The StablePool contract is a TokenMaster pool token that is designed to
 *         maintain a stable market value.
 * 
 * @dev    <h4>Features</h4>
 *         - ERC20C token with full creator controls.
 *         - Deployed through TokenMasterRouter.
 *         - Market value of token is fixed at a stable price.
 *         - Creator specified buy and sell fees with guardrails.
 *         - Creator earnings when tokens are spent through TokenMaster.
 */
contract StablePool is BondedPool, IStablePool {

    /// @dev Guardrail for buy fee BPS.
    uint16 private immutable MAXIMUM_BUY_FEE_BPS;
    /// @dev Guardrail for sell fee BPS.
    uint16 private immutable MAXIMUM_SELL_FEE_BPS;

    /// @dev The numerator for the ratio of paired token to pool token that will be the stable price of a token before fees.
    uint96 private immutable PAIRED_PRICE_PER_TOKEN_NUMERATOR;
    /// @dev The denominator for the ratio of paired token to pool token that will be the stable price of a token before fees.
    uint96 private immutable PAIRED_PRICE_PER_TOKEN_DENOMINATOR;

    /// @dev Parameters that are applied to buys.
    StablePoolBuyParameters private buyParameters;
    /// @dev Parameters that are applied to sells.
    StablePoolSellParameters private sellParameters;

    constructor(
        PoolDeploymentParameters memory deploymentParams,
        uint256 /*pairedValueIn*/,
        uint256 infrastructureFeeBPS,
        address router
    ) BondedPool(deploymentParams, infrastructureFeeBPS, router) {
        StablePoolInitializationParameters memory initializationParameters = 
            abi.decode(deploymentParams.encodedInitializationArgs, (StablePoolInitializationParameters));
        
        if (initializationParameters.maxBuyFeeBPS > BPS || 
            initializationParameters.maxSellFeeBPS > BPS ||
            initializationParameters.stablePairedPricePerToken.numerator == 0 ||
            initializationParameters.stablePairedPricePerToken.denominator == 0) {
            revert TokenMasterERC20__InvalidParameters();
        }
        if (initializationParameters.initialSupplyAmount > type(uint128).max) {
            revert TokenMasterERC20__InvalidPairedValues();
        }
        
        MAXIMUM_BUY_FEE_BPS = uint16(initializationParameters.maxBuyFeeBPS);
        MAXIMUM_SELL_FEE_BPS = uint16(initializationParameters.maxSellFeeBPS);

        PAIRED_PRICE_PER_TOKEN_NUMERATOR = initializationParameters.stablePairedPricePerToken.numerator;
        PAIRED_PRICE_PER_TOKEN_DENOMINATOR = initializationParameters.stablePairedPricePerToken.denominator;

        (uint256 _creatorShare, uint256 _infrastructureShare, uint256 _partnerShare) = _creatorPairedTokenShare();

        uint256 minimumSeedFunding = 
            initializationParameters.initialSupplyAmount * 
            PAIRED_PRICE_PER_TOKEN_NUMERATOR / 
            PAIRED_PRICE_PER_TOKEN_DENOMINATOR;

        if ((_creatorShare + _infrastructureShare + _partnerShare) < minimumSeedFunding) {
            revert TokenMasterERC20__InsufficientSeedFunding();
        }

        _setBuyParameters(initializationParameters.initialBuyParameters);
        _setSellParameters(initializationParameters.initialSellParameters);

        _mint(initializationParameters.initialSupplyRecipient, initializationParameters.initialSupplyAmount);
    }

    /*************************************************************************/
    /*                              POOL FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Executes a buy of tokens.
     * 
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * @dev     Throws when the amount of tokens to buy exceeds the pool maximum.
     * @dev     Throws when the amount of value in is insufficient for the tokens being bought.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Purchased tokens have been minted to the buyer.
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
        _callerIsRouter();

        if (tokensToBuy > type(uint128).max) {
            revert TokenMasterERC20__InvalidPairedValues();
        }

        unchecked {
            uint256 pairedToPool = _calculatePairedToPool(tokensToBuy, PAIRED_PRICE_PER_TOKEN_NUMERATOR, PAIRED_PRICE_PER_TOKEN_DENOMINATOR);
            uint256 pairedToCreatorShare = pairedToPool * buyParameters.buyFeeBPS / BPS;
    
            totalCost = pairedToPool + pairedToCreatorShare;
    
            uint256 refundAmount = pairedTokenIn - totalCost;
            if (refundAmount > pairedTokenIn) {
                revert TokenMasterERC20__InsufficientBuyInput();
            }
    
            _mint(buyer, tokensToBuy);
            refundByRouterAmount = _transferPairedToken(buyer, refundAmount);
        }
    }

    /**
     * @notice Executes a sale of tokens.
     * 
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * @dev     Throws when the amount of value to be sent to the seller is less than their specified minimum.
     * @dev     Throws when paired with native token and the native token transfer to the seller fails.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Sold tokens have been burned from the seller.
     * @dev    2. Market value of the tokens, less fees, has been transferred to the seller.
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
        _callerIsRouter();

        pairedValueToSeller = 
            (tokensToSell * PAIRED_PRICE_PER_TOKEN_NUMERATOR / PAIRED_PRICE_PER_TOKEN_DENOMINATOR) * 
            (BPS - sellParameters.sellFeeBPS) / BPS;

        if (pairedValueToSeller < pairedTokenMinimumOut) {
            revert TokenMasterERC20__InsufficientSellOutput();
        }

        _burn(seller, tokensToSell);
        
        pairedToken = PAIRED_TOKEN;
        transferByRouterAmount = _transferPairedToken(seller, pairedValueToSeller);
    }

    /**
     * @notice Executes a spend of tokens.
     * 
     * @dev     Throws when the caller is not the TokenMasterRouter.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Spent tokens have been burned from the spender.
     * 
     * @param spender        Address of the spender.
     * @param tokensToSpend  Amount of tokens being spent.
     */
    function spendTokens(address spender, uint256 tokensToSpend) external {
        _callerIsRouter();
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
    function setBuyParameters(StablePoolBuyParameters calldata _buyParameters) external onlyOwner {
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
    function setSellParameters(StablePoolSellParameters calldata _sellParameters) external onlyOwner {
        _setSellParameters(_sellParameters);

        emit SellParametersUpdated();
    }

    /*************************************************************************/
    /*                             VIEW FUNCTIONS                            */
    /*************************************************************************/

    /**
     * @notice  Returns the current settings for buy orders.
     * 
     * @return _buyParameters  The current buy parameters.
     */
    function getBuyParameters() external view returns(StablePoolBuyParameters memory _buyParameters) {
        _buyParameters = buyParameters;
    }

    /**
     * @notice  Returns the current settings for sell orders.
     * 
     * @return _sellParameters  The current sell parameters.
     */
    function getSellParameters() external view returns(StablePoolSellParameters memory _sellParameters) {
        _sellParameters = sellParameters;
    }

    /**
     * @notice  Returns the ratio of paired token to pool token for the stable pool.
     * 
     * @return numerator    The numerator for the ratio of paired token to pool token.
     * @return denominator  The denominator for the ratio of paired token to pool token.
     */
    function getStablePriceRatio() external view returns(uint96 numerator, uint96 denominator) {
        numerator = PAIRED_PRICE_PER_TOKEN_NUMERATOR;
        denominator = PAIRED_PRICE_PER_TOKEN_DENOMINATOR;
    }

    /**
     * @notice  Returns the guardrails for maximum fees that may be set by the creator.
     * 
     * @return maxBuyFeeBPS   The maximum buy fee rate in BPS that may be set by the creator.
     * @return maxSellFeeBPS  The maximum sell fee rate in BPS that may be set by the creator.
     */
    function getParameterGuardrails() external view returns (uint16 maxBuyFeeBPS, uint16 maxSellFeeBPS) {
        maxBuyFeeBPS = MAXIMUM_BUY_FEE_BPS;
        maxSellFeeBPS = MAXIMUM_SELL_FEE_BPS;
    }

    /*************************************************************************/
    /*                           INTERNAL FUNCTIONS                          */
    /*************************************************************************/

    /**
     * @dev  Calculates the bonded market value of a stable pool using the pool supply,
     * @dev  and stable pool price ratio.
     */
    function _bondedMarketValue() internal virtual view override returns(uint256) {
        return totalSupply() * PAIRED_PRICE_PER_TOKEN_NUMERATOR / PAIRED_PRICE_PER_TOKEN_DENOMINATOR;
    }

    /**
     * @dev  Validates the buy parameters being set do not exceed guardrails and stores them.
     * 
     * @dev  Throws when a setting exceeds a guardrail.
     * 
     * @param _buyParameters  The parameters to set for buy orders.
     */
    function _setBuyParameters(StablePoolBuyParameters memory _buyParameters) internal {
        if (_buyParameters.buyFeeBPS > MAXIMUM_BUY_FEE_BPS) {
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
    function _setSellParameters(StablePoolSellParameters memory _sellParameters) internal {
        if (_sellParameters.sellFeeBPS > MAXIMUM_SELL_FEE_BPS || _sellParameters.sellFeeBPS > BPS) {
            revert TokenMasterERC20__InvalidParameters();
        }
        sellParameters = _sellParameters;
    }

    /**
     * @dev  Extends the ERC165 interface support check with additional interfaces supported by StablePool.
     * 
     * @param interfaceId The interface id
     */
    function _supportsInterfaceExtended(bytes4 interfaceId) internal virtual view override returns (bool) {
        return interfaceId == type(IStablePool).interfaceId;
    }
}