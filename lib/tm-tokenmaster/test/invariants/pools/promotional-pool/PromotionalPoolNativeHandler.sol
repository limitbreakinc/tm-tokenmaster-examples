// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "../BondedPoolNativeHandler.sol";
import "src/pools/promotional-pool/PromotionalPool.sol";
import "src/TokenMasterRouter.sol";
import "test/mocks/MockPairedTokenERC20.sol";

contract PromotionalPoolNativeHandler is BondedPoolNativeHandler {
    using LibAddressSet for AddressSet;
    using LibUint256Set for Uint256Set;

    PromotionalPoolInitializationParameters public initializationParameters;

    constructor(
        TokenMasterTest _test,
        TokenMasterRouter _router, 
        BondedPool _pool,
        DeploymentParameters memory _deploymentParameters,
        PromotionalPoolInitializationParameters memory _initializationParameters
    ) BondedPoolNativeHandler(_test, _router, _pool, _deploymentParameters) {
        initializationParameters = _initializationParameters;
        ghost_initialTokenSupply = _initializationParameters.initialSupplyAmount;
    }

    function buyTokens(
        uint256 tokensToBuy, 
        uint256 pairedValueIn
    ) public virtual override createActor countCall("buyTokens") {
        tokensToBuy = bound(tokensToBuy, 0, type(uint128).max);
        
        PromotionalPoolBuyParameters memory buyParameters = IPromotionalPool(address(pool)).getBuyParameters();
        uint96 buyCostPairedTokenNumerator = buyParameters.buyCostPairedTokenNumerator;
        uint96 buyCostPoolTokenDenominator = buyParameters.buyCostPoolTokenDenominator;

        uint256 marketValueShare = 0;
        uint256 revenueShare = tokensToBuy * buyCostPairedTokenNumerator / buyCostPoolTokenDenominator;

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
        uint256 /*tokensToSell*/
    ) public virtual override useActor(actorSeed) countCall("sellTokens") {
        return;
    }

    function setBuyParameters(uint256 randomSeed) public virtual override {
        uint96 buyCostPairedTokenNumerator = uint96(uint256(_getRandomHash(randomSeed, 1)) % type(uint96).max);
        uint96 buyCostPoolTokenDenominator = uint96(uint256(_getRandomHash(randomSeed, 2)) % type(uint96).max);
        _setBuyParameters(buyCostPairedTokenNumerator, buyCostPoolTokenDenominator);
    }
    
    function setSellParameters(uint256 /*randomSeed*/) public virtual override {
        return;
    }

    function _setBuyParameters(
        uint96 buyCostPairedTokenNumerator, 
        uint96 buyCostPoolTokenDenominator
    ) internal {
        buyCostPairedTokenNumerator = uint96(bound(buyCostPairedTokenNumerator, 0, type(uint96).max));
        buyCostPoolTokenDenominator = uint96(bound(buyCostPoolTokenDenominator, 1, type(uint96).max));
        vm.startPrank(pool.owner());
        IPromotionalPool(address(pool)).setBuyParameters(PromotionalPoolBuyParameters({
            buyCostPairedTokenNumerator: buyCostPairedTokenNumerator,
            buyCostPoolTokenDenominator: buyCostPoolTokenDenominator
        }));
        vm.stopPrank();
    }
}