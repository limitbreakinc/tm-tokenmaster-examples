// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./StandardPoolToken.t.sol";

contract StandardPoolTokenForwardedTest is StandardPoolTokenTest {

    TrustedForwarder internal testForwarder;

    function setUp() public virtual override {
        super.setUp();

        testForwarder = TrustedForwarder(trustedForwarderFactory.cloneTrustedForwarder(address(this), address(0), bytes32(0)));
    }

    function _defaultDeploymentParameters(
        address initialOwner,
        StandardPoolInitializationParameters memory initializationParams
    ) internal view override returns (DeploymentParameters memory deploymentParameters) {
        deploymentParameters = super._defaultDeploymentParameters(initialOwner, initializationParams);
        
        deploymentParameters.blockTransactionsFromUntrustedChannels = true;
    }

    function testRevertsWhenNotBuyingThroughTrustedChannel() public {
        address deployer = address(0x4444);

        StandardPoolInitializationParameters memory initializationParams = _defaultInitializationParameters();
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

        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = tokenAddress;
        buyOrder.tokensToBuy = 5 ether;
        buyOrder.pairedValueIn = 6 ether;
        _executeBuyTokens(trader, buyOrder, 6 ether, TokenMasterRouter__TransactionOriginatedFromUntrustedChannel.selector, true);
    }

    function _deployToken(
        address deployer,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal override returns (address tokenAddress) {
        uint256 msgValue;
        if (deploymentParameters.poolParams.pairedToken == address(0)) {
            msgValue = deploymentParameters.poolParams.initialPairedTokenToDeposit;
        }
        tokenAddress = _executeDeployTokenForwarder(testForwarder, deployer, msgValue, deploymentParameters, signature, errorSelector);

        if (errorSelector == bytes4(0)) {
            vm.startPrank(deployer);
            tokenMasterRouter.setTokenAllowedTrustedChannel(tokenAddress, address(testForwarder), true);
            vm.stopPrank();

            address[] memory trustedChannels = tokenMasterRouter.getTrustedChannels(tokenAddress);
            address[] memory testChannels = new address[](1);
            testChannels[0] = address(testForwarder);
            assertEq(keccak256(abi.encodePacked(trustedChannels)), keccak256(abi.encodePacked(testChannels)));
        }
    }

    function _deployTokenOverrideValue(
        address deployer,
        uint256 msgValue,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal override returns (address tokenAddress) {
        tokenAddress = _executeDeployTokenForwarder(testForwarder, deployer, msgValue, deploymentParameters, signature, errorSelector);

        if (errorSelector == bytes4(0)) {
            vm.startPrank(deployer);
            tokenMasterRouter.setTokenAllowedTrustedChannel(tokenAddress, address(testForwarder), true);
            vm.stopPrank();
        }
    }

    function _buyTokensInternal(
        uint256 /*buyerKey*/,
        address buyer,
        BuyOrder memory buyOrder,
        uint256 msgValue,
        bytes4 errorSelector,
        bool expectRevert
    ) internal override {
        _executeBuyTokensForwarder(testForwarder, buyer, buyOrder, msgValue, errorSelector, expectRevert);
    }

    function _sellTokensInternal(
        address seller,
        SellOrder memory sellOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal override {
        _executeSellTokensForwarder(testForwarder, seller, sellOrder, errorSelector, expectRevert);
    }
}