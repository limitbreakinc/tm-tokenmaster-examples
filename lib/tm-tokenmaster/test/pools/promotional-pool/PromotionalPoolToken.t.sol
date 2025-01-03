// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "../../TokenMasterToken.t.sol";
import "src/pools/promotional-pool/IPromotionalPool.sol";
import "src/pools/promotional-pool/PromotionalPool.sol";
import "@limitbreak/tm-core-lib/src/utils/access/Ownable.sol";
import "../../mocks/MockPairedTokenERC20.sol";

contract PromotionalPoolTokenTest is TokenMasterTokenTest {
    MockPairedTokenERC20 internal testRecoveryToken;

    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 private constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function setUp() public virtual override {
        super.setUp();

        testRecoveryToken = new MockPairedTokenERC20("Test Recovery", "TR", 18);
    }

    function testMinterBurnerRoles() public {
        address deployer = address(0x4444);

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);
        PromotionalPool pool = PromotionalPool(tokenAddress);

        address minter = address(0x444144732);
        address burner = address(0xB624432);
        
        vm.startPrank(minter);
        vm.expectRevert();
        pool.grantRole(MINTER_ROLE, minter);
        vm.stopPrank();
        vm.startPrank(deployer);
        pool.grantRole(MINTER_ROLE, minter);
        pool.grantRole(BURNER_ROLE, burner);
        vm.stopPrank();

        address recipient = address(0x4141);
        uint256 recipientBalanceBefore = pool.balanceOf(recipient);
        vm.expectRevert();
        pool.mint(recipient, 1 ether);
        vm.startPrank(minter);
        pool.mint(recipient, 1 ether);
        vm.stopPrank();
        assertEq(recipientBalanceBefore + 1 ether, pool.balanceOf(recipient));
        recipientBalanceBefore = pool.balanceOf(recipient);
        vm.expectRevert();
        pool.burn(recipient, 0.5 ether);
        vm.startPrank(burner);
        pool.burn(recipient, 0.5 ether);
        vm.stopPrank();
        assertEq(recipientBalanceBefore - 0.5 ether, pool.balanceOf(recipient));

        address[] memory recipients = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        uint256[] memory balancesBefore = new uint256[](3);
        bytes32 seed = bytes32(uint256(0x533D));
        for (uint256 i; i < 3; ++i) {
            seed = keccak256(abi.encode(seed));
            recipients[i] = address(uint160(uint256(seed)));
            seed = keccak256(abi.encode(seed));
            amounts[i] = uint256(keccak256(abi.encode(seed))) % type(uint248).max;
            balancesBefore[i] = pool.balanceOf(recipients[i]);
        }
        vm.expectRevert();
        pool.mintBatch(recipients, amounts);
        vm.startPrank(minter);
        pool.mintBatch(recipients, amounts);
        vm.stopPrank();

        for (uint256 i; i < 3; ++i) {
            uint256 received = pool.balanceOf(recipients[i]) - balancesBefore[i];
            assertEq(received, amounts[i]);
        }

        uint256[] memory mismatchAmounts = new uint256[](4);
        vm.startPrank(minter);
        vm.expectRevert(TokenMasterERC20__ArrayLengthMismatch.selector);
        pool.mintBatch(recipients, mismatchAmounts);
        vm.stopPrank();
    }

    function testOrderSignerList() public {
        address deployer = address(0x4444);

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        vm.deal(deployer, 10 ether);
        vm.deal(deploymentParameters.tokenAddress, 10 ether);
        _dealPaired(deployer, 10 ether);
        _dealPaired(deploymentParameters.tokenAddress, 10 ether);
        testRecoveryToken.mint(deploymentParameters.tokenAddress, 10 ether);

        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);
        PromotionalPool pool = PromotionalPool(tokenAddress);

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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        PromotionalPool pool = PromotionalPool(_deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR));

        vm.expectRevert(TokenMasterERC20__CallerMustBeRouter.selector);
        pool.buyTokens(address(0x5555), 1, 1);
        vm.expectRevert(TokenMasterERC20__OperationNotSupportedByPool.selector);
        pool.sellTokens(address(0x5555), 1, 1);
        vm.expectRevert(TokenMasterERC20__CallerMustBeRouter.selector);
        pool.spendTokens(address(0x5555), 1);
        vm.expectRevert(TokenMasterERC20__OperationNotSupportedByPool.selector);
        pool.transferCreatorShareToMarket(1, address(0x5555), address(0x6666));
    }

    function testRevertsDeployWhenValueCannotTransfer() public {
        address deployer = address(0x4444);

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        vm.deal(deployer, 10 ether);
        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);
        
        bytes4 errorSelector = TokenMasterRouter__InvalidMessageValue.selector;
        if (deploymentParameters.poolParams.pairedToken != address(0)) {
            errorSelector = TokenMasterRouter__NativeValueNotAllowedOnERC20.selector;
        }
        _deployTokenOverrideValue(
            deployer,
            1 ether,
            deploymentParameters,
            emptySignature,
            errorSelector
        );
    }

    function testRevertsDeployWithValueIn() public {
        address deployer = address(0x4444);

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.poolParams.initialPairedTokenToDeposit = 1 ether;
        _updateDeploymentAddress(deploymentParameters);

        vm.deal(deployer, 10 ether);
        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        
        bytes4 errorSelector = TokenMasterRouter__DeployedTokenAddressMismatch.selector;
        if (deploymentParameters.poolParams.pairedToken != address(0)) {
            _deployTokenOverrideValue(
                deployer,
                0 ether,
                deploymentParameters,
                emptySignature,
                errorSelector
            );
        } else {
            _deployTokenOverrideValue(
                deployer,
                deploymentParameters.poolParams.initialPairedTokenToDeposit,
                deploymentParameters,
                emptySignature,
                errorSelector
            );
        }
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        initializationParams = _defaultInitializationParameters();
        initializationParams.initialBuyParameters.buyCostPoolTokenDenominator = 0;
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        assertEq(PromotionalPool(tokenAddress).decimals(), deploymentParameters.poolParams.tokenDecimals);

        PromotionalPoolBuyParameters memory currentBuyParameters = IPromotionalPool(tokenAddress).getBuyParameters();

        assertEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );

        initializationParams.initialBuyParameters.buyCostPairedTokenNumerator += 1;
        assertNotEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );
    }

    function testOwnerCanUpdateParameters() public {
        address deployer = address(0x4444);

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        initializationParams.initialBuyParameters.buyCostPairedTokenNumerator += 1;
        initializationParams.initialBuyParameters.buyCostPoolTokenDenominator += 1;
        vm.startPrank(deployer);
        vm.expectEmit(true,true,true,true);
        emit IPromotionalPool.BuyParametersUpdated();
        PromotionalPool(tokenAddress).setBuyParameters(initializationParams.initialBuyParameters);
        vm.stopPrank();

        PromotionalPoolBuyParameters memory currentBuyParameters = IPromotionalPool(tokenAddress).getBuyParameters();

        assertEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );

        initializationParams.initialBuyParameters.buyCostPairedTokenNumerator += 1;
        assertNotEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );
    }

    function testRevertsWhenNonOwnerSetsParameters() public {
        address deployer = address(0x4444);

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        initializationParams.initialBuyParameters.buyCostPairedTokenNumerator += 1;
        address alice = address(0xA11CE);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        PromotionalPool(tokenAddress).setBuyParameters(initializationParams.initialBuyParameters);
        vm.stopPrank();

        PromotionalPoolBuyParameters memory currentBuyParameters = IPromotionalPool(tokenAddress).getBuyParameters();
        
        assertNotEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );

        initializationParams = _defaultInitializationParameters();

        assertEq(
            keccak256(abi.encode(currentBuyParameters)),
            keccak256(abi.encode(initializationParams.initialBuyParameters))
        );
    }

    function testTrades() public {
        address deployer = address(0x4444);

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 10 ether);
        _buyTokens(traderKey, trader, PromotionalPool(tokenAddress), 500 ether, 0.0004 ether, 0.0004 ether, block.timestamp, TokenMasterERC20__InsufficientBuyInput.selector);
        _buyTokens(traderKey, trader, PromotionalPool(tokenAddress), 5 ether, 6 ether, 6 ether, block.timestamp, NO_ERROR);

        vm.expectRevert(TokenMasterERC20__OperationNotSupportedByPool.selector);
        PromotionalPool(tokenAddress).sellTokens(trader, 1, 1);
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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        PromotionalPool pool = PromotionalPool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);

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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        PromotionalPool pool = PromotionalPool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);

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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        PromotionalPool pool = PromotionalPool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);

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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        PromotionalPool pool = PromotionalPool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);

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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        PromotionalPool pool = PromotionalPool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);

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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        PromotionalPool pool = PromotionalPool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);

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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 1 ether;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(tmps.deployer, initializationParams);
        deploymentParameters.poolParams.partnerFeeBPS = 100;
        deploymentParameters.poolParams.partnerFeeRecipient = tmps.partner;
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(tmps.deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        address tokenAddress = _deployToken(tmps.deployer, deploymentParameters, emptySignature, NO_ERROR);
        PromotionalPool pool = PromotionalPool(tokenAddress);

        uint256 traderKey = 0x5555;
        address trader = vm.addr(traderKey);
        _dealPaired(trader, 1000 ether);
        _buyTokens(traderKey, trader, pool, 5 ether, 10 ether, 10 ether, block.timestamp, NO_ERROR);

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

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        uint256 blockTime = 0;
        vm.warp(blockTime);
        PromotionalPool pool = PromotionalPool(_deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR));

        assertTrue(pool.supportsInterface(type(IPromotionalPool).interfaceId));
        assertTrue(pool.supportsInterface(type(IMinterBurnerRolePool).interfaceId));
        assertTrue(pool.supportsInterface(type(ITokenMasterERC20C).interfaceId));
        assertTrue(pool.supportsInterface(type(IERC20).interfaceId));
        assertTrue(pool.supportsInterface(type(IERC20Metadata).interfaceId));
        assertTrue(pool.supportsInterface(type(ICreatorToken).interfaceId));
        assertTrue(pool.supportsInterface(type(ICreatorTokenLegacy).interfaceId));
        assertTrue(pool.supportsInterface(type(IERC165).interfaceId));

        console.log("ITokenMasterERC20C.interfaceId: ");
        console.logBytes4(type(ITokenMasterERC20C).interfaceId);
        console.log("IPromotionalPool.interfaceId: ");
        console.logBytes4(type(IPromotionalPool).interfaceId);
        console.log("IMinterBurnerRolePool.interfaceId: ");
        console.logBytes4(type(IMinterBurnerRolePool).interfaceId);
    }

    function testRevertsWhenRenouncingOwnership() public {
        address deployer = address(0x4444);

        PromotionalPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        _updateDeploymentAddress(deploymentParameters);

        _dealPaired(deployer, 10 ether);
        SignatureECDSA memory emptySignature;
        PromotionalPool pool = PromotionalPool(_deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR));

        vm.expectRevert(TokenMasterERC20__RenounceNotAllowed.selector);
        vm.prank(deployer);
        pool.renounceOwnership();
    }

    function _defaultInitializationParameters() internal view returns (PromotionalPoolInitializationParameters memory initializationParams) {
        initializationParams.initialSupplyRecipient = address(this);
        initializationParams.initialSupplyAmount = 100 ether;
        initializationParams.initialBuyParameters = PromotionalPoolBuyParameters({
            buyCostPairedTokenNumerator: 1,
            buyCostPoolTokenDenominator: 100
        });
    }

    function _defaultDeploymentParameters(
        address initialOwner,
        PromotionalPoolInitializationParameters memory initializationParams
    ) internal view virtual returns (DeploymentParameters memory deploymentParameters) {
        bytes memory args = abi.encode(initializationParams);

        deploymentParameters.tokenFactory = address(promotionalPoolFactory);
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
            initialPairedTokenToDeposit: 0 ether,
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
        if (deploymentParameters.poolParams.pairedToken != address(0)) {
            vm.startPrank(deployer);
            IERC20(deploymentParameters.poolParams.pairedToken).approve(address(tokenMasterRouter), type(uint256).max);
            vm.stopPrank();
        }
        return _executeDeployToken(deployer, 0, deploymentParameters, signature, errorSelector);
    }

    function _deployTokenOverrideValue(
        address deployer,
        uint256 msgValue,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal virtual returns (address tokenAddress) {
        if (deploymentParameters.poolParams.pairedToken != address(0)) {
            vm.startPrank(deployer);
            IERC20(deploymentParameters.poolParams.pairedToken).approve(address(tokenMasterRouter), type(uint256).max);
            vm.stopPrank();
        }
        return _executeDeployToken(deployer, msgValue, deploymentParameters, signature, errorSelector);
    }

    struct BuyTmps {
        uint256 buyerKey;
        address buyer;
        PromotionalPool pool;
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
        PromotionalPool pool,
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
        
        PromotionalPoolBuyParameters memory buyParameters = IPromotionalPool(address(pool)).getBuyParameters();
        uint96 buyCostPairedTokenNumerator = buyParameters.buyCostPairedTokenNumerator;
        uint96 buyCostPoolTokenDenominator = buyParameters.buyCostPoolTokenDenominator;

        uint256 marketValueShare = 0;
        uint256 revenueShare = 
            (buyTmps.tokensToBuy * buyCostPairedTokenNumerator / buyCostPoolTokenDenominator);

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

    function _dealPaired(address account, uint256 amount) internal virtual {
        vm.deal(account, amount);
    }

    function _pairedBalance(address account) internal view virtual returns (uint256) {
        return account.balance;
    }
}