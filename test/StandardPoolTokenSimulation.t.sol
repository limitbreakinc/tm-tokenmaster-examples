// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "@limitbreak/tokenmaster/test/TokenMasterToken.t.sol";
import {StandardPool} from "@limitbreak/tokenmaster/src/pools/standard-token-pool/StandardPool.sol";
import {IStandardPool} from "@limitbreak/tokenmaster/src/pools/standard-token-pool/IStandardPool.sol";
import "@limitbreak/tokenmaster/src/pools/standard-token-pool/DataTypes.sol";
import "@limitbreak/tm-core-lib/src/utils/access/Ownable.sol";
import "@limitbreak/tokenmaster/test/mocks/MockPairedTokenERC20.sol";
import "./helpers/Random.sol";
import "./helpers/AddressSet.sol";


contract StandardPoolTokenSimulationTest is TokenMasterTokenTest {
    using LibAddressSet for AddressSet;
    
    AddressSet internal _allUsers;
    AddressSet internal _buyers;

    function setUp() public virtual override {
        super.setUp();
    }
    
    uint16 constant BUY_FEE_BPS = 10;
    uint16 constant SELL_FEE_BPS = 10;
    uint16 constant BUY_SPREAD_BPS = 15;
    uint16 constant SELL_SPREAD_BPS = 25;
    uint16 constant CREATOR_SHARE_BPS = 8000;
    uint256 constant TOKENS_TO_SPEND = 1_000_000 ether;

    function deal100PairedToUser(address user) external {
        _dealPaired(user, 500_000 ether);
    }

    struct Tracker 
    {
        address earlyBuyer;
        uint256 earlyBuyerCostBasis;
        uint256 earlyBuyerSaleProceeds;
        uint256 startingTotalSupply;
        uint256 startingMarketShare;
        uint256 endingTotalSupply;
        uint256 endingMarketShare;
        uint256 totalTokensBought;
        uint256 totalTokensSold;
        uint256 totalTokensSpent;
        uint256 totalPairedTokenInFromBuys;
        uint256 totalPairedTokenOutFromSells;
    }

    function testSimulateMarketValue() public {
        uint160 deployerKey = uint160(0x4444);
        address deployer = vm.addr(deployerKey);

        Tracker memory tracker = Tracker({
            earlyBuyer: address(0),
            earlyBuyerCostBasis: 0,
            earlyBuyerSaleProceeds: 0,
            startingTotalSupply: 0,
            startingMarketShare: 0,
            endingTotalSupply: 0,
            endingMarketShare: 0,
            totalTokensBought: 0,
            totalTokensSold: 0,
            totalTokensSpent: 0,
            totalPairedTokenInFromBuys: 0,
            totalPairedTokenOutFromSells: 0
        });

        vm.startPrank(TOKENMASTER_ADMIN);
        tokenMasterRouter.setInfrastructureFee(0);
        vm.stopPrank();

        Random rand = new Random(vm.unixTime());

        StandardPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();

        initializationParams.initialSupplyAmount = 1 ether;
        initializationParams.minBuySpreadBPS = 0;
        initializationParams.maxBuySpreadBPS = 99_99;
        initializationParams.maxBuyFeeBPS = 10_000;
        initializationParams.maxBuyDemandFeeBPS = 10_000;
        initializationParams.minSellSpreadBPS = 0;
        initializationParams.maxSellSpreadBPS = 99_99;
        initializationParams.maxSellFeeBPS = 10_000;
        initializationParams.maxSpendCreatorShareBPS = 10_000;
        initializationParams.creatorEmissionRateNumerator = 0;
        initializationParams.creatorEmissionRateDenominator = 1;
        initializationParams.creatorEmissionsHardCap = 0;

        initializationParams.initialBuyParameters.buySpreadBPS = BUY_SPREAD_BPS;
        initializationParams.initialBuyParameters.buyFeeBPS = BUY_FEE_BPS;
        initializationParams.initialBuyParameters.buyCostPairedTokenNumerator = 0;
        initializationParams.initialBuyParameters.buyCostPoolTokenDenominator = 1;
        initializationParams.initialBuyParameters.buyDemandFeeBPS = 0;
        
        initializationParams.initialSellParameters.sellSpreadBPS = SELL_SPREAD_BPS;
        initializationParams.initialSellParameters.sellFeeBPS = SELL_FEE_BPS;

        initializationParams.initialSpendParameters.creatorShareBPS = CREATOR_SHARE_BPS;

        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.maxInfrastructureFeeBPS = 10_000;
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 0.000001 ether;

        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        vm.startPrank(deployer);
        tokenMasterRouter.setOrderSigner(tokenAddress,  vm.addr(uint160(0x5555)), true);
        vm.stopPrank();

        StandardPool pool = StandardPool(tokenAddress);

        (
            uint256 marketShare,
            uint256 creatorShare,,
        ) = pool.pairedTokenShares();

        tracker.startingTotalSupply = pool.totalSupply();
        tracker.startingMarketShare = marketShare;

        _logDivision("Pool Per Paired (Begin)", pool.totalSupply(), marketShare);
        _logDivision("Creator Share (Begin)", creatorShare, 1 ether);

        _createRandomUsers(rand, 500, 2000);
        _allUsers.forEach(this.deal100PairedToUser);

        _doEarlyBuy(tracker, pool, rand);

        for (uint256 i = 0; i < 5000; i++)
        {
            address buyer = _allUsers.rand(rand.getNext(0, type(uint256).max));
            _buyers.add(buyer);
            uint256 tokensToBuy = rand.getNext(1_000 ether, 5_000_000 ether);
            uint256 pairedTokenBalanceBefore = buyer.balance;
            _buyTokens(0, buyer, pool, tokensToBuy, buyer.balance, buyer.balance, block.timestamp, NO_ERROR);
            tracker.totalTokensBought += tokensToBuy;
            tracker.totalPairedTokenInFromBuys += pairedTokenBalanceBefore - buyer.balance;
        }

        for (uint256 i = 0; i < 10000; i++)
        {
            if (i % 2 == 0) {
                // Sells on event iterations
                address seller = _buyers.rand(rand.getNext(0, type(uint256).max));
                uint256 sellerBalance = pool.balanceOf(seller);
                uint256 tokensToSell = rand.getNext(sellerBalance / 10, sellerBalance * 3 / 4);
                uint256 pairedTokenBalanceBefore = seller.balance;
                _sellTokens(0, seller, pool, tokensToSell, 0 ether, NO_ERROR);
                tracker.totalTokensSold += tokensToSell;
                tracker.totalPairedTokenOutFromSells += seller.balance - pairedTokenBalanceBefore;
            } else {
                // Spends on odd iterations
                address spender = _buyers.rand(rand.getNext(0, type(uint256).max));
                uint256 spenderBalance = pool.balanceOf(spender);
                if (spenderBalance < TOKENS_TO_SPEND) continue;
                tracker.totalTokensSpent += TOKENS_TO_SPEND;

                SpendOrder memory spendOrder;
                SignedOrder memory signedOrder;
                signedOrder.creatorIdentifier = bytes32(rand.getNext(1, type(uint256).max));
                spendOrder.multiplier = 1;
                spendOrder.maxAmountToSpend = TOKENS_TO_SPEND;
                spendOrder.tokenMasterToken = address(pool);
                signedOrder.tokenMasterOracle = address(0);
                signedOrder.baseToken = address(0);
                signedOrder.baseValue = TOKENS_TO_SPEND;
                signedOrder.maxPerWallet = type(uint256).max;
                signedOrder.maxTotal = type(uint256).max;
                signedOrder.expiration = type(uint256).max;
                signedOrder.hook = address(0);
                signedOrder.signature = SignatureECDSA({
                    v: 0,
                    r: 0,
                    s: 0
                });
                signedOrder.cosignature = Cosignature({
                    signer: address(0),
                    expiration: 0,
                    v: 0,
                    r: 0,
                    s: 0
                });

                (
                    SignatureECDSA memory signedSpendOrder, 
                    /*bytes32 spendOrderHash*/
                ) = getSignedSpendOrderAndDigest( uint160(0x5555), spendOrder, signedOrder);
        
                signedOrder.signature = signedSpendOrder;
        
                vm.startPrank(spender);
                tokenMasterRouter.spendTokens(spendOrder, signedOrder);
                vm.stopPrank();
            }
        }

        _doFinalSale(tracker, pool);

        (
            marketShare,
            creatorShare,,
        ) = pool.pairedTokenShares();

        tracker.endingMarketShare = marketShare;
        tracker.endingTotalSupply = pool.totalSupply();

        _logDivision("Total Tokens Bought", tracker.totalTokensBought, 1 ether);
        _logDivision("Total Tokens Sold", tracker.totalTokensSold, 1 ether);
        _logDivision("Total Tokens Spent", tracker.totalTokensSpent, 1 ether);
        _logDivision("Net Tokens", tracker.totalTokensBought - (tracker.totalTokensSold + tracker.totalTokensSpent), 1 ether);
        _logDivision("Final Supply", pool.totalSupply(), 1 ether);
        _logDivision("Total Buy/Sell Volume (Pooled Token)", tracker.totalTokensBought + tracker.totalTokensSold, 1 ether);
        _logDivision("Total Buy/Sell Volume (Paired Token)", tracker.totalPairedTokenInFromBuys + tracker.totalPairedTokenOutFromSells, 1 ether);
        _logDivision("Total Paired Token In From Buys", tracker.totalPairedTokenInFromBuys, 1 ether);
        _logDivision("Total Paired Token Out From Sells", tracker.totalPairedTokenOutFromSells, 1 ether);
        _logDivision("Pool Per Paired (End)", pool.totalSupply(), marketShare);
        _logDivision("Creator Share (End)", creatorShare, 1 ether);

        _logDivisionPercentage("Market value appreciation (percentage)", 1_000_000 ether * tracker.endingMarketShare / tracker.endingTotalSupply, (1 ether / 100));
        _printProfitAndLossOfEarlyBuyer(tracker);

        //assertTrue(false);
    }

    function _doEarlyBuy(Tracker memory tracker, StandardPool pool, Random rand) private {
        tracker.earlyBuyer = vm.addr(uint160(rand.getNext(5000, 6000)));
        _dealPaired(tracker.earlyBuyer, 500_000 ether);
        uint256 earlyBuyerStartingBalance = tracker.earlyBuyer.balance;
        console.log("Early Buyer Buying 10,000,000 tokens");
        logDecimals("Early Buyer Balance Before Buy", earlyBuyerStartingBalance, 18);
        _buyTokens(0, tracker.earlyBuyer, pool, 10_000_000 ether, tracker.earlyBuyer.balance, tracker.earlyBuyer.balance, block.timestamp, NO_ERROR);
        logDecimals("Early Buyer Balance After Buy", tracker.earlyBuyer.balance, 18);
        logDecimals("Early Buyer Cost Basis", earlyBuyerStartingBalance - tracker.earlyBuyer.balance, 18);
        tracker.earlyBuyerCostBasis = earlyBuyerStartingBalance - tracker.earlyBuyer.balance;
        tracker.totalTokensBought += 10_000_000 ether;
        tracker.totalPairedTokenInFromBuys += tracker.earlyBuyerCostBasis;
    }

    function _doFinalSale(Tracker memory tracker, StandardPool pool) private {
        tracker.totalTokensSold += 10_000_000 ether;
        uint256 balanceBeforeSale = tracker.earlyBuyer.balance;
        console.log("Early Buyer Selling 10,000,000 tokens");
        logDecimals("Early Buyer Balance Before Sale", balanceBeforeSale, 18);
        _sellTokens(0, tracker.earlyBuyer, pool, 10_000_000 ether, 0 ether, NO_ERROR);
        logDecimals("Early Buyer Balance After Sale", tracker.earlyBuyer.balance, 18);
        logDecimals("Early Buyer Sale Proceeds", tracker.earlyBuyer.balance - balanceBeforeSale, 18);
        tracker.earlyBuyerSaleProceeds = tracker.earlyBuyer.balance - balanceBeforeSale;
        tracker.totalPairedTokenOutFromSells += tracker.earlyBuyerSaleProceeds;
    }

    function _printProfitAndLossOfEarlyBuyer(Tracker memory tracker) private {
        _logDivision("Early Buyer Cost Basis", tracker.earlyBuyerCostBasis, 1 ether);
        _logDivision("Early Buyer Sale Proceeds", tracker.earlyBuyerSaleProceeds, 1 ether);

        if (tracker.earlyBuyerSaleProceeds > tracker.earlyBuyerCostBasis) {
            _logDivision("Early Buyer Profit", tracker.earlyBuyerSaleProceeds - tracker.earlyBuyerCostBasis, 1 ether);
            _logDivisionPercentage("Early Buyer ROI (percentage)", 1_000_000 ether * (tracker.earlyBuyerSaleProceeds - tracker.earlyBuyerCostBasis) / tracker.earlyBuyerCostBasis, 1_000_000 ether / 100);
        } else {
            _logDivision("Early Buyer Loss", tracker.earlyBuyerCostBasis - tracker.earlyBuyerSaleProceeds, 1 ether);
        }
    }

    function _createRandomUsers(Random rand, uint256 min, uint256 max) private {
        uint256 userCount = rand.getNext(min, max);
        for (uint256 i = 0; i < userCount; i++) {
            _allUsers.add(vm.addr((uint160(rand.getNext(type(uint16).max, type(uint160).max)))));
        }
        console.log("Created %s users", userCount);
    }

    function _logDivision(string memory message, uint256 numerator, uint256 denominator) private {
        // Scale numerator for precision
        uint256 scaledNumerator = numerator * 1e18; // Adjust precision by 18 decimals
        uint256 result = scaledNumerator / denominator;
    
        logDecimals(message, result, 18);
    }

    function _logDivisionPercentage(string memory message, uint256 numerator, uint256 denominator) private {
        // Scale numerator for precision
        uint256 scaledNumerator = numerator * 1e18; // Adjust precision by 18 decimals
        uint256 result = scaledNumerator / denominator;
        if (result >= 100 ether) {
            result -= 100 ether;
        }

        logDecimals(message, result, 18);
    }

    function logDecimals(string memory message, uint256 value, uint256 decimals) internal pure {
        uint256 whole = value / (10 ** decimals);
        uint256 decimal = value % (10 ** decimals);
        message = string(bytes.concat(bytes(message), ": %s."));
        for (uint256 i = 1; i < decimals; ++i) {
            if (decimal < 10 ** i) message = string(bytes.concat(bytes(message), "0"));
        }
        message = string(bytes.concat(bytes(message), "%s"));
        console.log(message, whole, decimal);
    }

    function _defaultInitializationParameters() internal view returns (StandardPoolInitializationParameters memory initializationParams) {
        initializationParams.initialSupplyRecipient = address(this);
        initializationParams.initialSupplyAmount = 100 ether;
        initializationParams.minBuySpreadBPS = 100;
        initializationParams.maxBuySpreadBPS = 200;
        initializationParams.maxBuyFeeBPS = 300;
        initializationParams.maxBuyDemandFeeBPS = 10_000;
        initializationParams.minSellSpreadBPS = 150;
        initializationParams.maxSellSpreadBPS = 250;
        initializationParams.maxSellFeeBPS = 350;
        initializationParams.maxSpendCreatorShareBPS = 10_000;
        initializationParams.creatorEmissionRateNumerator = 1 ether;
        initializationParams.creatorEmissionRateDenominator = 1;
        initializationParams.creatorEmissionsHardCap = 50_000 ether;
        initializationParams.initialBuyParameters = StandardPoolBuyParameters({
            buySpreadBPS: 125,
            buyFeeBPS: 225,
            buyCostPairedTokenNumerator: 1,
            buyCostPoolTokenDenominator: 1000,
            useTargetSupply: false,
            reserved: 0,
            buyDemandFeeBPS: 325,
            targetSupplyBaseline: 0,
            targetSupplyBaselineScaleFactor: 0,
            targetSupplyGrowthRatePerSecond: 0,
            targetSupplyBaselineTimestamp: 0
        });
        initializationParams.initialSellParameters = StandardPoolSellParameters({
            sellSpreadBPS: 175,
            sellFeeBPS: 275
        });
        initializationParams.initialSpendParameters = StandardPoolSpendParameters({
            creatorShareBPS: 9975
        });
        initializationParams.initialPausedState = 0;
    }

    function _defaultDeploymentParameters(
        address initialOwner,
        StandardPoolInitializationParameters memory initializationParams
    ) internal view virtual returns (DeploymentParameters memory deploymentParameters) {
        bytes memory args = abi.encode(initializationParams);

        deploymentParameters.tokenFactory = address(standardPoolFactory);
        deploymentParameters.tokenSalt = bytes32(0);
        deploymentParameters.blockTransactionsFromUntrustedChannels = false;
        deploymentParameters.restrictPairingToLists = false;
        deploymentParameters.maxInfrastructureFeeBPS = 175;
        deploymentParameters.poolParams = PoolDeploymentParameters({
            name: "Test",
            symbol: "T",
            tokenDecimals: 18,
            initialOwner: initialOwner,
            pairedToken: address(0),
            initialPairedTokenToDeposit: 1 ether,
            encodedInitializationArgs: args,
            defaultTransferValidator: address(transferValidator),
            useRouterForPairedTransfers: false,
            partnerFeeRecipient: address(0),
            partnerFeeBPS: 0
        });
    }

    function _deployToken(
        address deployer,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal virtual returns (address tokenAddress) {
        uint256 msgValue;
        if (deploymentParameters.poolParams.pairedToken == address(0)) {
            msgValue = deploymentParameters.poolParams.initialPairedTokenToDeposit;
        }
        return _executeDeployToken(deployer, msgValue, deploymentParameters, signature, errorSelector);
    }

    function _deployTokenOverrideValue(
        address deployer,
        uint256 msgValue,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal virtual returns (address tokenAddress) {
        return _executeDeployToken(deployer, msgValue, deploymentParameters, signature, errorSelector);
    }

    struct BuyTmps {
        uint256 buyerKey;
        address buyer;
        StandardPool pool;
        uint256 tokensToBuy;
        uint256 pairedValueIn;
        uint256 msgValue;
        bytes4 errorSelector;
        bool expectRevert;
        uint256 marketShareBefore;
        uint256 revenueShareBefore;
        uint256 buyerBalanceBefore;
        uint256 buyerTokenBalanceBefore;
        uint256 buyDemandFeeBPS;
        uint256 expectedSupply;
        uint256 startTokenSupply;
    }
    function _buyTokens(
        uint256 buyerKey,
        address buyer,
        StandardPool pool,
        uint256 tokensToBuy, 
        uint256 pairedValueIn,
        uint256 msgValue,
        uint256 timestamp,
        bytes4 errorSelector
    ) internal {
        BuyTmps memory buyTmps;
        buyTmps.buyerKey = buyerKey;
        buyTmps.buyer = buyer;
        buyTmps.pool = pool;
        buyTmps.tokensToBuy = tokensToBuy;
        buyTmps.pairedValueIn = pairedValueIn;
        buyTmps.msgValue = msgValue;
        buyTmps.errorSelector = errorSelector;

        (
            uint16 buySpreadBPS,
            uint16 buyFeeBPS,
            uint96 buyCostPairedTokenNumerator,
            uint96 buyCostPoolTokenDenominator,
            uint16 buyDemandFeeBPS,
            uint256 expectedSupply
        ) = _loadBuyParameters(IStandardPool(address(pool)).getBuyParameters(), timestamp);

        buyTmps.buyDemandFeeBPS = buyDemandFeeBPS;
        buyTmps.expectedSupply = expectedSupply;
        buyTmps.startTokenSupply = buyTmps.pool.totalSupply();

        {
            uint256 marketShare;
            uint256 creatorShare;
            uint256 infrastructureShare;
            uint256 partnerShare;
            (
                marketShare,
                creatorShare,
                infrastructureShare,
                partnerShare
            ) = buyTmps.pool.pairedTokenShares();
            buyTmps.marketShareBefore = marketShare;
            buyTmps.revenueShareBefore = creatorShare + infrastructureShare + partnerShare;
        }

        buyTmps.expectRevert = errorSelector != NO_ERROR;

        if (buyTmps.marketShareBefore > 0) {
            if (buyTmps.marketShareBefore > type(uint256).max / BPS) {
                buyTmps.expectRevert = true;
            }
        }

        uint256 marketValueShare = buyTmps.tokensToBuy * (buyTmps.marketShareBefore * BPS / (BPS - buySpreadBPS)) / buyTmps.startTokenSupply;
        uint256 revenueShare = 
            (buyTmps.tokensToBuy * buyCostPairedTokenNumerator / buyCostPoolTokenDenominator) + 
            (marketValueShare * buyFeeBPS / BPS);
        if (buyTmps.expectedSupply > 0) {
            uint256 adjustedSupply = buyTmps.startTokenSupply + buyTmps.tokensToBuy;
            if (buyTmps.expectedSupply < adjustedSupply) {
                uint256 demandFee = buyTmps.tokensToBuy * ((buyTmps.marketShareBefore * adjustedSupply / buyTmps.expectedSupply) - buyTmps.marketShareBefore) / buyTmps.startTokenSupply;
                uint256 creatorShareOfDemandFee = demandFee * buyTmps.buyDemandFeeBPS / BPS;
                revenueShare += creatorShareOfDemandFee;
                marketValueShare += (demandFee - creatorShareOfDemandFee);
            }
        }
        uint256 maxMarketValueShare = type(uint120).max - buyTmps.marketShareBefore;
        if (marketValueShare > maxMarketValueShare) {
            buyTmps.expectRevert = true;
        }

        if (marketValueShare + revenueShare > buyTmps.pairedValueIn) {
            buyTmps.expectRevert = true;
        }

        BuyOrder memory buyOrder = BuyOrder({
            tokenMasterToken: address(buyTmps.pool),
            tokensToBuy: buyTmps.tokensToBuy,
            pairedValueIn: buyTmps.pairedValueIn
        });

        buyTmps.buyerTokenBalanceBefore = buyTmps.pool.balanceOf(buyTmps.buyer);

        BuyTmps memory tmpBuyTmps = buyTmps;
        _buyTokensInternal(tmpBuyTmps.buyerKey, tmpBuyTmps.buyer, buyOrder, tmpBuyTmps.msgValue, tmpBuyTmps.errorSelector, tmpBuyTmps.expectRevert);

        uint256 marketShareAfter;
        uint256 revenueShareAfter;
        {
            uint256 creatorShare;
            uint256 infrastructureShare;
            uint256 partnerShare;
            (
                marketShareAfter,
                creatorShare,
                infrastructureShare,
                partnerShare
            ) = tmpBuyTmps.pool.pairedTokenShares();
            revenueShareAfter = creatorShare + infrastructureShare + partnerShare;
        }
        uint256 buyerTokenBalanceAfter = tmpBuyTmps.pool.balanceOf(tmpBuyTmps.buyer);

        if (tmpBuyTmps.expectRevert) {
            assertEq(tmpBuyTmps.marketShareBefore, marketShareAfter);
            assertEq(tmpBuyTmps.revenueShareBefore, revenueShareAfter);
            assertEq(tmpBuyTmps.buyerTokenBalanceBefore, buyerTokenBalanceAfter);
        } else {
            assertEq(tmpBuyTmps.marketShareBefore + marketValueShare, marketShareAfter, "market share");
            assertEq(
                tmpBuyTmps.revenueShareBefore + revenueShare,
                revenueShareAfter,
                "revenue share"
            );
            assertEq(tmpBuyTmps.buyerTokenBalanceBefore + tmpBuyTmps.tokensToBuy, buyerTokenBalanceAfter, "buyer balance");
        }
    }

    function _buyTokensInternal(
        uint256 /*buyerKey*/,
        address buyer,
        BuyOrder memory buyOrder,
        uint256 msgValue,
        bytes4 errorSelector,
        bool expectRevert
    ) internal virtual {
        _executeBuyTokens(buyer, buyOrder, msgValue, errorSelector, expectRevert);
    }

    struct SellTmps {
        uint256 sellerKey;
        address seller;
        StandardPool pool;
        uint256 marketShareBefore;
        uint256 revenueShareBefore;
        uint256 sellerTokenBalanceBefore;
    }
    function _sellTokens(
        uint256 sellerKey,
        address seller, 
        StandardPool pool,
        uint256 tokensToSell,
        uint256 minimumOut,
        bytes4 errorSelector
    ) internal {
        SellTmps memory sellTmps;
        sellTmps.sellerKey = sellerKey;
        sellTmps.seller = seller;
        sellTmps.pool = pool;
        sellTmps.sellerTokenBalanceBefore = pool.balanceOf(sellTmps.seller);
        {
            uint256 marketShare;
            uint256 creatorShare;
            uint256 infrastructureShare;
            uint256 partnerShare;
            (
                marketShare,
                creatorShare,
                infrastructureShare,
                partnerShare
            ) = sellTmps.pool.pairedTokenShares();
            sellTmps.marketShareBefore = marketShare;
            sellTmps.revenueShareBefore = creatorShare + infrastructureShare + partnerShare;
        }

        StandardPoolSellParameters memory sellParams = sellTmps.pool.getSellParameters();
        uint256 pairedTokenValue = tokensToSell * sellTmps.marketShareBefore / sellTmps.pool.totalSupply();
        uint256 pairedValueFromMarket = pairedTokenValue * (BPS - sellParams.sellSpreadBPS) / BPS;
        uint256 expectedSellerProceeds = pairedTokenValue * (BPS - sellParams.sellSpreadBPS - sellParams.sellFeeBPS) / BPS;
        uint256 revenueShare = pairedValueFromMarket - expectedSellerProceeds;

        SellOrder memory sellOrder;
        sellOrder.tokenMasterToken = address(pool);
        sellOrder.tokensToSell = tokensToSell;
        sellOrder.minimumOut = minimumOut;

        bool expectRevert = errorSelector != NO_ERROR;

        if (sellOrder.minimumOut > pairedValueFromMarket) {
            expectRevert = true;
        }
        if (sellOrder.tokensToSell > sellTmps.pool.balanceOf(sellTmps.seller)) {
            expectRevert = true;
        }

        _sellTokensInternal(seller, sellOrder, errorSelector, expectRevert);

        uint256 marketShareAfter;
        uint256 revenueShareAfter;
        {
            uint256 creatorShare;
            uint256 infrastructureShare;
            uint256 partnerShare;
            (
                marketShareAfter,
                creatorShare,
                infrastructureShare,
                partnerShare
            ) = sellTmps.pool.pairedTokenShares();
            revenueShareAfter = creatorShare + infrastructureShare + partnerShare;
        }
        uint256 sellerTokenBalanceAfter = sellTmps.pool.balanceOf(sellTmps.seller);
        
        if (expectRevert) {
            assertEq(sellTmps.sellerTokenBalanceBefore, sellerTokenBalanceAfter);
            assertEq(sellTmps.marketShareBefore, marketShareAfter);
            assertEq(sellTmps.revenueShareBefore, revenueShareAfter);
        } else {
            assertEq(sellTmps.sellerTokenBalanceBefore - sellOrder.tokensToSell, sellerTokenBalanceAfter);
            assertEq(sellTmps.marketShareBefore - pairedValueFromMarket, marketShareAfter);
            assertEq(sellTmps.revenueShareBefore + revenueShare, revenueShareAfter);
        }
    }

    function _sellTokensInternal(
        address seller,
        SellOrder memory sellOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal virtual {
        _executeSellTokens(seller, sellOrder, errorSelector, expectRevert);
    }

    function _spendTokensInternalWithSignedOrder(
        uint256 /*spenderKey*/,
        address spender,
        SpendOrder memory spendOrder,
        SignedOrder memory signedOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        _executeSpendTokens(spender, spendOrder, signedOrder, errorSelector, expectRevert);
    }

    function _loadBuyParameters(StandardPoolBuyParameters memory buyParameters, uint256 timestamp) internal pure returns(
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
                if (targetSupplyBaselineTimestamp < timestamp) {
                    expectedSupply +=
                        buyParameters.targetSupplyGrowthRatePerSecond * (timestamp - buyParameters.targetSupplyBaselineTimestamp);
                }
            }
        }
    }

    function _dealPaired(address account, uint256 amount) internal virtual {
        vm.deal(account, amount);
    }

    function _pairedBalance(address account) internal view virtual returns (uint256) {
        return account.balance;
    }
}