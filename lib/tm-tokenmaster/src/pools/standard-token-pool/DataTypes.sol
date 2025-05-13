//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @dev This struct defines parameters used for standard pool initialization.
 * 
 * @dev **initialSupplyRecipient**: Address to receive the initial supply amount.
 * @dev **initialSupplyAmount**: Initial amount of supply to mint to the initial supply recipient.
 * @dev **minBuySpreadBPS**: Immutable minimum spread rate in BPS for buys.
 * @dev **maxBuySpreadBPS**: Immutable maximum spread rate in BPS for buys.
 * @dev **maxBuyFeeBPS**: Immutable maximum buy fee rate in BPS that may be set by the creator.
 * @dev **maxBuyDemandFeeBPS**: Immutable maximum buy demand fee rate in BPS that may be set by the creator.
 * @dev **maxSellFeeBPS**: Immutable maximum sell fee rate in BPS that may be set by the creator.
 * @dev **maxSpendCreatorShareBPS**: Immutable maximum creator share rate in BPS that may be set by the creator.
 * @dev **creatorEmissionRateNumerator**: Immutable numerator for the rate in tokens per second that a creator earns emissions.
 * @dev **creatorEmissionRateDenominator**: Immutable denominator for the rate in tokens per second that a creator earns emissions.
 * @dev **creatorEmissionsHardCap**: Initial value for the hard cap of total emissions that a creator may claim over time.
 * @dev **initialBuyParameters**: Initial settings for buy parameters.
 * @dev **initialSellParameters**: Initial settings for sell parameters.
 * @dev **initialSpendParameters**: Initial settings for spend parameters.
 * @dev **initialPausedState**: Initial paused state for pausable functions.
 */
struct StandardPoolInitializationParameters {
    address initialSupplyRecipient;
    uint256 initialSupplyAmount;
    uint256 minBuySpreadBPS; 
    uint256 maxBuySpreadBPS; 
    uint256 maxBuyFeeBPS;
    uint256 maxBuyDemandFeeBPS; 
    uint256 minSellSpreadBPS; 
    uint256 maxSellSpreadBPS; 
    uint256 maxSellFeeBPS;
    uint256 maxSpendCreatorShareBPS;
    uint256 creatorEmissionRateNumerator;
    uint256 creatorEmissionRateDenominator;
    uint256 creatorEmissionsHardCap;
    StandardPoolBuyParameters initialBuyParameters;
    StandardPoolSellParameters initialSellParameters;
    StandardPoolSpendParameters initialSpendParameters;
    uint256 initialPausedState;
}

/**
 * @dev This struct defines parameters used for buys.
 * 
 * @dev **buySpreadBPS**: Spread rate in BPS for the cost of tokens above the current market value.
 * @dev **buyFeeBPS**: Fee rate in BPS for the fee applied to buys.
 * @dev **buyCostPairedTokenNumerator**: The numerator for the ratio of paired token to pool token that will be added as a fee on top of buys.
 * @dev **buyCostPoolTokenDenominator**: The denominator for the ratio of paired token to pool token that will be added as a fee on top of buys.
 * @dev **useTargetSupply**: True if the pool uses a target supply for determining the application of demand fees.
 * @dev **reserved**: Unused.
 * @dev **buyDemandFeeBPS**: Rate in BPS of the amount of demand fee that is allocated to the creator.
 * @dev **targetSupplyBaseline**: Baseline supply amount for determining if a buy will exceed the target supply.
 * @dev **targetSupplyBaselineScaleFactor**: Scale factor for the baseline supply. Stored as a separate value to optimize storage.
 * @dev Actual Supply Baseline = targetSupplyBaseline * 10^targetSupplyBaselineScaleFactor
 * @dev **targetSupplyGrowthRatePerSecond**: Rate in tokens per second that the target supply grows when calculating expected supply.
 * @dev **targetSupplyBaselineTimestamp**: Unix timestamp for the time when target supply growth rate per second starts accumulating.
 * @dev When the current block timestamp is less than targetSupplyBaselineTimestamp:
 * @dev   Expected Supply = Actual Supply Baseline.
 * @dev When the current block timestamp is greater than targetSupplyBaselineTimestamp:
 * @dev   Expected Supply = Actual Supply Baseline + targetSupplyGrowthRatePerSecond * (block.timestamp - targetSupplyBaselineTimestamp)
 */
struct StandardPoolBuyParameters {
    uint16 buySpreadBPS;
    uint16 buyFeeBPS;
    uint96 buyCostPairedTokenNumerator;
    uint96 buyCostPoolTokenDenominator;
    bool useTargetSupply;
    uint24 reserved;
    uint16 buyDemandFeeBPS;
    uint48 targetSupplyBaseline;
    uint8 targetSupplyBaselineScaleFactor;
    uint96 targetSupplyGrowthRatePerSecond;
    uint48 targetSupplyBaselineTimestamp;
}

/**
 * @dev This struct defines parameters used for sells.
 * 
 * @dev **sellSpreadBPS**: Spread rate in BPS to adjust value of tokens being sold below market value.
 * @dev **sellFeeBPS**: Sell fee rate in BPS that will be subtracted from a sell order.
 */
struct StandardPoolSellParameters {
    uint16 sellSpreadBPS;
    uint16 sellFeeBPS;
}

/**
 * @dev This struct defines parameters used for spends.
 * 
 * @dev **creatorShareBPS**: Rate in BPS of the value of tokens that will be allocated to the creator when tokens are spent.
 * @dev Any value not allocated to the creator remains in the market value of tokens and increases the 
 * @dev market value of all remaining tokens.
 */
struct StandardPoolSpendParameters {
    uint16 creatorShareBPS;
}