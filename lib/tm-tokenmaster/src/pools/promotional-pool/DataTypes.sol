//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @dev This struct defines parameters used for promotional pool initialization.
 * 
 * @dev **initialSupplyRecipient**: Address to receive the initial supply amount.
 * @dev **initialSupplyAmount**: Initial amount of supply to mint to the initial supply recipient.
 * @dev **initialBuyParameters**: Initial settings for buy parameters.
 */
struct PromotionalPoolInitializationParameters {
    address initialSupplyRecipient;
    uint256 initialSupplyAmount;
    PromotionalPoolBuyParameters initialBuyParameters;
}

/**
 * @dev This struct defines parameters used for promotional pool buys.
 * 
 * @dev **buyCostPairedTokenNumerator**: The numerator for the ratio of paired token to pooled tokens when buying.
 * @dev **buyCostPoolTokenDenominator**: The denominator for the ratio of paired token to pooled tokens when buying.
 */
struct PromotionalPoolBuyParameters {
    uint96 buyCostPairedTokenNumerator;
    uint96 buyCostPoolTokenDenominator;
}