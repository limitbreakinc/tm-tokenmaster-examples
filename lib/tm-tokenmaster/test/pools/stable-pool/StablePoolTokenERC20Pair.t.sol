// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./StablePoolToken.t.sol";

contract StablePoolTokenERC20PairTest is StablePoolTokenTest {

    MockPairedTokenERC20 internal testPairedToken;

    function setUp() public virtual override {
        super.setUp();

        testPairedToken = new MockPairedTokenERC20("Test Pair", "TP", 18);
    }

    function testPairTokenToToken() public {
        address deployer = address(0x4444);

        StablePoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
        initializationParams.initialSupplyAmount = 10 ether;
        initializationParams.initialSupplyRecipient = deployer;
        DeploymentParameters memory deploymentParameters = _defaultDeploymentParameters(deployer, initializationParams);
        deploymentParameters.restrictPairingToLists = true;
        _updateDeploymentAddress(deploymentParameters);

        vm.deal(deployer, 10 ether);
        _dealPaired(deployer, 10 ether);

        SignatureECDSA memory emptySignature;
        address tokenAddressA = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        deploymentParameters.poolParams.pairedToken = tokenAddressA;
        _updateDeploymentAddress(deploymentParameters);
        address tokenAddressB = _deployToken(deployer, deploymentParameters, emptySignature, NO_ERROR);

        address deployerB = address(0x4545);
        vm.startPrank(deployer);
        IERC20(tokenAddressA).transfer(deployerB, 5 ether);
        vm.stopPrank();
        uint256 snapshotId = vm.snapshot();

        vm.expectRevert(LibOwnership.Ownership__CallerIsNotTokenOrOwnerOrAdmin.selector);
        tokenMasterRouter.updateTokenSettings(tokenAddressA, false, false);
        vm.startPrank(deployer);
        tokenMasterRouter.updateTokenSettings(tokenAddressA, false, false);
        vm.stopPrank();
        
        deploymentParameters.poolParams.initialOwner = deployerB;
        _updateDeploymentAddress(deploymentParameters);
        tokenAddressB = _deployToken(deployerB, deploymentParameters, emptySignature, NO_ERROR);

        vm.revertTo(snapshotId);

        deploymentParameters.poolParams.initialOwner = deployerB;
        _updateDeploymentAddress(deploymentParameters);
        tokenAddressB = _deployToken(deployerB, deploymentParameters, emptySignature, TokenMasterRouter__PairedTokenPairingRestricted.selector);

        vm.startPrank(deployer);
        tokenMasterRouter.setTokenAllowedPairToDeployer(tokenAddressA, deployerB, true);
        vm.stopPrank();

        deploymentParameters.poolParams.initialOwner = deployerB;
        _updateDeploymentAddress(deploymentParameters);
        tokenAddressB = _deployToken(deployerB, deploymentParameters, emptySignature, NO_ERROR);

        vm.revertTo(snapshotId);

        deploymentParameters.poolParams.initialOwner = deployerB;
        _updateDeploymentAddress(deploymentParameters);
        tokenAddressB = _deployToken(deployerB, deploymentParameters, emptySignature, TokenMasterRouter__PairedTokenPairingRestricted.selector);

        vm.startPrank(deployer);
        tokenMasterRouter.setTokenAllowedPairToToken(tokenAddressA, deploymentParameters.tokenAddress, true);
        vm.stopPrank();

        deploymentParameters.poolParams.initialOwner = deployerB;
        _updateDeploymentAddress(deploymentParameters);
        tokenAddressB = _deployToken(deployerB, deploymentParameters, emptySignature, NO_ERROR);

        vm.revertTo(snapshotId);

        vm.startPrank(deployer);
        tokenMasterRouter.updateTokenSettings(tokenAddressA, true, false);
        tokenMasterRouter.updateTokenSettings(tokenAddressA, true, false);
        vm.stopPrank();

        deploymentParameters.poolParams.initialOwner = deployerB;
        _updateDeploymentAddress(deploymentParameters);
        tokenAddressB = _deployToken(deployerB, deploymentParameters, emptySignature, TokenMasterRouter__TransactionOriginatedFromUntrustedChannel.selector);

        vm.startPrank(deployer);
        address allowedChannel = trustedForwarderFactory.cloneTrustedForwarder(deployer, address(0), bytes32(uint256(1)));
        tokenMasterRouter.setTokenAllowedTrustedChannel(tokenAddressA, allowedChannel, true);
        vm.stopPrank();

        deploymentParameters.poolParams.initialOwner = deployerB;
        _updateDeploymentAddress(deploymentParameters);
        tokenAddressB = _deployTokenForwarder(TrustedForwarder(allowedChannel), deployerB, deploymentParameters, emptySignature, NO_ERROR);
    }

    function _defaultDeploymentParameters(
        address initialOwner,
        StablePoolInitializationParameters memory initializationParams
    ) internal view override returns (DeploymentParameters memory deploymentParameters) {
        deploymentParameters = super._defaultDeploymentParameters(initialOwner, initializationParams);
        
        deploymentParameters.poolParams.pairedToken = address(testPairedToken);
    }

    function _deployToken(
        address deployer,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal override returns (address tokenAddress) {
        vm.startPrank(deployer);
        IERC20(deploymentParameters.poolParams.pairedToken).approve(address(tokenMasterRouter), type(uint256).max);
        vm.stopPrank();
        return _executeDeployToken(deployer, 0, deploymentParameters, signature, errorSelector);
    }

    function _deployTokenForwarder(
        TrustedForwarder forwarder,
        address deployer,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal returns (address tokenAddress) {
        vm.startPrank(deployer);
        IERC20(deploymentParameters.poolParams.pairedToken).approve(address(tokenMasterRouter), type(uint256).max);
        vm.stopPrank();
        return _executeDeployTokenForwarder(forwarder, deployer, 0, deploymentParameters, signature, errorSelector);
    }

    function _deployTokenOverrideValue(
        address deployer,
        uint256 msgValue,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal override returns (address tokenAddress) {
        return _executeDeployToken(deployer, msgValue, deploymentParameters, signature, errorSelector);
    }

    function _buyTokensInternal(
        uint256 /*buyerKey*/,
        address buyer,
        BuyOrder memory buyOrder,
        uint256 /*msgValue*/,
        bytes4 errorSelector,
        bool expectRevert
    ) internal override {
        vm.startPrank(buyer);
        testPairedToken.approve(address(tokenMasterRouter), type(uint256).max);
        vm.stopPrank();
        _executeBuyTokens(buyer, buyOrder, 0, errorSelector, expectRevert);
    }

    function _sellTokensInternal(
        address seller,
        SellOrder memory sellOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal override {
        vm.startPrank(seller);
        testPairedToken.approve(address(tokenMasterRouter), type(uint256).max);
        vm.stopPrank();
        _executeSellTokens(seller, sellOrder, errorSelector, expectRevert);
    }

    function _dealPaired(address account, uint256 amount) internal override {
        testPairedToken.mint(account, amount);
    }

    function _pairedBalance(address account) internal view override returns (uint256) {
        return testPairedToken.balanceOf(account);
    }
}