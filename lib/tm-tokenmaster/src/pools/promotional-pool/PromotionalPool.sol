//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./IPromotionalPool.sol";
import "./DataTypes.sol";
import "../../Constants.sol";
import "../../DataTypes.sol";
import "../../Errors.sol";

import "../BondedPool.sol";
import "../../interfaces/IMinterBurnerRolePool.sol";

import "@limitbreak/tm-core-lib/src/token/erc20/ERC20C.sol";
import "@limitbreak/tm-core-lib/src/token/erc20/utils/SafeERC20.sol";
import "@limitbreak/tm-core-lib/src/utils/access/Ownable2Step.sol";
import "@limitbreak/tm-core-lib/src/utils/access/OwnableAccessControl.sol";
import "@limitbreak/tm-core-lib/src/licenses/LicenseRef-PolyForm-Strict-1.0.0.sol";

/**
 * @title  PromotionalPool
 * @author Limit Break, Inc.
 * @notice The PromotionalPool contract is a TokenMaster pool token that is designed for
 *         valueless promotional tokens that a creator has full control over minting and 
 *         burning with no constraints related to bonded token value while still allowing
 *         full use of TokenMaster for deploying and executing spend orders.
 * 
 * @dev    <h4>Features</h4>
 *         - ERC20C token with full creator controls.
 *         - Deployed through TokenMasterRouter.
 *         - Zero bonded market value for promotional tokens.
 *         - Creator specified buy rate with a paired value token if creator wishes to
 *             allow purchases of the promotional token by participants.
 *         - Creator can grant minting and burning roles to external addresses to mint
 *             and burn tokens to and from any account.
 */
