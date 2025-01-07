// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@limitbreak/tokenmaster/test/TokenMasterToken.t.sol";
import "@limitbreak/tokenmaster/src/pools/standard-token-pool/DataTypes.sol";
import "@limitbreak/tokenmaster/src/pools/stable-pool/DataTypes.sol";
import "@limitbreak/tokenmaster/src/pools/promotional-pool/DataTypes.sol";
import {StandardPool} from "@limitbreak/tokenmaster/src/pools/standard-token-pool/StandardPool.sol";
import {StablePool} from "@limitbreak/tokenmaster/src/pools/stable-pool/StablePool.sol";
import {PromotionalPool} from "@limitbreak/tokenmaster/src/pools/promotional-pool/PromotionalPool.sol";
import {OracleAlternateAssetPrice} from "../src/examples/OracleAlternateAssetPrice.sol";
import {HookSpendMintsERC721C} from "../src/examples/HookSpendMintsERC721C.sol";
import {HookBuyMintsPromoToken} from "../src/examples/HookBuyMintsPromoToken.sol";

contract ExamplesTest is TokenMasterTokenTest {
    
    struct Tmps {
        address deployer;
        address tokenAddress;
        address tokenAddress2;
        uint256 traderKey;
        address trader;
        uint256 signerKey;
        address signer;
    }

    // Deploys a Standard Pool token
    // Executes buy of token
    // Executes a spend of token with price adjusted through oracle to mint ERC721-C
    function testExampleStandardPool() public {
        Tmps memory tmps;

        // Define token parameters
        tmps.deployer = address(0x4444);
        StandardPoolInitializationParameters memory initializationParams = _defaultStandardPoolInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, abi.encode(initializationParams));
        deploymentParameters.tokenFactory = address(standardPoolFactory);

        // Deploy token
        _dealPaired(tmps.deployer, 10 ether);
        _updateDeploymentAddress(deploymentParameters);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);

        // Buy tokens
        tmps.trader = vm.addr(0x5555);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.trader, tmps.tokenAddress, 5 ether, 6 ether, 6 ether, NO_ERROR, false);

        // Deploy Oracle and Spend Hook
        OracleAlternateAssetPrice oracle = new OracleAlternateAssetPrice();
        HookSpendMintsERC721C spendHook = new HookSpendMintsERC721C(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), type(uint64).max);

        // Configure oracle to reduce spend cost 1/10
        oracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        // Configure order signer
        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);
        vm.prank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);

        // Define signed spend order
        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(oracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5;
        signedOrder.maxTotal = 10;
        signedOrder.expiration = block.timestamp;
        signedOrder.hook = address(spendHook);

        // Sign spend order
        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            0,
            address(0),
            0,
            SPEND_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        SpendOrder memory spendOrder;
        spendOrder.tokenMasterToken = tmps.tokenAddress;
        spendOrder.multiplier = 1;
        spendOrder.maxAmountToSpend = 1 ether;

        // Execute spend
        _executeSpendTokens(
            tmps.trader,
            spendOrder,
            signedOrder,
            NO_ERROR,
            false
        );

        assertEq(StandardPool(tmps.tokenAddress).balanceOf(tmps.trader), 4.9 ether); // 5e18 purchased, 1e17 spent
        assertEq(spendHook.balanceOf(tmps.trader), 1);
    }

    // Deploys a Stable Pool token
    // Executes buy of stable token with advanced buy that mints promo tokens
    function testExampleStablePool() public {
        Tmps memory tmps;

        // Define token parameters
        tmps.deployer = address(0x4444);
        StablePoolInitializationParameters memory initializationParams = _defaultStablePoolInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, abi.encode(initializationParams));
        deploymentParameters.tokenFactory = address(stablePoolFactory);

        // Deploy token
        _dealPaired(tmps.deployer, 10 ether);
        _updateDeploymentAddress(deploymentParameters);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);

        // Define promo pool and deploy
        PromotionalPoolInitializationParameters memory promoInitializationParams = _defaultPromotionalPoolInitializationParameters();
        deploymentParameters = _defaultDeploymentParameters(tmps.deployer, abi.encode(promoInitializationParams));
        deploymentParameters.tokenFactory = address(promotionalPoolFactory);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 0 ether;
        _updateDeploymentAddress(deploymentParameters);
        tmps.tokenAddress2 = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);

        // Deploy Buy Hook
        HookBuyMintsPromoToken buyHook = new HookBuyMintsPromoToken(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), tmps.tokenAddress2);

        // Configure order signer
        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        PromotionalPool(tmps.tokenAddress2).grantRole(keccak256("MINTER_ROLE"), address(buyHook));
        vm.stopPrank();

        // Define signed buy order
        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(0);
        signedOrder.baseToken = address(0);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = block.timestamp;
        signedOrder.hook = address(buyHook);

        // Sign buy order
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);
        _dealPaired(tmps.trader, 10 ether);
        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            0,
            address(0),
            0,
            BUY_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = tmps.tokenAddress;
        buyOrder.tokensToBuy = 5 ether;
        buyOrder.pairedValueIn = 6 ether;

        // Buy tokens
        _buyTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            buyOrder,
            signedOrder,
            6 ether,
            NO_ERROR,
            false
        );

        assertEq(StablePool(tmps.tokenAddress).balanceOf(tmps.trader), 5 ether);
        assertEq(PromotionalPool(tmps.tokenAddress2).balanceOf(tmps.trader), 5 ether);
    }

    function _defaultStandardPoolInitializationParameters() internal view returns (StandardPoolInitializationParameters memory initializationParams) {
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

    function _defaultStablePoolInitializationParameters() internal view returns (StablePoolInitializationParameters memory initializationParams) {
        initializationParams.initialSupplyRecipient = address(this);
        initializationParams.initialSupplyAmount = 100 ether;
        initializationParams.maxBuyFeeBPS = 300;
        initializationParams.maxSellFeeBPS = 350;
        initializationParams.initialBuyParameters = StablePoolBuyParameters({
            buyFeeBPS: 225
        });
        initializationParams.initialSellParameters = StablePoolSellParameters({
            sellFeeBPS: 275
        });
        initializationParams.stablePairedPricePerToken = PairedPricePerToken({
            numerator: 1,
            denominator: 100
        });
    }

    function _defaultPromotionalPoolInitializationParameters() internal view returns (PromotionalPoolInitializationParameters memory initializationParams) {
        initializationParams.initialSupplyRecipient = address(this);
        initializationParams.initialSupplyAmount = 100 ether;
        initializationParams.initialBuyParameters = PromotionalPoolBuyParameters({
            buyCostPairedTokenNumerator: 1,
            buyCostPoolTokenDenominator: 100
        });
    }

    function _defaultDeploymentParameters(
        address initialOwner,
        bytes memory args
    ) internal view virtual returns (DeploymentParameters memory deploymentParameters) {
        deploymentParameters.tokenSalt = bytes32(0);
        deploymentParameters.blockTransactionsFromUntrustedChannels = false;
        deploymentParameters.restrictPairingToLists = false;
        deploymentParameters.maxInfrastructureFeeBPS = 175;
        deploymentParameters.poolParams = PoolDeploymentParameters({
            name: "Example",
            symbol: "E",
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

    function _buyTokens(
        address buyer,
        address tokenAddress,
        uint256 tokensToBuy,
        uint256 pairedValueIn,
        uint256 msgValue,
        bytes4 errorSelector,
        bool expectRevert
    ) internal virtual {
        BuyOrder memory buyOrder = BuyOrder({
            tokenMasterToken: tokenAddress,
            tokensToBuy: tokensToBuy,
            pairedValueIn: pairedValueIn
        });

        _executeBuyTokens(buyer, buyOrder, msgValue, errorSelector, expectRevert);
    }

    function _dealPaired(address account, uint256 amount) internal virtual {
        vm.deal(account, amount);
    }

    function _pairedBalance(address account) internal view virtual returns (uint256) {
        return account.balance;
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

    function _buyTokensInternalWithSignedOrder(
        uint256 /*buyerKey*/,
        address buyer,
        BuyOrder memory buyOrder,
        SignedOrder memory signedOrder,
        uint256 msgValue,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        PermitTransfer memory permitTransfer;

        _executeBuyTokensAdvanced(buyer, buyOrder, signedOrder, permitTransfer, msgValue, errorSelector, expectRevert);
    }
}