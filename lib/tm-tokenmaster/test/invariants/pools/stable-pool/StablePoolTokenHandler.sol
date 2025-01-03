// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "../BondedPoolTokenHandler.sol";
import "src/pools/stable-pool/StablePool.sol";
import "src/TokenMasterRouter.sol";
import "test/mocks/MockPairedTokenERC20.sol";

contract StablePoolTokenHandler is BondedPoolTokenHandler {
    using LibAddressSet for AddressSet;
    using LibUint256Set for Uint256Set;

    StablePoolInitializationParameters public initializationParameters;

    constructor(
        TokenMasterTest _test,
        TokenMasterRouter _router, 
        BondedPool _pool,
        DeploymentParameters memory _deploymentParameters,
        StablePoolInitializationParameters memory _initializationParameters
    ) BondedPoolTokenHandler(_test, _router, _pool, _deploymentParameters) {
        initializationParameters = _initializationParameters;
        ghost_initialTokenSupply = _initializationParameters.initialSupplyAmount;
    }

    function buyTokens(
        uint256 tokensToBuy, 
        uint256 pairedValueIn
    ) public virtual override createActor countCall("buyTokens") {
        tokensToBuy = bound(tokensToBuy, 0, type(uint128).max);

        uint128 priceNumerator = initializationParameters.stablePairedPricePerToken.numerator;
        uint128 priceDenominator = initializationParameters.stablePairedPricePerToken.denominator;
        
        StablePoolBuyParameters memory buyParameters = IStablePool(address(pool)).getBuyParameters();
        uint16 buyFeeBPS = buyParameters.buyFeeBPS;

        uint256 marketValueShare = tokensToBuy * priceNumerator / priceDenominator;
        uint256 revenueShare = 
            (marketValueShare * buyFeeBPS / BPS);

        uint256 totalCostPairedToken = marketValueShare + revenueShare;
        pairedValueIn = bound(pairedValueIn, totalCostPairedToken, type(uint256).max);
        uint256 expectedRefund = pairedValueIn - totalCostPairedToken;

        if (MockPairedTokenERC20(pool.PAIRED_TOKEN()).balanceOf(address(this)) < pairedValueIn) {
            return;
        }

        _payToken(address(this), pool.PAIRED_TOKEN(), currentActor, pairedValueIn);
        _handleBuyTokens(currentActor, tokensToBuy, pairedValueIn);
        _payToken(currentActor, pool.PAIRED_TOKEN(), address(this), expectedRefund);

        ghost_tokensBought += tokensToBuy;
        ghost_pairedTokenIntoPool += totalCostPairedToken;
    }

    function sellTokens(
        uint256 actorSeed, 
        uint256 tokensToSell
    ) public virtual override useActor(actorSeed) countCall("sellTokens") {
        tokensToSell = bound(tokensToSell, 0, pool.balanceOf(currentActor));

        uint128 priceNumerator = initializationParameters.stablePairedPricePerToken.numerator;
        uint128 priceDenominator = initializationParameters.stablePairedPricePerToken.denominator;
        
        uint256 expectedSellerProceeds = 
            (tokensToSell * priceNumerator / priceDenominator) * 
            (BPS - IStablePool(address(pool)).getSellParameters().sellFeeBPS) / BPS;

        _sellTokens(currentActor, tokensToSell);
        _payToken(currentActor, pool.PAIRED_TOKEN(), address(this), expectedSellerProceeds);
        
        ghost_tokensSold += tokensToSell;
        ghost_pairedTokenOutOfPool += expectedSellerProceeds;
    }

    function setBuyParameters(uint256 randomSeed) public virtual override {
        uint16 buyFeeBPS = uint16(uint256(_getRandomHash(randomSeed, 1)) % BPS);
        _setBuyParameters(buyFeeBPS);
    }
    
    function setSellParameters(uint256 randomSeed) public virtual override {
        uint16 sellFeeBPS = uint16(uint256(_getRandomHash(randomSeed, 1))) % BPS;
        _setSellParameters(sellFeeBPS);
    }

    function _setBuyParameters(
        uint16 buyFeeBPS
    ) internal {
        buyFeeBPS = uint16(bound(buyFeeBPS, 0, BPS));
        vm.startPrank(pool.owner());
        IStablePool(address(pool)).setBuyParameters(StablePoolBuyParameters({
            buyFeeBPS: buyFeeBPS
        }));
        vm.stopPrank();
    }

    function _setSellParameters(uint16 sellFeeBPS) internal {
        sellFeeBPS = uint16(bound(sellFeeBPS, 0, BPS));
        vm.startPrank(pool.owner());
        IStablePool(address(pool)).setSellParameters(StablePoolSellParameters({
            sellFeeBPS: sellFeeBPS
        }));
        vm.stopPrank();
    }
}