contract PromotionalPool is BondedPool, IPromotionalPool, IMinterBurnerRolePool {

    /// @dev Role constant for assigning an address to the minter role.
    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @dev Role constant for assigning an address to the burner role.
    bytes32 private constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @dev Parameters that are applied to buys.
    PromotionalPoolBuyParameters private buyParameters;

    constructor(
        PoolDeploymentParameters memory deploymentParams,
        uint256 pairedValueIn,
        uint256 infrastructureFeeBPS,
        address router
    ) BondedPool(deploymentParams, infrastructureFeeBPS, router) {
        if (pairedValueIn > 0) {
            revert TokenMasterERC20__InvalidPairedValues();
        }

        PromotionalPoolInitializationParameters memory initializationParameters = 
            abi.decode(deploymentParams.encodedInitializationArgs, (PromotionalPoolInitializationParameters));

        _setBuyParameters(initializationParameters.initialBuyParameters);
        _mint(initializationParameters.initialSupplyRecipient, initializationParameters.initialSupplyAmount);
    }

    /*************************************************************************/
    /*                    DISTRIBUTION (MINT/BURN) FUNCTIONS                 */
    /*************************************************************************/

    /**
     * @notice  Mints an amount of tokens to an address.
     * 
     * @dev     Throws when the caller does not have the minter role.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Tokens have been minted to the address.
     * 
     * @param to      Address to mint tokens to.
     * @param amount  Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice  Mints tokens to specified addresses in specified amounts.
     * 
     * @dev     Throws when the caller does not have the minter role.
     * @dev     Throws when the array lengths of the to addresses and amounts do not match.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Tokens have been minted to each address specified.
     * 
     * @param toAddresses  Addresses to mint tokens to.
     * @param amounts      Amounts of tokens to mint.
     */
    function mintBatch(address[] calldata toAddresses, uint256[] calldata amounts) external onlyRole(MINTER_ROLE) {
        if (toAddresses.length != amounts.length) {
            revert TokenMasterERC20__ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < toAddresses.length; ++i) {
            _mint(toAddresses[i], amounts[i]);
        }
    }

    /**
     * @notice  Burns an amount of tokens from an address.
     * 
     * @dev     Throws when the caller does not have the burner role.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Tokens have been burned from the address.
     * 
     * @param from    Address to burn tokens from.
     * @param amount  Amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    /*************************************************************************/
    /*                              POOL FUNCTIONS                           */
    /*************************************************************************/

    /**
     * @notice  Executes a buy of tokens.
     * 
     * @dev     Throws when the caller is not the TokenMasterRouter.
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
        
        (uint96 buyCostPairedTokenNumerator, uint96 buyCostPoolTokenDenominator) = _loadBuyParameters();
        totalCost = tokensToBuy * buyCostPairedTokenNumerator / buyCostPoolTokenDenominator;

        unchecked {
            uint256 refundAmount = pairedTokenIn - totalCost;
            if (refundAmount > pairedTokenIn) {
                revert TokenMasterERC20__InsufficientBuyInput();
            }

            _mint(buyer, tokensToBuy);
            refundByRouterAmount = _transferPairedToken(buyer, refundAmount);
        }
    }

    /**
     * @notice  Selling of tokens is unsupported in PromotionalPool as there is no bonded market value.
     */
    function sellTokens(
        address /*seller*/,
        uint256 /*tokensToSell*/,
        uint256 /*pairedTokenMinimumOut*/
    ) external pure returns (address /*pairedToken*/, uint256 /*pairedValueToSeller*/, uint256 /*transferByRouterAmount*/) {
        revert TokenMasterERC20__OperationNotSupportedByPool();
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
    function setBuyParameters(PromotionalPoolBuyParameters calldata _buyParameters) external onlyOwner {
        _setBuyParameters(_buyParameters);

        emit BuyParametersUpdated();
    }

    /*************************************************************************/
    /*                             VIEW FUNCTIONS                            */
    /*************************************************************************/

    /**
     * @notice  Returns the current settings for buy orders.
     * 
     * @return _buyParameters  The current buy parameters.
     */
    function getBuyParameters() external view returns(PromotionalPoolBuyParameters memory _buyParameters) {
        _buyParameters = buyParameters;
    }

    /*************************************************************************/
    /*                           INTERNAL FUNCTIONS                          */
    /*************************************************************************/

    /**
     * @dev  Returns zero as there is no bonded market value for promotional pools.
     */
    function _bondedMarketValue() internal virtual view override returns(uint256) {
        // Bonded market value in promotional pools is always zero
        return 0;
    }

    /**
     * @dev  Validates the buy parameters being set.
     * 
     * @dev  Throws when a setting is invalid.
     * 
     * @param _buyParameters  The parameters to set for buy orders.
     */
    function _setBuyParameters(PromotionalPoolBuyParameters memory _buyParameters) internal {
        if (_buyParameters.buyCostPoolTokenDenominator == 0) {
            revert TokenMasterERC20__InvalidParameters();
        }

        buyParameters = _buyParameters;
    }

    /**
     * @dev  Loads buy parameters from storage onto stack for executing a buy.
     * 
     * @return buyCostPairedTokenNumerator  The numerator for the ratio of paired token to pool token as an additional buy fee.
     * @return buyCostPoolTokenDenominator  The denominator for the ratio of paired token to pool token as an additional buy fee.
     */
    function _loadBuyParameters() internal view returns(
        uint96 buyCostPairedTokenNumerator,
        uint96 buyCostPoolTokenDenominator
    ) {
        buyCostPairedTokenNumerator = buyParameters.buyCostPairedTokenNumerator;
        buyCostPoolTokenDenominator = buyParameters.buyCostPoolTokenDenominator;
    }

    /**
     * @dev  Extends the ERC165 interface support check with additional interfaces supported by PromotionalPool.
     * 
     * @param interfaceId The interface id
     */
    function _supportsInterfaceExtended(bytes4 interfaceId) internal virtual view override returns (bool) {
        return 
        interfaceId == type(IPromotionalPool).interfaceId ||
        interfaceId == type(IMinterBurnerRolePool).interfaceId;
    }
}
