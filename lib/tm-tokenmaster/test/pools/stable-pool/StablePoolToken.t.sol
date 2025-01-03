// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "../../TokenMasterToken.t.sol";
import "src/pools/stable-pool/IStablePool.sol";
import "src/pools/stable-pool/StablePool.sol";
import "@limitbreak/tm-core-lib/src/utils/access/Ownable.sol";
import "../../mocks/MockPairedTokenERC20.sol";

contract StablePoolTokenTest is TokenMasterTokenTest {
    MockPairedTokenERC20 internal testRecoveryToken;

    function setUp() public virtual override {
        super.setUp();

        testRecoveryToken = new MockPairedTokenERC20("Test Recovery", "TR", 18);
    }

    function testOrderSignerList() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        address[] memory testSigners = new address[](3);
        testSigners[0] = address(0xA11CE);
        testSigners[1] = address(0xB0B);
        testSigners[2] = address(0x57343);

        vm.startPrank(testSigners[0]);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setOrderSigner(tokenAddress, testSigners[0], true);
        vm.stopPrank();
        vm.startPrank(deployer);
        tokenMasterRouter.setOrderSigner(tokenAddress, testSigners[0], true);
        tokenMasterRouter.setOrderSigner(tokenAddress, testSigners[1], true);
        tokenMasterRouter.setOrderSigner(tokenAddress, testSigners[2], true);
        address[] memory storedSigners = tokenMasterRouter.getOrderSigners(tokenAddress);
        assertEq(
            keccak256(abi.encodePacked(testSigners)),
            keccak256(abi.encodePacked(storedSigners))
        );
        tokenMasterRouter.setOrderSigner(tokenAddress, testSigners[2], false);
        address[] memory updatedTestSigners = new address[](2);
        updatedTestSigners[0] = testSigners[0];
        updatedTestSigners[1] = testSigners[1];
        storedSigners = tokenMasterRouter.getOrderSigners(tokenAddress);
        assertEq(
            keccak256(abi.encodePacked(updatedTestSigners)),
            keccak256(abi.encodePacked(storedSigners))
        );
        vm.stopPrank();
    }

    function testTrustedChannelList() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);
        address[] memory storedChannels = tokenMasterRouter.getTrustedChannels(tokenAddress);

        address[] memory testTrustedChannels;
        if (storedChannels.length > 0) {
            testTrustedChannels = new address[](3 + storedChannels.length);
            for (uint256 i; i < storedChannels.length; ++i) {
                testTrustedChannels[i] = storedChannels[i];
            }
            testTrustedChannels[storedChannels.length] = address(0xA11CE);
            testTrustedChannels[storedChannels.length + 1] = address(0xB0B);
            testTrustedChannels[storedChannels.length + 2] = address(0x57343);
        } else {
            testTrustedChannels = new address[](3);
            testTrustedChannels[0] = address(0xA11CE);
            testTrustedChannels[1] = address(0xB0B);
            testTrustedChannels[2] = address(0x57343);
        }

        vm.startPrank(testTrustedChannels[0]);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setTokenAllowedTrustedChannel(tokenAddress, testTrustedChannels[0], true);
        vm.stopPrank();
        vm.startPrank(deployer);
        tokenMasterRouter.setTokenAllowedTrustedChannel(tokenAddress, testTrustedChannels[testTrustedChannels.length - 3], true);
        tokenMasterRouter.setTokenAllowedTrustedChannel(tokenAddress, testTrustedChannels[testTrustedChannels.length - 2], true);
        tokenMasterRouter.setTokenAllowedTrustedChannel(tokenAddress, testTrustedChannels[testTrustedChannels.length - 1], true);
        storedChannels = tokenMasterRouter.getTrustedChannels(tokenAddress);
        assertEq(
            keccak256(abi.encodePacked(testTrustedChannels)),
            keccak256(abi.encodePacked(storedChannels))
        );
        tokenMasterRouter.setTokenAllowedTrustedChannel(tokenAddress, testTrustedChannels[testTrustedChannels.length - 1], false);
        address[] memory updatedTrustedChannels = new address[](testTrustedChannels.length - 1);
        for (uint256 i; i < updatedTrustedChannels.length; ++i) {
            updatedTrustedChannels[i] = testTrustedChannels[i];
        }
        storedChannels = tokenMasterRouter.getTrustedChannels(tokenAddress);
        assertEq(
            keccak256(abi.encodePacked(updatedTrustedChannels)),
            keccak256(abi.encodePacked(storedChannels))
        );
        vm.stopPrank();
    }

    function testAllowedPairToDeployer() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        address[] memory testDeployers = new address[](3);
        testDeployers[0] = address(0xA11CE);
        testDeployers[1] = address(0xB0B);
        testDeployers[2] = address(0x57343);

        vm.startPrank(testDeployers[0]);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setTokenAllowedPairToDeployer(tokenAddress, testDeployers[0], true);
        vm.stopPrank();
        vm.startPrank(deployer);
        tokenMasterRouter.setTokenAllowedPairToDeployer(tokenAddress, testDeployers[0], true);
        tokenMasterRouter.setTokenAllowedPairToDeployer(tokenAddress, testDeployers[1], true);
        tokenMasterRouter.setTokenAllowedPairToDeployer(tokenAddress, testDeployers[2], true);
        address[] memory storedDeployers = tokenMasterRouter.getAllowedPairToDeployers(tokenAddress);
        assertEq(
            keccak256(abi.encodePacked(testDeployers)),
            keccak256(abi.encodePacked(storedDeployers))
        );
        tokenMasterRouter.setTokenAllowedPairToDeployer(tokenAddress, testDeployers[2], false);
        address[] memory updatedDeployers = new address[](2);
        updatedDeployers[0] = testDeployers[0];
        updatedDeployers[1] = testDeployers[1];
        storedDeployers = tokenMasterRouter.getAllowedPairToDeployers(tokenAddress);
        assertEq(
            keccak256(abi.encodePacked(updatedDeployers)),
            keccak256(abi.encodePacked(storedDeployers))
        );
        vm.stopPrank();
    }

    function testAllowedPairToToken() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        address[] memory testTokens = new address[](3);
        testTokens[0] = address(0xA11CE);
        testTokens[1] = address(0xB0B);
        testTokens[2] = address(0x57343);

        vm.startPrank(testTokens[0]);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.setTokenAllowedPairToToken(tokenAddress, testTokens[0], true);
        vm.stopPrank();
        vm.startPrank(deployer);
        tokenMasterRouter.setTokenAllowedPairToToken(tokenAddress, testTokens[0], true);
        tokenMasterRouter.setTokenAllowedPairToToken(tokenAddress, testTokens[1], true);
        tokenMasterRouter.setTokenAllowedPairToToken(tokenAddress, testTokens[2], true);
        address[] memory storedTokens = tokenMasterRouter.getAllowedPairToTokens(tokenAddress);
        assertEq(
            keccak256(abi.encodePacked(testTokens)),
            keccak256(abi.encodePacked(storedTokens))
        );
        tokenMasterRouter.setTokenAllowedPairToToken(tokenAddress, testTokens[2], false);
        address[] memory updatedTokens = new address[](2);
        updatedTokens[0] = testTokens[0];
        updatedTokens[1] = testTokens[1];
        storedTokens = tokenMasterRouter.getAllowedPairToTokens(tokenAddress);
        assertEq(
            keccak256(abi.encodePacked(updatedTokens)),
            keccak256(abi.encodePacked(storedTokens))
        );
        vm.stopPrank();
    }

    function testWithdrawUnrelatedTokens() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        vm.deal(deployer, 10 ether);
        vm.deal(deploymentParameters.tokenAddress, 10 ether);
        _dealPaired(deployer, 10 ether);
        _dealPaired(deploymentParameters.tokenAddress, 10 ether);
        testRecoveryToken.mint(deploymentParameters.tokenAddress, 10 ether);

        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);
        StablePool pool = StablePool(tokenAddress);

        bytes4 expectedError = NO_ERROR;
        uint256 withdrawAmount = tokenAddress.balance;
        uint256 expectedDeployerBalance = deployer.balance + withdrawAmount;
        if (deploymentParameters.poolParams.pairedToken == address(0)) {
            expectedError = TokenMasterERC20__CannotWithdrawPairedToken.selector;
            expectedDeployerBalance = deployer.balance;
        }
        address alice = address(0xA11CE);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        pool.withdrawUnrelatedToken(address(0), alice, withdrawAmount);
        vm.stopPrank();
        vm.startPrank(deployer);
        if (expectedError == NO_ERROR) {
            vm.expectRevert(TokenMasterERC20__NativeTransferFailed.selector);
            pool.withdrawUnrelatedToken(address(0), deployer, withdrawAmount+1);
        } else {
            vm.expectRevert(expectedError);
        }
        pool.withdrawUnrelatedToken(address(0), deployer, withdrawAmount);
        assertEq(deployer.balance, expectedDeployerBalance);

        withdrawAmount = testRecoveryToken.balanceOf(tokenAddress);
        expectedDeployerBalance = testRecoveryToken.balanceOf(deployer) + withdrawAmount;
        vm.expectRevert();
        pool.withdrawUnrelatedToken(address(testRecoveryToken), deployer, withdrawAmount+1);
        pool.withdrawUnrelatedToken(address(testRecoveryToken), deployer, withdrawAmount);
        assertEq(testRecoveryToken.balanceOf(deployer), expectedDeployerBalance);
        vm.stopPrank();
    }

    function testRevertsWhenCallingDirectly() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;

        vm.expectRevert(TokenMasterFactory__CallerMustBeRouter.selector);
        ITokenMasterFactory(deploymentParameters.tokenFactory).deployToken(
            deploymentParameters.tokenSalt,
            deploymentParameters.poolParams,
            0,
            0
        );

        StablePool pool = StablePool(_deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR));

        vm.expectRevert(TokenMasterERC20__CallerMustBeRouter.selector);
        pool.buyTokens(address(0x5555), 1, 1);
        vm.expectRevert(TokenMasterERC20__CallerMustBeRouter.selector);
        pool.sellTokens(address(0x5555), 1, 1);
        vm.expectRevert(TokenMasterERC20__CallerMustBeRouter.selector);
        pool.spendTokens(address(0x5555), 1);
        vm.expectRevert(TokenMasterERC20__OperationNotSupportedByPool.selector);
        pool.transferCreatorShareToMarket(1, address(0x5555), address(0x6666));
    }

    function testRevertsDeployWhenValueCannotTransfer() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        vm.deal(deployer, 10 ether);
        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);
        
        bytes4 errorSelector = TokenMasterRouter__FailedToDepositInitialPairedFunds.selector;
        if (deploymentParameters.poolParams.pairedToken != address(0)) {
            errorSelector = TokenMasterRouter__NativeValueNotAllowedOnERC20.selector;
        }
        _deployTokenOverrideValue(
            deployer,
            deploymentParameters.poolParams.initialPairedTokenToDeposit,
            deploymentParameters,
            emptySignature,
            errorSelector
        );
    }

    function testDeployWithSigningAuthority() public {
        address deployer = address(0x4444);

        uint256 signerKey = uint256(TOKENMASTER_SIGNER_BASE_ROLE);
        address signerAddress = vm.addr(signerKey);
        vm.startPrank(TOKENMASTER_ADMIN);
        IRoleClient[] memory clients = new IRoleClient[](0);
        roleServer.setRoleHolder(roleSet, TOKENMASTER_SIGNER_BASE_ROLE, signerAddress, true, clients);
        vm.stopPrank();

        vm.warp(block.timestamp + 1);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory deploymentSignature; 
        //test empty signature, expect revert
        _deployToken(deployer, deploymentParameters, deploymentSignature, TokenMasterRouter__InvalidDeploymentSignature.selector);
        
        deploymentSignature = _signDeploymentParameters(signerKey, deploymentParameters);
        _deployToken(deployer, deploymentParameters, deploymentSignature, NO_ERROR);
    }

    function testRevertsDeployWhenFactoryNotAllowed() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        initializationParams = _defaultInitializationParameters();
        deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.tokenFactory = address(0x9090);
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__TokenFactoryNotAllowed.selector);
    }

    function testRevertsDeployWhenInfraFeeExceedsMax() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        initializationParams = _defaultInitializationParameters();
        deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.tokenSalt = bytes32(uint256(0x0A));
        deploymentParameters.maxInfrastructureFeeBPS = tokenMasterRouter.infrastructureFeeBPS() - 1;
        _updateDeploymentAddress(deploymentParameters);
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__InvalidInfrastructureFeeBPS.selector);
    }

    function testRevertsDeployWithInvalidValue() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);

        vm.deal(deployer, 10 ether);
        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;

        _updateDeploymentAddress(deploymentParameters);
        bytes4 errorSelector = TokenMasterRouter__InvalidMessageValue.selector;
        if (deploymentParameters.poolParams.pairedToken != address(0)) {
            errorSelector = TokenMasterRouter__NativeValueNotAllowedOnERC20.selector;
        }
        _deployTokenOverrideValue(
            deployer,
            deploymentParameters.poolParams.initialPairedTokenToDeposit + 1,
            deploymentParameters,
            emptySignature,
            errorSelector
        );
    }

    function testRevertsWhenInitializationParametersAreInvalid() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        initializationParams = _defaultInitializationParameters();
        initializationParams.maxBuyFeeBPS = BPS + 1;
        deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__DeployedTokenAddressMismatch.selector);

        initializationParams = _defaultInitializationParameters();
        initializationParams.maxSellFeeBPS = BPS + 1;
        deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__DeployedTokenAddressMismatch.selector);

        initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = uint256(type(uint128).max) + 1;
        deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__DeployedTokenAddressMismatch.selector);

        initializationParams = _defaultInitializationParameters();
        initializationParams.initialBuyParameters.buyFeeBPS = uint16(initializationParams.maxBuyFeeBPS + 1);
        deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__DeployedTokenAddressMismatch.selector);

        initializationParams = _defaultInitializationParameters();
        initializationParams.initialSellParameters.sellFeeBPS = uint16(initializationParams.maxSellFeeBPS + 1);
        deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__DeployedTokenAddressMismatch.selector);

        initializationParams = _defaultInitializationParameters();
        deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.partnerFeeBPS = BPS + 1;
        deploymentParameters.poolParams.partnerFeeRecipient = address(0xAAAA);
        _updateDeploymentAddress(deploymentParameters);
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__DeployedTokenAddressMismatch.selector);

        initializationParams = _defaultInitializationParameters();
        deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = address(0);
        _updateDeploymentAddress(deploymentParameters);
        _deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__DeployedTokenAddressMismatch.selector);
    }

    function testParametersMatchDeployedSettings() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        assertEq(StablePool(tokenAddress).decimals(), deploymentParameters.poolParams.tokenDecimals);

        StablePoolBuyParameters memory currentBuyParameters = IStablePool(tokenAddress).getBuyParameters();
        StablePoolSellParameters memory currentSellParameters = IStablePool(tokenAddress).getSellParameters();

        assertEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );
        assertEq(
            keccak256(abi.encode(currentSellParameters)),
            keccak256(abi.encode(initializationParams.initialSellParameters))
        );

        initializationParams.initialBuyParameters.buyFeeBPS += 1;
        initializationParams.initialSellParameters.sellFeeBPS += 1;
        assertNotEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );
        assertNotEq(
            keccak256(abi.encode(currentSellParameters)),
            keccak256(abi.encode(initializationParams.initialSellParameters))
        );

        (uint16 maxBuyFeeBPS, uint16 maxSellFeeBPS) = IStablePool(tokenAddress).getParameterGuardrails();
        assertEq(initializationParams.maxBuyFeeBPS, maxBuyFeeBPS);
        assertEq(initializationParams.maxSellFeeBPS, maxSellFeeBPS);
    }

    function testOwnerCanUpdateParameters() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        initializationParams.initialBuyParameters.buyFeeBPS += 1;
        initializationParams.initialSellParameters.sellFeeBPS += 1;
        vm.startPrank(deployer);
        vm.expectEmit(true,true,true,true);
        emit IStablePool.BuyParametersUpdated();
        StablePool(tokenAddress).setBuyParameters(initializationParams.initialBuyParameters);
        vm.expectEmit(true,true,true,true);
        emit IStablePool.SellParametersUpdated();
        StablePool(tokenAddress).setSellParameters(initializationParams.initialSellParameters);
        vm.stopPrank();

        StablePoolBuyParameters memory currentBuyParameters = IStablePool(tokenAddress).getBuyParameters();
        StablePoolSellParameters memory currentSellParameters = IStablePool(tokenAddress).getSellParameters();

        assertEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );
        assertEq(
            keccak256(abi.encode(currentSellParameters)),
            keccak256(abi.encode(initializationParams.initialSellParameters))
        );

        initializationParams.initialBuyParameters.buyFeeBPS += 1;
        initializationParams.initialSellParameters.sellFeeBPS += 1;
        assertNotEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );
        assertNotEq(
            keccak256(abi.encode(currentSellParameters)),
            keccak256(abi.encode(initializationParams.initialSellParameters))
        );
    }

    function testRevertsWhenNonOwnerSetsParameters() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        initializationParams.initialBuyParameters.buyFeeBPS += 1;
        initializationParams.initialSellParameters.sellFeeBPS += 1;
        address alice = address(0xA11CE);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        StablePool(tokenAddress).setBuyParameters(initializationParams.initialBuyParameters);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        StablePool(tokenAddress).setSellParameters(initializationParams.initialSellParameters);
        vm.stopPrank();

        StablePoolBuyParameters memory currentBuyParameters = IStablePool(tokenAddress).getBuyParameters();
        StablePoolSellParameters memory currentSellParameters = IStablePool(tokenAddress).getSellParameters();
        
        assertNotEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );
        assertNotEq(
            keccak256(abi.encode(currentSellParameters)),
            keccak256(abi.encode(initializationParams.initialSellParameters))
        );

        initializationParams = _defaultInitializationParameters();

        assertEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );
        assertEq(
            keccak256(abi.encode(currentSellParameters)),
            keccak256(abi.encode(initializationParams.initialSellParameters))
        );
    }

    function testTrades() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 10 ether);
        _buyTokens(traderKey, trader, StablePool(tokenAddress), 5 ether, 0.0004 ether, 0.0004 ether, block.timestamp, TokenMasterERC20__InsufficientBuyInput.selector);
        _buyTokens(traderKey, trader, StablePool(tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        _sellTokens(traderKey, trader, StablePool(tokenAddress), 5 ether, 6 ether, TokenMasterERC20__InsufficientSellOutput.selector);
        _sellTokens(traderKey, trader, StablePool(tokenAddress), 5 ether, 4 ether, NO_ERROR);

        traderKey = uint256(0xBBBB);
        trader = vm.addr(traderKey);
        _dealPaired(trader, type(uint160).max);
        _buyTokens(traderKey, trader, StablePool(tokenAddress), type(uint144).max, type(uint152).max, type(uint152).max, block.timestamp, TokenMasterERC20__InvalidPairedValues.selector);
    }

    struct TestTransferTmps {
        address deployer;
        address partner;
        uint256 marketBefore;
        uint256 creatorBefore;
        uint256 infraBefore;
        uint256 partnerBefore;
        uint256 deployerBalanceBefore;
        uint256 infraBalanceBefore;
        uint256 partnerBalanceBefore;
        address newPartner;
        uint256 newPartnerBalanceBefore;
    }

    function testWithdrawPartialCreatorShare() public {
        TestTransferTmps memory tmps;
        tmps.deployer = address(0x4444);
        tmps.partner = address(0xCCCC);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        StablePool pool = StablePool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);
        _sellTokens(traderKey, trader, pool, 5 ether, 0 ether, NO_ERROR);

        uint256 marketShare;
        uint256 creatorShare;
        uint256 infrastructureShare;
        uint256 partnerShare;
        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        tmps.marketBefore = marketShare;
        tmps.deployerBalanceBefore = _pairedBalance(tmps.deployer);
        tmps.infraBefore = _pairedBalance(FEE_RECIPIENT);
        tmps.partnerBefore = _pairedBalance(tmps.partner);

        TestTransferTmps memory tmpTmps = tmps;
        uint256 withdrawAmount = creatorShare / 2;
        uint256 creatorRemaining = creatorShare - withdrawAmount;
        vm.startPrank(tmpTmps.partner);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.withdrawCreatorShare(pool, tmpTmps.deployer, withdrawAmount);
        vm.stopPrank();
        vm.startPrank(tmpTmps.deployer);
        tokenMasterRouter.withdrawCreatorShare(pool, tmpTmps.deployer, withdrawAmount);
        vm.stopPrank();

        assertEq(tmpTmps.infraBefore + infrastructureShare, _pairedBalance(FEE_RECIPIENT));
        assertEq(tmpTmps.partnerBefore + partnerShare, _pairedBalance(tmpTmps.partner));
        assertEq(tmpTmps.deployerBalanceBefore + withdrawAmount, _pairedBalance(tmpTmps.deployer));

        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        assertEq(marketShare, tmpTmps.marketBefore);
        assertEq(creatorShare, creatorRemaining);
        assertEq(infrastructureShare, 0);
        assertEq(partnerShare, 0);
    }

    function testWithdrawFullCreatorShare() public {
        TestTransferTmps memory tmps;
        tmps.deployer = address(0x4444);
        tmps.partner = address(0xCCCC);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        StablePool pool = StablePool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);
        _sellTokens(traderKey, trader, pool, 5 ether, 0 ether, NO_ERROR);

        uint256 marketShare;
        uint256 creatorShare;
        uint256 infrastructureShare;
        uint256 partnerShare;
        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        tmps.marketBefore = marketShare;
        tmps.deployerBalanceBefore = _pairedBalance(tmps.deployer);
        tmps.infraBefore = _pairedBalance(FEE_RECIPIENT);
        tmps.partnerBefore = _pairedBalance(tmps.partner);

        TestTransferTmps memory tmpTmps = tmps;
        uint256 withdrawAmount = creatorShare;
        uint256 creatorRemaining = creatorShare - withdrawAmount;
        vm.startPrank(tmpTmps.partner);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.withdrawCreatorShare(pool, tmpTmps.deployer, withdrawAmount);
        vm.stopPrank();
        vm.startPrank(tmpTmps.deployer);
        tokenMasterRouter.withdrawCreatorShare(pool, tmpTmps.deployer, withdrawAmount);
        vm.stopPrank();

        assertEq(tmpTmps.infraBefore + infrastructureShare, _pairedBalance(FEE_RECIPIENT));
        assertEq(tmpTmps.partnerBefore + partnerShare, _pairedBalance(tmpTmps.partner));
        assertEq(tmpTmps.deployerBalanceBefore + withdrawAmount, _pairedBalance(tmpTmps.deployer));

        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        assertEq(marketShare, tmpTmps.marketBefore);
        assertEq(creatorShare, creatorRemaining);
        assertEq(infrastructureShare, 0);
        assertEq(partnerShare, 0);
    }

    function testRevertsWhenWithdrawingExcessCreatorShare() public {
        TestTransferTmps memory tmps;
        tmps.deployer = address(0x4444);
        tmps.partner = address(0xCCCC);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        StablePool pool = StablePool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);
        _sellTokens(traderKey, trader, pool, 5 ether, 0 ether, NO_ERROR);

        uint256 marketShare;
        uint256 creatorShare;
        uint256 infrastructureShare;
        uint256 partnerShare;
        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        tmps.marketBefore = marketShare;
        tmps.creatorBefore = creatorShare;
        tmps.infraBefore = infrastructureShare;
        tmps.partnerBefore = partnerShare;
        tmps.deployerBalanceBefore = _pairedBalance(tmps.deployer);
        tmps.infraBalanceBefore = _pairedBalance(FEE_RECIPIENT);
        tmps.partnerBalanceBefore = _pairedBalance(tmps.partner);

        uint256 withdrawAmount = creatorShare + 1;
        vm.startPrank(tmps.deployer);
        vm.expectRevert(TokenMasterERC20__WithdrawOrTransferAmountGreaterThanShare.selector);
        tokenMasterRouter.withdrawCreatorShare(pool, tmps.deployer, withdrawAmount);
        vm.stopPrank();

        assertEq(tmps.infraBalanceBefore, _pairedBalance(FEE_RECIPIENT));
        assertEq(tmps.partnerBalanceBefore, _pairedBalance(tmps.partner));
        assertEq(tmps.deployerBalanceBefore, _pairedBalance(tmps.deployer));

        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        assertEq(marketShare, tmps.marketBefore);
        assertEq(creatorShare, tmps.creatorBefore);
        assertEq(infrastructureShare, tmps.infraBefore);
        assertEq(partnerShare, tmps.partnerBefore);
    }

    function testRevertsWhenTransferringExcessCreatorShareToMarket() public {
        TestTransferTmps memory tmps;
        tmps.deployer = address(0x4444);
        tmps.partner = address(0xCCCC);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        StablePool pool = StablePool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);
        _sellTokens(traderKey, trader, pool, 5 ether, 0 ether, NO_ERROR);

        uint256 marketShare;
        uint256 creatorShare;
        uint256 infrastructureShare;
        uint256 partnerShare;
        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        tmps.marketBefore = marketShare;
        tmps.creatorBefore = creatorShare;
        tmps.infraBefore = infrastructureShare;
        tmps.partnerBefore = partnerShare;
        tmps.deployerBalanceBefore = _pairedBalance(tmps.deployer);
        tmps.infraBalanceBefore = _pairedBalance(FEE_RECIPIENT);
        tmps.partnerBalanceBefore = _pairedBalance(tmps.partner);

        uint256 transferAmount = creatorShare + 1;
        vm.startPrank(tmps.deployer);
        vm.expectRevert(TokenMasterERC20__OperationNotSupportedByPool.selector);
        tokenMasterRouter.transferCreatorShareToMarket(pool, transferAmount);
        vm.stopPrank();

        assertEq(tmps.infraBalanceBefore, _pairedBalance(FEE_RECIPIENT));
        assertEq(tmps.partnerBalanceBefore, _pairedBalance(tmps.partner));
        assertEq(tmps.deployerBalanceBefore, _pairedBalance(tmps.deployer));

        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        assertEq(marketShare, tmps.marketBefore);
        assertEq(creatorShare, tmps.creatorBefore);
        assertEq(infrastructureShare, tmps.infraBefore);
        assertEq(partnerShare, tmps.partnerBefore);
    }

    function testWithdrawFeesByPartner() public {
        TestTransferTmps memory tmps;
        tmps.deployer = address(0x4444);
        tmps.partner = address(0xCCCC);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        StablePool pool = StablePool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);
        _sellTokens(traderKey, trader, pool, 5 ether, 0 ether, NO_ERROR);

        uint256 marketShare;
        uint256 creatorShare;
        uint256 infrastructureShare;
        uint256 partnerShare;
        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        tmps.marketBefore = marketShare;
        tmps.deployerBalanceBefore = _pairedBalance(tmps.deployer);
        tmps.infraBefore = _pairedBalance(FEE_RECIPIENT);
        tmps.partnerBefore = _pairedBalance(tmps.partner);

        uint256 creatorRemaining = creatorShare;
        vm.startPrank(tmps.deployer);
        vm.expectRevert(TokenMasterRouter__CallerNotAllowed.selector);
        ITokenMasterERC20C[] memory pools = new ITokenMasterERC20C[](1);
        pools[0] = pool;
        tokenMasterRouter.withdrawFees(pools);
        vm.stopPrank();
        vm.startPrank(tmps.partner);
        tokenMasterRouter.withdrawFees(pools);
        vm.stopPrank();

        TestTransferTmps memory tmpTmps = tmps;
        assertEq(tmpTmps.infraBefore + infrastructureShare, _pairedBalance(FEE_RECIPIENT));
        assertEq(tmpTmps.partnerBefore + partnerShare, _pairedBalance(tmpTmps.partner));
        assertEq(tmpTmps.deployerBalanceBefore, _pairedBalance(tmpTmps.deployer));

        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        assertEq(marketShare, tmpTmps.marketBefore);
        assertEq(creatorShare, creatorRemaining);
        assertEq(infrastructureShare, 0);
        assertEq(partnerShare, 0);
    }

    function testWithdrawFeesByPartnerToNewPartnerFeeReceiver() public {
        TestTransferTmps memory tmps;
        tmps.deployer = address(0x4444);
        tmps.partner = address(0xCCCC);
        tmps.newPartner = address(0xDEDE);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        StablePool pool = StablePool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);
        _sellTokens(traderKey, trader, pool, 5 ether, 0 ether, NO_ERROR);

        uint256 marketShare;
        uint256 creatorShare;
        uint256 infrastructureShare;
        uint256 partnerShare;
        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        tmps.marketBefore = marketShare;
        tmps.deployerBalanceBefore = _pairedBalance(tmps.deployer);
        tmps.infraBefore = _pairedBalance(FEE_RECIPIENT);
        tmps.partnerBefore = _pairedBalance(tmps.partner);
        tmps.newPartnerBalanceBefore = _pairedBalance(tmps.newPartner);

        vm.startPrank(tmps.deployer);
        vm.expectRevert(TokenMasterRouter__InvalidRecipient.selector);
        tokenMasterRouter.acceptProposedPartnerFeeReceiver(tokenAddress, tmps.newPartner);
        vm.expectRevert(TokenMasterRouter__CallerNotAllowed.selector);
        tokenMasterRouter.partnerProposeFeeReceiver(tokenAddress, tmps.newPartner);
        vm.stopPrank();
        vm.startPrank(tmps.partner);
        vm.expectEmit(true,true,true,true);
        emit ITokenMasterRouter.PartnerFeeRecipientProposed(tokenAddress, tmps.newPartner);
        tokenMasterRouter.partnerProposeFeeReceiver(tokenAddress, tmps.newPartner);
        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.acceptProposedPartnerFeeReceiver(tokenAddress, tmps.newPartner);
        vm.stopPrank();
        vm.startPrank(tmps.deployer);
        vm.expectRevert(TokenMasterRouter__InvalidRecipient.selector);
        tokenMasterRouter.acceptProposedPartnerFeeReceiver(tokenAddress, address(0x0BAD));
        vm.expectEmit(true,true,true,true);
        emit ITokenMasterRouter.PartnerFeeRecipientUpdated(tokenAddress, tmps.newPartner);
        tokenMasterRouter.acceptProposedPartnerFeeReceiver(tokenAddress, tmps.newPartner);
        vm.stopPrank();

        uint256 creatorRemaining = creatorShare;
        vm.startPrank(tmps.deployer);
        vm.expectRevert(TokenMasterRouter__CallerNotAllowed.selector);
        ITokenMasterERC20C[] memory pools = new ITokenMasterERC20C[](1);
        pools[0] = pool;
        tokenMasterRouter.withdrawFees(pools);
        vm.stopPrank();
        vm.startPrank(tmps.newPartner);
        tokenMasterRouter.withdrawFees(pools);
        vm.stopPrank();

        TestTransferTmps memory tmpTmps = tmps;
        assertEq(tmpTmps.infraBefore + infrastructureShare, _pairedBalance(FEE_RECIPIENT));
        assertEq(tmpTmps.partnerBefore, _pairedBalance(tmpTmps.partner));
        assertEq(tmpTmps.newPartnerBalanceBefore + partnerShare, _pairedBalance(tmpTmps.newPartner));
        assertEq(tmpTmps.deployerBalanceBefore, _pairedBalance(tmpTmps.deployer));

        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        assertEq(marketShare, tmpTmps.marketBefore);
        assertEq(creatorShare, creatorRemaining);
        assertEq(infrastructureShare, 0);
        assertEq(partnerShare, 0);
    }

    function testWithdrawFeesByFeeCollector() public {
        TestTransferTmps memory tmps;
        tmps.deployer = address(0x4444);
        tmps.partner = address(0xCCCC);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        StablePool pool = StablePool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);
        _sellTokens(traderKey, trader, pool, 5 ether, 0 ether, NO_ERROR);

        uint256 marketShare;
        uint256 creatorShare;
        uint256 infrastructureShare;
        uint256 partnerShare;
        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        tmps.marketBefore = marketShare;
        tmps.deployerBalanceBefore = _pairedBalance(tmps.deployer);
        tmps.infraBefore = _pairedBalance(FEE_RECIPIENT);
        tmps.partnerBefore = _pairedBalance(tmps.partner);

        uint256 creatorRemaining = creatorShare;
        vm.startPrank(tmps.deployer);
        vm.expectRevert(TokenMasterRouter__CallerNotAllowed.selector);
        ITokenMasterERC20C[] memory pools = new ITokenMasterERC20C[](1);
        pools[0] = pool;
        tokenMasterRouter.withdrawFees(pools);
        vm.stopPrank();
        vm.startPrank(FEE_COLLECTOR);
        tokenMasterRouter.withdrawFees(pools);
        vm.stopPrank();

        TestTransferTmps memory tmpTmps = tmps;
        assertEq(tmpTmps.infraBefore + infrastructureShare, _pairedBalance(FEE_RECIPIENT));
        assertEq(tmpTmps.partnerBefore + partnerShare, _pairedBalance(tmpTmps.partner));
        assertEq(tmpTmps.deployerBalanceBefore, _pairedBalance(tmpTmps.deployer));

        (
            marketShare,
            creatorShare,
            infrastructureShare,
            partnerShare
        ) = pool.pairedTokenShares();

        assertEq(marketShare, tmpTmps.marketBefore);
        assertEq(creatorShare, creatorRemaining);
        assertEq(infrastructureShare, 0);
        assertEq(partnerShare, 0);
    }

    function testSupportsInterface() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        uint256 blockTime = 0;
        vm.warp(blockTime);
        StablePool pool = StablePool(_deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR));

        assertTrue(pool.supportsInterface(type(IStablePool).interfaceId));
        assertTrue(pool.supportsInterface(type(ITokenMasterERC20C).interfaceId));
        assertTrue(pool.supportsInterface(type(IERC20).interfaceId));
        assertTrue(pool.supportsInterface(type(IERC20Metadata).interfaceId));
        assertTrue(pool.supportsInterface(type(ICreatorToken).interfaceId));
        assertTrue(pool.supportsInterface(type(ICreatorTokenLegacy).interfaceId));
        assertTrue(pool.supportsInterface(type(IERC165).interfaceId));

        console.log("ITokenMasterERC20C.interfaceId: ");
        console.logBytes4(type(ITokenMasterERC20C).interfaceId);
        console.log("IStablePool.interfaceId: ");
        console.logBytes4(type(IStablePool).interfaceId);
    }

    function testRevertsWhenRenouncingOwnership() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        StablePool pool = StablePool(_deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR));

        vm.expectRevert(TokenMasterERC20__RenounceNotAllowed.selector);
        vm.prank(deployer);
        pool.renounceOwnership();
    }

    function testRevertsWhenInitialPairedValueInIsZero() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 0;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        StablePool(_deployToken(deployer, deploymentParameters, emptySignature, TokenMasterRouter__DeployedTokenAddressMismatch.selector));
    }

    function _defaultInitializationParameters() internal view returns (StablePoolInitializationParameters memory initializationParams) {
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

    function _defaultDeploymentParameters(
        address initialOwner,
        StablePoolInitializationParameters memory initializationParams
    ) internal view virtual returns (DeploymentParameters memory deploymentParameters) {
        bytes memory args = abi.encode(initializationParams);

        deploymentParameters.tokenFactory = address(stablePoolFactory);
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
        StablePool pool;
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
        StablePool pool,
        uint256 tokensToBuy, 
        uint256 pairedValueIn,
        uint256 msgValue,
        uint256 /*timestamp*/,
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

        (uint96 priceNumerator, uint96 priceDenominator) = buyTmps.pool.getStablePriceRatio();
        
        StablePoolBuyParameters memory buyParameters = IStablePool(address(pool)).getBuyParameters();
        uint16 buyFeeBPS = buyParameters.buyFeeBPS;

        uint256 marketValueShare = buyTmps.tokensToBuy * priceNumerator / priceDenominator;
        uint256 revenueShare = 
            (marketValueShare * buyFeeBPS / BPS);

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
        StablePool pool;
        uint256 marketShareBefore;
        uint256 revenueShareBefore;
        uint256 sellerTokenBalanceBefore;
    }
    function _sellTokens(
        uint256 sellerKey,
        address seller, 
        StablePool pool,
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

        StablePoolSellParameters memory sellParams = sellTmps.pool.getSellParameters();

        (uint96 priceNumerator, uint96 priceDenominator) = sellTmps.pool.getStablePriceRatio();
        
        uint256 pairedTokenValue = (tokensToSell * priceNumerator / priceDenominator);
        uint256 pairedValueFromMarket = pairedTokenValue;
        uint256 expectedSellerProceeds = 
            pairedTokenValue * 
            (BPS - sellParams.sellFeeBPS) / BPS;
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

    function _dealPaired(address account, uint256 amount) internal virtual {
        vm.deal(account, amount);
    }

    function _pairedBalance(address account) internal view virtual returns (uint256) {
        return account.balance;
    }
}