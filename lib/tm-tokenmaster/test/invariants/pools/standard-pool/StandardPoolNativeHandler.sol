// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "../BondedPoolNativeHandler.sol";
import "src/pools/standard-token-pool/StandardPool.sol";
import "src/TokenMasterRouter.sol";
import "test/mocks/MockPairedTokenERC20.sol";

contract StandardPoolNativeHandler is BondedPoolNativeHandler {
    using LibAddressSet for AddressSet;
    using LibUint256Set for Uint256Set;

    StandardPoolInitializationParameters private myInitializationParameters;

    function initializationParameters() public view returns(StandardPoolInitializationParameters memory) {
        return myInitializationParameters;
    }

    constructor(
        TokenMasterTest _test,
        TokenMasterRouter _router, 
        BondedPool _pool,
        DeploymentParameters memory _deploymentParameters,
        StandardPoolInitializationParameters memory _initializationParameters
    ) BondedPoolNativeHandler(_test, _router, _pool, _deploymentParameters) {
        myInitializationParameters = _initializationParameters;
        ghost_mintedToRouter = 1;
        ghost_initialTokenSupply = _initializationParameters.initialSupplyAmount - 1;
    }

    function buyTokens(
        uint256 tokensToBuy, 
        uint256 pairedValueIn
    ) public virtual override createActor countCall("buyTokens") {

        (
            uint16 buySpreadBPS,
            uint16 buyFeeBPS,
            uint96 buyCostPairedTokenNumerator,
            uint96 buyCostPoolTokenDenominator,
            /*uint16 buyDemandFeeBPS*/,
            /*uint256 expectedSupply*/
        ) = _loadBuyParameters(IStandardPool(address(pool)).getBuyParameters());

        (uint256 bondedMarketValue,,,) = pool.pairedTokenShares();
        uint256 maxTokensToBuy = type(uint120).max - pool.totalSupply();
        tokensToBuy = bound(tokensToBuy, 0, maxTokensToBuy);

        if (bondedMarketValue > 0) {
            if (bondedMarketValue > type(uint256).max / BPS) return;
            tokensToBuy = bound(tokensToBuy, 0, type(uint256).max / (bondedMarketValue * BPS / (BPS - buySpreadBPS)));
        }

        uint256 marketValueShare = tokensToBuy * (bondedMarketValue * BPS / (BPS - buySpreadBPS)) / pool.totalSupply();
        uint256 maxMarketValueShare = type(uint120).max - bondedMarketValue;
        if (marketValueShare > maxMarketValueShare) {
            tokensToBuy = tokensToBuy * maxMarketValueShare / marketValueShare;
            marketValueShare = tokensToBuy * (bondedMarketValue * BPS / (BPS - buySpreadBPS)) / pool.totalSupply();
        }
        uint256 revenueShare = 
            (tokensToBuy * buyCostPairedTokenNumerator / buyCostPoolTokenDenominator) + 
            (marketValueShare * buyFeeBPS / BPS);

        uint256 totalCostPairedToken = marketValueShare + revenueShare;
        pairedValueIn = bound(pairedValueIn, totalCostPairedToken, type(uint256).max);
        uint256 expectedRefund = pairedValueIn - totalCostPairedToken;

        if (address(this).balance < pairedValueIn) {
            return;
        }

        _payNative(address(this), currentActor, pairedValueIn);
        _handleBuyTokens(currentActor, tokensToBuy, pairedValueIn);
        _payNative(currentActor, address(this), expectedRefund);

        ghost_tokensBought += tokensToBuy;
        ghost_pairedTokenIntoPool += totalCostPairedToken;
    }

    function sellTokens(
        uint256 actorSeed, 
        uint256 tokensToSell
    ) public virtual override useActor(actorSeed) countCall("sellTokens") {
        tokensToSell = bound(tokensToSell, 0, pool.balanceOf(currentActor));
        if (tokensToSell == pool.totalSupply()) {
            return;
        }

        (uint256 bondedMarketValue,,,) = pool.pairedTokenShares();
        StandardPoolSellParameters memory sellParams = IStandardPool(address(pool)).getSellParameters();
        tokensToSell = bound(tokensToSell, 0, type(uint256).max / bondedMarketValue);
        uint256 pairedTokenValue = tokensToSell * bondedMarketValue / pool.totalSupply();
        //uint256 pairedValueFromMarket = pairedTokenValue * (BPS - sellParams.sellSpreadBPS) / BPS;
        uint256 expectedSellerProceeds = pairedTokenValue * (BPS - sellParams.sellSpreadBPS - sellParams.sellFeeBPS) / BPS;

        _sellTokens(currentActor, tokensToSell);
        _payNative(currentActor, address(this), expectedSellerProceeds);
        
        ghost_tokensSold += tokensToSell;
        ghost_pairedTokenOutOfPool += expectedSellerProceeds;
    }

    function spendTokens(
        uint256 actorSeed, 
        uint256 signerSeed, 
        uint256 tokensToSpend,
        bytes32 spendId
    ) 
    public virtual override {
        tokensToSpend = bound(tokensToSpend, 0, pool.balanceOf(currentActor));
        if (tokensToSpend == pool.totalSupply()) {
            return;
        }

        /*(uint256 bondedMarketValue,,,) = pool.pairedTokenShares();
        uint16 creatorShareBPS = IStandardPool(address(pool)).getSpendParameters().creatorShareBPS;
        uint256 pairedValueFromMarket = 
            (tokensToSpend * bondedMarketValue / pool.totalSupply()) * 
            creatorShareBPS / 
            BPS;*/

        super.spendTokens(actorSeed, signerSeed, tokensToSpend, spendId);
    }

    function setBuyParameters(uint256 randomSeed) public virtual override {
        uint16 buySpreadBPS = uint16(uint256(_getRandomHash(randomSeed, 1)) % BPS);
        uint16 buyFeeBPS = uint16(uint256(_getRandomHash(randomSeed, 2)) % BPS);
        uint96 buyCostPairedTokenNumerator = uint96(uint256(_getRandomHash(randomSeed, 3)) % type(uint96).max);
        uint96 buyCostPoolTokenDenominator = uint96(uint256(_getRandomHash(randomSeed, 4)) % type(uint96).max);
        _setBuyParameters(buySpreadBPS, buyFeeBPS, buyCostPairedTokenNumerator, buyCostPoolTokenDenominator);
    }
    
    function setSellParameters(uint256 randomSeed) public virtual override {
        uint16 sellSpreadBPS = uint16(uint256(_getRandomHash(randomSeed, 1))) % BPS;
        uint16 sellFeeBPS = uint16(uint256(_getRandomHash(randomSeed, 2))) % BPS;

        if (sellSpreadBPS + sellFeeBPS > BPS) {
            sellSpreadBPS = 0;
            sellFeeBPS = 0;
        }

        _setSellParameters(sellSpreadBPS, sellFeeBPS);
    }

    function setSpendParameters(uint256 randomSeed) public virtual {
        uint16 creatorShareBPS = uint16(uint256(_getRandomHash(randomSeed, 1))) % BPS;
        _setSpendParameters(creatorShareBPS);
    }

    function _setBuyParameters(
        uint16 buySpreadBPS,
        uint16 buyFeeBPS, 
        uint96 buyCostPairedTokenNumerator, 
        uint96 buyCostPoolTokenDenominator
    ) internal {
        buySpreadBPS = uint16(bound(buySpreadBPS, myInitializationParameters.minBuySpreadBPS, myInitializationParameters.maxBuySpreadBPS));
        buyFeeBPS = uint16(bound(buyFeeBPS, 0, myInitializationParameters.maxBuyFeeBPS));
        buyCostPairedTokenNumerator = uint96(bound(buyCostPairedTokenNumerator, 0, type(uint48).max));
        buyCostPoolTokenDenominator = uint96(bound(buyCostPoolTokenDenominator, 1, type(uint48).max));
        vm.startPrank(pool.owner());
        IStandardPool(address(pool)).setBuyParameters(StandardPoolBuyParameters({
            buySpreadBPS: buySpreadBPS,
            buyFeeBPS: buyFeeBPS,
            buyCostPairedTokenNumerator: buyCostPairedTokenNumerator,
            buyCostPoolTokenDenominator: buyCostPoolTokenDenominator,
            useTargetSupply: false,
            reserved: 0,
            buyDemandFeeBPS: 0,
            targetSupplyBaseline: 0,
            targetSupplyBaselineScaleFactor: 0,
            targetSupplyGrowthRatePerSecond: 0,
            targetSupplyBaselineTimestamp: 0
        }));
        vm.stopPrank();
    }

    function _setSellParameters(uint16 sellSpreadBPS, uint16 sellFeeBPS) internal {
        sellSpreadBPS = uint16(bound(sellSpreadBPS, myInitializationParameters.minSellSpreadBPS, myInitializationParameters.maxSellSpreadBPS));
        sellFeeBPS = uint16(bound(sellFeeBPS, 0, myInitializationParameters.maxSellFeeBPS));
        vm.startPrank(pool.owner());
        IStandardPool(address(pool)).setSellParameters(StandardPoolSellParameters({
            sellSpreadBPS: sellSpreadBPS,
            sellFeeBPS: sellFeeBPS
        }));
        vm.stopPrank();
    }

    function _setSpendParameters(uint16 creatorShareBPS) internal {
        creatorShareBPS = uint16(bound(creatorShareBPS, 0, myInitializationParameters.maxSpendCreatorShareBPS));
        vm.startPrank(pool.owner());
        IStandardPool(address(pool)).setSpendParameters(StandardPoolSpendParameters({
            creatorShareBPS: creatorShareBPS
        }));
        vm.stopPrank();
    }

    function _loadBuyParameters(StandardPoolBuyParameters memory buyParameters) internal view returns(
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
}