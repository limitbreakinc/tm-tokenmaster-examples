//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @dev This struct defines parameters used for stable pool initialization.
 * 
 * @dev **initialSupplyRecipient**: Address to receive the initial supply amount.
 * @dev **initialSupplyAmount**: Initial amount of supply to mint to the initial supply recipient.
 * @dev **maxBuyFeeBPS**: Immutable maximum buy fee rate in BPS that may be set by the creator.
 * @dev **maxSellFeeBPS**: Immutable maximum sell fee rate in BPS that may be set by the creator.
 * @dev **initialBuyParameters**: Initial settings for buy parameters.
 * @dev **initialSellParameters**: Initial settings for sell parameters.
 * @dev **stablePairedPricePerToken**: Immutable ratio of paired token to pool token for stable pricing.
 */
struct StablePoolInitializationParameters {
    address initialSupplyRecipient;
    uint256 initialSupplyAmount;
    uint256 maxBuyFeeBPS;
    uint256 maxSellFeeBPS;
    StablePoolBuyParameters initialBuyParameters;
    StablePoolSellParameters initialSellParameters;
    PairedPricePerToken stablePairedPricePerToken;
}

/**
 * @dev This struct defines parameters used for stable pool buys.
 * 
 * @dev **buyFeeBPS**: Buy fee rate in BPS that will be applied to a buy order.
 */
struct StablePoolBuyParameters {
    uint16 buyFeeBPS;
}

/**
 * @dev This struct defines parameters used for stable pool sells.
 * 
 * @dev **sellFeeBPS**: Sell fee rate in BPS that will be subtracted from a sell order.
 */
struct StablePoolSellParameters {
    uint16 sellFeeBPS;
}

/**
 * @dev This struct defines parameters used for initializing a stable pool's price.
 * 
 * @dev **numerator**: The numerator for the ratio of paired token to pool token that will be the stable price of a token before fees.
 * @dev **denominator**: The denominator for the ratio of paired token to pool token that will be the stable price of a token before fees.
 */
struct PairedPricePerToken {
    uint96 numerator;
    uint96 denominator;
}