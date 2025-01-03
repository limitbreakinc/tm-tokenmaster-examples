// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./StablePoolToken.t.sol";
import {MockBuyHookPromoPool} from "../../mocks/MockBuyHookPromoPool.sol";
import {MockSellHookPromoPool} from "../../mocks/MockSellHookPromoPool.sol";
import {MockSpendHookERC721C} from "../../mocks/MockSpendHookERC721C.sol";
import {MockOracle} from "../../mocks/MockOracle.sol";
import "src/pools/promotional-pool/IPromotionalPool.sol";
import "src/pools/promotional-pool/PromotionalPool.sol";

contract StablePoolTokenNativeBuyAdvancedTest is StablePoolTokenTest {
    MockOracle private mockOracle;
    PromotionalPool private promoPool;
    address promoPoolOwner = address(0x920440);
    MockBuyHookPromoPool private buyHook;
    MockSellHookPromoPool private sellHook;
    MockSpendHookERC721C private spendHook;

    function setUp() public virtual override {
        super.setUp();

        vm.deal(promoPoolOwner, 50 ether);
        StablePoolInitializationParameters memory initParams;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(promoPoolOwner, initParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 0 ether;
        PromotionalPoolInitializationParameters memory promoInitParams;
        promoInitParams.initialSupplyRecipient = promoPoolOwner;
        promoInitParams.initialSupplyAmount = type(uint128).max;
        promoInitParams.initialBuyParameters.buyCostPairedTokenNumerator = 2;
        promoInitParams.initialBuyParameters.buyCostPoolTokenDenominator = 1;
        deploymentParameters.tokenFactory = address(promotionalPoolFactory);
        deploymentParameters.poolParams.encodedInitializationArgs = abi.encode(promoInitParams);
        deploymentParameters.poolParams.initialOwner = promoPoolOwner;
        _updateDeploymentAddress(deploymentParameters);
        SignatureECDSA memory emptySignature;
        promoPool = PromotionalPool(_deployToken(promoPoolOwner, deploymentParameters, emptySignature, NO_ERROR));

        mockOracle = new MockOracle();
    }

    function testBuyHook() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        buyHook = new MockBuyHookPromoPool(address(tokenMasterRouter), tokenAddress, bytes32(uint256(0xFFFF)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(buyHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        uint256 signerKey = 0x0101;
        address signer = vm.addr(signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFFFF));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(buyHook);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 10 ether);
        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            trader,
            signerKey,
            signer,
            0,
            address(0),
            0,
            BUY_TYPEHASH,
            tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = tokenAddress;
        buyOrder.tokensToBuy = 5 ether;
        buyOrder.pairedValueIn = 6 ether;
        _buyTokensInternalWithSignedOrder(
            traderKey,
            trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tokenAddress, signer, true);
        vm.stopPrank();
        vm.startPrank(deployer);
        tokenMasterRouter.setOrderSigner(tokenAddress, signer, true);
        vm.stopPrank();
        _buyTokensInternalWithSignedOrder(
            traderKey,
            trader,
            buyOrder,
            signedOrder,
            6 ether,
            NO_ERROR,
            false
        );
        assertEq(promoPool.balanceOf(trader), 5 ether);

        (
            uint256 totalBought,
            uint256 totalWalletBought,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getBuyTrackingData(tokenAddress, signedOrder, trader);
        assertEq(totalBought, 5 ether);
        assertEq(totalWalletBought, 5 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsBuyHookWhenBuyIsBelowMinimum() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        buyHook = new MockBuyHookPromoPool(address(tokenMasterRouter), tokenAddress, bytes32(uint256(0xFFFF)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(buyHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        uint256 signerKey = 0x0101;
        address signer = vm.addr(signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFFFF));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(buyHook);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 10 ether);
        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            trader,
            signerKey,
            signer,
            0,
            address(0),
            0,
            BUY_TYPEHASH,
            tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = tokenAddress;
        buyOrder.tokensToBuy = 0.1 ether - 1;
        buyOrder.pairedValueIn = 6 ether;
        _buyTokensInternalWithSignedOrder(
            traderKey,
            trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tokenAddress, signer, true);
        vm.stopPrank();
        vm.startPrank(deployer);
        tokenMasterRouter.setOrderSigner(tokenAddress, signer, true);
        vm.stopPrank();
        _buyTokensInternalWithSignedOrder(
            traderKey,
            trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderDoesNotMeetMinimum.selector,
            false
        );
        assertEq(promoPool.balanceOf(trader), 0 ether);

        (
            uint256 totalBought,
            uint256 totalWalletBought,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getBuyTrackingData(tokenAddress, signedOrder, trader);
        assertEq(totalBought, 0 ether);
        assertEq(totalWalletBought, 0 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsBuyHookWhenBuyOrderIsExpired() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        buyHook = new MockBuyHookPromoPool(address(tokenMasterRouter), tokenAddress, bytes32(uint256(0xFFFF)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(buyHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        uint256 signerKey = 0x0101;
        address signer = vm.addr(signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFFFF));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp - 1;
        signedOrder.hook = address(buyHook);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 10 ether);
        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            trader,
            signerKey,
            signer,
            0,
            address(0),
            0,
            BUY_TYPEHASH,
            tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = tokenAddress;
        buyOrder.tokensToBuy = 0.1 ether;
        buyOrder.pairedValueIn = 6 ether;
        _buyTokensInternalWithSignedOrder(
            traderKey,
            trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderExpired.selector,
            false
        );
        vm.startPrank(trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tokenAddress, signer, true);
        vm.stopPrank();
        vm.startPrank(deployer);
        tokenMasterRouter.setOrderSigner(tokenAddress, signer, true);
        vm.stopPrank();
        _buyTokensInternalWithSignedOrder(
            traderKey,
            trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderExpired.selector,
            false
        );
        assertEq(promoPool.balanceOf(trader), 0 ether);

        (
            uint256 totalBought,
            uint256 totalWalletBought,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getBuyTrackingData(tokenAddress, signedOrder, trader);
        assertEq(totalBought, 0 ether);
        assertEq(totalWalletBought, 0 ether);
        assertFalse(orderDisabled);
        assertFalse(signatureValid);
        assertFalse(cosignatureValid);
    }

    function testRevertsBuyHookWhenBuyOrderWhenWalletMaxExceeded() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        buyHook = new MockBuyHookPromoPool(address(tokenMasterRouter), tokenAddress, bytes32(uint256(0xFFFF)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(buyHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        uint256 signerKey = 0x0101;
        address signer = vm.addr(signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFFFF));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 1 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(buyHook);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 10 ether);
        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            trader,
            signerKey,
            signer,
            0,
            address(0),
            0,
            BUY_TYPEHASH,
            tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = tokenAddress;
        buyOrder.tokensToBuy = 5 ether;
        buyOrder.pairedValueIn = 6 ether;
        vm.startPrank(deployer);
        tokenMasterRouter.setOrderSigner(tokenAddress, signer, true);
        vm.stopPrank();
        _buyTokensInternalWithSignedOrder(
            traderKey,
            trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderMaxPerWalletExceeded.selector,
            false
        );
        assertEq(promoPool.balanceOf(trader), 0 ether);

        (
            uint256 totalBought,
            uint256 totalWalletBought,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getBuyTrackingData(tokenAddress, signedOrder, trader);
        assertEq(totalBought, 0 ether);
        assertEq(totalWalletBought, 0 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsBuyHookWhenBuyOrderWhenOrderMaxExceeded() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        buyHook = new MockBuyHookPromoPool(address(tokenMasterRouter), tokenAddress, bytes32(uint256(0xFFFF)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(buyHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        uint256 signerKey = 0x0101;
        address signer = vm.addr(signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFFFF));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 6 ether;
        signedOrder.maxTotal = 1 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(buyHook);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 10 ether);
        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            trader,
            signerKey,
            signer,
            0,
            address(0),
            0,
            BUY_TYPEHASH,
            tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = tokenAddress;
        buyOrder.tokensToBuy = 5 ether;
        buyOrder.pairedValueIn = 6 ether;
        vm.startPrank(deployer);
        tokenMasterRouter.setOrderSigner(tokenAddress, signer, true);
        vm.stopPrank();
        _buyTokensInternalWithSignedOrder(
            traderKey,
            trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderMaxTotalExceeded.selector,
            false
        );
        assertEq(promoPool.balanceOf(trader), 0 ether);

        (
            uint256 totalBought,
            uint256 totalWalletBought,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getBuyTrackingData(tokenAddress, signedOrder, trader);
        assertEq(totalBought, 0 ether);
        assertEq(totalWalletBought, 0 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsBuyHookWhenOrderIsDisabled() public {
        TempBuyHook memory tmps;
        tmps.deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);

        buyHook = new MockBuyHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFFFF)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(buyHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFFFF));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(buyHook);

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
        buyOrder.tokensToBuy = 0.1 ether;
        buyOrder.pairedValueIn = 6 ether;
        _buyTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        address manager = address(0x4444632);
        StablePool(tmps.tokenAddress).grantRole(ORDER_MANAGER_ROLE, manager);
        vm.stopPrank();
        vm.startPrank(manager);
        tokenMasterRouter.disableBuyOrder(tmps.tokenAddress, signedOrder, true);
        vm.stopPrank();
        _buyTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderDisabled.selector,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 0 ether);

        TempBuyHook memory tmpTmps = tmps;

        (
            uint256 totalBought,
            uint256 totalWalletBought,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getBuyTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalBought, 0 ether);
        assertEq(totalWalletBought, 0 ether);
        assertTrue(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    struct TempBuyHook {
        uint256 signerKey;
        address signer;
        uint256 cosignerKey;
        address cosigner;
        address tokenAddress;
        address deployer;
        uint256 traderKey;
        address trader;
    }
    function testBuyHookWithCosignature() public {
        TempBuyHook memory tmps;
        tmps.deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);

        buyHook = new MockBuyHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFFFF)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(buyHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);
        tmps.cosignerKey = 0x0202;
        tmps.cosigner = vm.addr(tmps.cosignerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFFFF));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(buyHook);

        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);
        _dealPaired(tmps.trader, 10 ether);
        (SignatureECDSA memory signedOrderSignature, Cosignature memory cosignature) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            tmps.cosignerKey,
            tmps.cosigner,
            timestamp,
            BUY_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;
        signedOrder.cosignature = cosignature;

        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = tmps.tokenAddress;
        buyOrder.tokensToBuy = 5 ether;
        buyOrder.pairedValueIn = 6 ether;
        _buyTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _buyTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            buyOrder,
            signedOrder,
            6 ether,
            NO_ERROR,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 5 ether);

        TempBuyHook memory tmpTmps = tmps;
        (
            uint256 totalBought,
            uint256 totalWalletBought,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getBuyTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalBought, 5 ether);
        assertEq(totalWalletBought, 5 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsBuyHookWithInvalidCosignature() public {
        TempBuyHook memory tmps;
        tmps.deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);

        buyHook = new MockBuyHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFFFF)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(buyHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);
        tmps.cosignerKey = 0x0202;
        tmps.cosigner = vm.addr(tmps.cosignerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFFFF));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(buyHook);

        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);
        _dealPaired(tmps.trader, 10 ether);
        (SignatureECDSA memory signedOrderSignature, Cosignature memory cosignature) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            tmps.cosignerKey,
            tmps.cosigner,
            timestamp,
            BUY_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        cosignature.r = keccak256(abi.encode(cosignature.r));
        signedOrder.signature = signedOrderSignature;
        signedOrder.cosignature = cosignature;

        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = tmps.tokenAddress;
        buyOrder.tokensToBuy = 5 ether;
        buyOrder.pairedValueIn = 6 ether;
        _buyTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _buyTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            buyOrder,
            signedOrder,
            6 ether,
            TokenMasterRouter__CosignatureInvalid.selector,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 0);

        TempBuyHook memory tmpTmps = tmps;
        (
            uint256 totalBought,
            uint256 totalWalletBought,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getBuyTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalBought, 0);
        assertEq(totalWalletBought, 0);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertFalse(cosignatureValid);
    }

    function _buyTokensInternal(
        uint256 /*buyerKey*/,
        address buyer,
        BuyOrder memory buyOrder,
        uint256 msgValue,
        bytes4 errorSelector,
        bool expectRevert
    ) internal override {
        SignedOrder memory signedOrder;
        PermitTransfer memory permitTransfer;

        _executeBuyTokensAdvanced(buyer, buyOrder, signedOrder, permitTransfer, msgValue, errorSelector, expectRevert);
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














    struct TempSellHook {
        uint256 signerKey;
        address signer;
        uint256 cosignerKey;
        address cosigner;
        address tokenAddress;
        address deployer;
        uint256 traderKey;
        address trader;
    }
    function testSellHook() public {
        TempSellHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        sellHook = new MockSellHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFEFE)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(sellHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFEFE));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(sellHook);

        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            0,
            address(0),
            0,
            SELL_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        SellOrder memory sellOrder;
        sellOrder.tokenMasterToken = tmps.tokenAddress;
        sellOrder.tokensToSell = 5 ether;
        sellOrder.minimumOut = 0.004 ether;
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            NO_ERROR,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 5 ether);

        TempSellHook memory tmpTmps = tmps;
        (
            uint256 totalSold,
            uint256 totalWalletSold,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSellTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalSold, 5 ether);
        assertEq(totalWalletSold, 5 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsSellHookWhenSellIsBelowMinimum() public {
        TempSellHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        sellHook = new MockSellHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFEFE)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(sellHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFEFE));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(sellHook);
        
        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            0,
            address(0),
            0,
            SELL_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        SellOrder memory sellOrder;
        sellOrder.tokenMasterToken = tmps.tokenAddress;
        sellOrder.tokensToSell = 0.1 ether - 1;
        sellOrder.minimumOut = 0.001 ether;
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderDoesNotMeetMinimum.selector,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 0 ether);

        TempSellHook memory tmpTmps = tmps;
        (
            uint256 totalSold,
            uint256 totalWalletSold,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSellTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalSold, 0 ether);
        assertEq(totalWalletSold, 0 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsSellHookWhenSellOrderIsExpired() public {
        TempSellHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        sellHook = new MockSellHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFEFE)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(sellHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFEFE));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp - 1;
        signedOrder.hook = address(sellHook);

        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            0,
            address(0),
            0,
            SELL_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        SellOrder memory sellOrder;
        sellOrder.tokenMasterToken = tmps.tokenAddress;
        sellOrder.tokensToSell = 0.1 ether;
        sellOrder.minimumOut = 0.001 ether;
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderExpired.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderExpired.selector,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 0 ether);

        TempSellHook memory tmpTmps = tmps;
        (
            uint256 totalSold,
            uint256 totalWalletSold,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSellTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalSold, 0 ether);
        assertEq(totalWalletSold, 0 ether);
        assertFalse(orderDisabled);
        assertFalse(signatureValid);
        assertFalse(cosignatureValid);
    }

    function testRevertsSellHookWhenSellOrderWhenWalletMaxExceeded() public {
        TempSellHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        sellHook = new MockSellHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFEFE)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(sellHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFEFE));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 1 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(sellHook);

        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            0,
            address(0),
            0,
            SELL_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        SellOrder memory sellOrder;
        sellOrder.tokenMasterToken = tmps.tokenAddress;
        sellOrder.tokensToSell = 5 ether;
        sellOrder.minimumOut = 1 ether;
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderMaxPerWalletExceeded.selector,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 0 ether);

        TempSellHook memory tmpTmps = tmps;
        (
            uint256 totalSold,
            uint256 totalWalletSold,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSellTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalSold, 0 ether);
        assertEq(totalWalletSold, 0 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsSellHookWhenBuyOrderWhenOrderMaxExceeded() public {
        TempSellHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        sellHook = new MockSellHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFEFE)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(sellHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFEFE));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 6 ether;
        signedOrder.maxTotal = 1 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(sellHook);

        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            0,
            address(0),
            0,
            SELL_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        SellOrder memory sellOrder;
        sellOrder.tokenMasterToken = tmps.tokenAddress;
        sellOrder.tokensToSell = 5 ether;
        sellOrder.minimumOut = 1 ether;
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderMaxTotalExceeded.selector,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 0 ether);

        TempSellHook memory tmpTmps = tmps;
        (
            uint256 totalSold,
            uint256 totalWalletSold,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSellTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalSold, 0 ether);
        assertEq(totalWalletSold, 0 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsSellHookWhenOrderIsDisabled() public {
        TempSellHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        sellHook = new MockSellHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFEFE)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(sellHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFEFE));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(sellHook);

        (SignatureECDSA memory signedOrderSignature, ) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            0,
            address(0),
            0,
            SELL_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;

        SellOrder memory sellOrder;
        sellOrder.tokenMasterToken = tmps.tokenAddress;
        sellOrder.tokensToSell = 0.1 ether;
        sellOrder.minimumOut = 0.001 ether;
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        address manager = address(0x4444632);
        StablePool(tmps.tokenAddress).grantRole(ORDER_MANAGER_ROLE, manager);
        vm.stopPrank();
        vm.startPrank(manager);
        tokenMasterRouter.disableSellOrder(tmps.tokenAddress, signedOrder, true);
        vm.stopPrank();
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderDisabled.selector,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 0 ether);

        TempSellHook memory tmpTmps = tmps;

        (
            uint256 totalSold,
            uint256 totalWalletSold,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSellTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalSold, 0 ether);
        assertEq(totalWalletSold, 0 ether);
        assertTrue(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testSellHookWithCosignature() public {
        TempSellHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        sellHook = new MockSellHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFEFE)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(sellHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);
        tmps.cosignerKey = 0x0202;
        tmps.cosigner = vm.addr(tmps.cosignerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFEFE));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(sellHook);

        (SignatureECDSA memory signedOrderSignature, Cosignature memory cosignature) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            tmps.cosignerKey,
            tmps.cosigner,
            timestamp,
            SELL_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;
        signedOrder.cosignature = cosignature;

        SellOrder memory sellOrder;
        sellOrder.tokenMasterToken = tmps.tokenAddress;
        sellOrder.tokensToSell = 5 ether;
        sellOrder.minimumOut = 0.004 ether;
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            NO_ERROR,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 5 ether);

        TempSellHook memory tmpTmps = tmps;
        (
            uint256 totalSold,
            uint256 totalWalletSold,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSellTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalSold, 5 ether);
        assertEq(totalWalletSold, 5 ether);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsSellHookWithInvalidCosignature() public {
        TempSellHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        sellHook = new MockSellHookPromoPool(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFEFE)), address(promoPool));
        vm.startPrank(promoPoolOwner);
        promoPool.grantRole(keccak256("MINTER_ROLE"), address(sellHook));
        vm.stopPrank();

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);
        tmps.cosignerKey = 0x0202;
        tmps.cosigner = vm.addr(tmps.cosignerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFEFE));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5 ether;
        signedOrder.maxTotal = 10 ether;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(sellHook);

        (SignatureECDSA memory signedOrderSignature, Cosignature memory cosignature) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            tmps.cosignerKey,
            tmps.cosigner,
            timestamp,
            SELL_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        cosignature.r = keccak256(abi.encode(cosignature.r));
        signedOrder.signature = signedOrderSignature;
        signedOrder.cosignature = cosignature;

        SellOrder memory sellOrder;
        sellOrder.tokenMasterToken = tmps.tokenAddress;
        sellOrder.tokensToSell = 5 ether;
        sellOrder.minimumOut = 1 ether;
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _sellTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            sellOrder,
            signedOrder,
            TokenMasterRouter__CosignatureInvalid.selector,
            false
        );
        assertEq(promoPool.balanceOf(tmps.trader), 0);

        TempSellHook memory tmpTmps = tmps;
        (
            uint256 totalSold,
            uint256 totalWalletSold,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSellTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalSold, 0);
        assertEq(totalWalletSold, 0);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertFalse(cosignatureValid);
    }

    function _sellTokensInternalWithSignedOrder(
        uint256 /*sellerKey*/,
        address seller,
        SellOrder memory sellOrder,
        SignedOrder memory signedOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        _executeSellTokensAdvanced(seller, sellOrder, signedOrder, errorSelector, expectRevert);
    }







    struct TempSpendHook {
        uint256 signerKey;
        address signer;
        uint256 cosignerKey;
        address cosigner;
        address tokenAddress;
        address deployer;
        uint256 traderKey;
        address trader;
    }
    function testSpendHook() public {
        TempSpendHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        spendHook = new MockSpendHookERC721C(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), type(uint64).max);

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5;
        signedOrder.maxTotal = 10;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(spendHook);

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
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            NO_ERROR,
            false
        );
        assertEq(spendHook.balanceOf(tmps.trader), 1);

        TempSpendHook memory tmpTmps = tmps;
        (
            uint256 totalMultipliersSpent,
            uint256 totalWalletMultipliersSpent,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSpendTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalMultipliersSpent, 1);
        assertEq(totalWalletMultipliersSpent, 1);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsSpendHookWhenSpendOrderIsExpired() public {
        TempSpendHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        spendHook = new MockSpendHookERC721C(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), type(uint64).max);

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5;
        signedOrder.maxTotal = 10;
        signedOrder.expiration = timestamp - 1;
        signedOrder.hook = address(spendHook);

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
        spendOrder.maxAmountToSpend = 5 ether;
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderExpired.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderExpired.selector,
            false
        );
        assertEq(spendHook.balanceOf(tmps.trader), 0);

        TempSpendHook memory tmpTmps = tmps;
        (
            uint256 totalMultipliersSpent,
            uint256 totalWalletMultipliersSpent,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSpendTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalMultipliersSpent, 0);
        assertEq(totalWalletMultipliersSpent, 0);
        assertFalse(orderDisabled);
        assertFalse(signatureValid);
        assertFalse(cosignatureValid);
    }

    function testRevertsSpendHookWhenSpendOrderWhenWalletMaxExceeded() public {
        TempSpendHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        spendHook = new MockSpendHookERC721C(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), type(uint64).max);

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 1;
        signedOrder.maxTotal = 10;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(spendHook);

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
        spendOrder.multiplier = 2;
        spendOrder.maxAmountToSpend = 1 ether;
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderMaxPerWalletExceeded.selector,
            false
        );
        assertEq(spendHook.balanceOf(tmps.trader), 0);

        TempSpendHook memory tmpTmps = tmps;
        (
            uint256 totalMultipliersSpent,
            uint256 totalWalletMultipliersSpent,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSpendTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalMultipliersSpent, 0);
        assertEq(totalWalletMultipliersSpent, 0);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsSpendHookWhenSpendOrderWhenOrderMaxExceeded() public {
        TempSpendHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        spendHook = new MockSpendHookERC721C(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), type(uint64).max);

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 1;
        signedOrder.maxTotal = 1;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(spendHook);

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
        spendOrder.multiplier = 2;
        spendOrder.maxAmountToSpend = 1 ether;
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderMaxTotalExceeded.selector,
            false
        );
        assertEq(spendHook.balanceOf(tmps.trader), 0);

        TempSpendHook memory tmpTmps = tmps;
        (
            uint256 totalMultipliersSpent,
            uint256 totalWalletMultipliersSpent,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSpendTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalMultipliersSpent, 0);
        assertEq(totalWalletMultipliersSpent, 0);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsSpendHookWhenOrderIsDisabled() public {
        TempSpendHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        spendHook = new MockSpendHookERC721C(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), type(uint64).max);

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5;
        signedOrder.maxTotal = 10;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(spendHook);

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
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        address manager = address(0x4444632);
        StablePool(tmps.tokenAddress).grantRole(ORDER_MANAGER_ROLE, manager);
        vm.stopPrank();
        vm.startPrank(manager);
        tokenMasterRouter.disableSpendOrder(tmps.tokenAddress, signedOrder, true);
        vm.stopPrank();
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderDisabled.selector,
            false
        );
        assertEq(spendHook.balanceOf(tmps.trader), 0);

        TempSpendHook memory tmpTmps = tmps;

        (
            uint256 totalMultipliersSpent,
            uint256 totalWalletMultipliersSpent,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSpendTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalMultipliersSpent, 0);
        assertEq(totalWalletMultipliersSpent, 0);
        assertTrue(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testSpendHookWithCosignature() public {
        TempSpendHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        spendHook = new MockSpendHookERC721C(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), type(uint64).max);

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);
        tmps.cosignerKey = 0x0202;
        tmps.cosigner = vm.addr(tmps.cosignerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5;
        signedOrder.maxTotal = 10;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(spendHook);

        (SignatureECDSA memory signedOrderSignature, Cosignature memory cosignature) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            tmps.cosignerKey,
            tmps.cosigner,
            timestamp,
            SPEND_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        signedOrder.signature = signedOrderSignature;
        signedOrder.cosignature = cosignature;

        SpendOrder memory spendOrder;
        spendOrder.tokenMasterToken = tmps.tokenAddress;
        spendOrder.multiplier = 1;
        spendOrder.maxAmountToSpend = 1 ether;
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            NO_ERROR,
            false
        );
        assertEq(spendHook.balanceOf(tmps.trader), 1);

        TempSpendHook memory tmpTmps = tmps;
        (
            uint256 totalMultipliersSpent,
            uint256 totalWalletMultipliersSpent,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSpendTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalMultipliersSpent, 1);
        assertEq(totalWalletMultipliersSpent, 1);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
    }

    function testRevertsSpendHookWithInvalidCosignature() public {
        TempSpendHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        spendHook = new MockSpendHookERC721C(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), type(uint64).max);

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 1, 10);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);
        tmps.cosignerKey = 0x0202;
        tmps.cosigner = vm.addr(tmps.cosignerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5;
        signedOrder.maxTotal = 10;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(spendHook);

        (SignatureECDSA memory signedOrderSignature, Cosignature memory cosignature) = _signSignedOrder(
            tmps.trader,
            tmps.signerKey,
            tmps.signer,
            tmps.cosignerKey,
            tmps.cosigner,
            timestamp,
            SPEND_TYPEHASH,
            tmps.tokenAddress,
            signedOrder
        );
        cosignature.r = keccak256(abi.encode(cosignature.r));
        signedOrder.signature = signedOrderSignature;
        signedOrder.cosignature = cosignature;

        SpendOrder memory spendOrder;
        spendOrder.tokenMasterToken = tmps.tokenAddress;
        spendOrder.multiplier = 1;
        spendOrder.maxAmountToSpend = 1 ether;
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__CosignatureInvalid.selector,
            false
        );
        assertEq(spendHook.balanceOf(tmps.trader), 0);

        TempSpendHook memory tmpTmps = tmps;
        (
            uint256 totalMultipliersSpent,
            uint256 totalWalletMultipliersSpent,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSpendTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalMultipliersSpent, 0);
        assertEq(totalWalletMultipliersSpent, 0);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertFalse(cosignatureValid);
    }
    function testRevertsSpendHookWhenSpendIsAboveMaximum() public {
        TempSpendHook memory tmps;
        tmps.deployer = address(0x4444);
        tmps.traderKey = 0x5555;
        tmps.trader = vm.addr(tmps.traderKey);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        tmps.tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        _dealPaired(tmps.trader, 10 ether);
        _buyTokens(tmps.traderKey, tmps.trader, StablePool(tmps.tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        spendHook = new MockSpendHookERC721C(address(tokenMasterRouter), tmps.tokenAddress, bytes32(uint256(0xFDFD)), type(uint64).max);

        mockOracle.setAdjustmentValue(tmps.tokenAddress, address(0x05), 10 ether, 1);

        uint256 timestamp = 10;
        vm.warp(timestamp);

        tmps.signerKey = 0x0101;
        tmps.signer = vm.addr(tmps.signerKey);

        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = bytes32(uint256(0xFDFD));
        signedOrder.tokenMasterOracle = address(mockOracle);
        signedOrder.baseToken = address(0x05);
        signedOrder.baseValue = 1 ether;
        signedOrder.maxPerWallet = 5;
        signedOrder.maxTotal = 10;
        signedOrder.expiration = timestamp;
        signedOrder.hook = address(spendHook);
        
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
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__OrderSignerUnauthorized.selector,
            false
        );
        vm.startPrank(tmps.trader);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        tokenMasterRouter.setOrderSigner(tmps.tokenAddress, tmps.signer, true);
        vm.stopPrank();
        _spendTokensInternalWithSignedOrder(
            tmps.traderKey,
            tmps.trader,
            spendOrder,
            signedOrder,
            TokenMasterRouter__AmountToSpendExceedsMax.selector,
            false
        );
        assertEq(spendHook.balanceOf(tmps.trader), 0);

        TempSpendHook memory tmpTmps = tmps;
        (
            uint256 totalMultipliersSpent,
            uint256 totalWalletMultipliersSpent,
            bool orderDisabled,
            bool signatureValid,
            bool cosignatureValid
        ) = tokenMasterRouter.getSpendTrackingData(tmpTmps.tokenAddress, signedOrder, tmpTmps.trader);
        assertEq(totalMultipliersSpent, 0);
        assertEq(totalWalletMultipliersSpent, 0);
        assertFalse(orderDisabled);
        assertTrue(signatureValid);
        assertTrue(cosignatureValid);
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

    function testRevertsWhenNativePairSetsUseRouterForTransfer() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        deploymentParameters.poolParams.useRouterForPairedTransfers = true;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__DeployedTokenAddressMismatch.selector);
    }
}