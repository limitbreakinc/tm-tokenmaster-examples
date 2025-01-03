// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./StablePoolToken.t.sol";
import "../../mocks/MockPairedTokenERC20TransferRestricted.sol";

contract StablePoolTokenERC20PairFallbackTransferByRouterTest is StablePoolTokenTest {

    MockPairedTokenERC20TransferRestricted internal testPairedToken;

    function setUp() public virtual override {
        super.setUp();

        testPairedToken = new MockPairedTokenERC20TransferRestricted("Test Pair", "TP", 18, address(tokenMasterRouter));
    }

    function _defaultDeploymentParameters(
        address initialOwner,
        StablePoolInitializationParameters memory initializationParams
    ) internal view override returns (DeploymentParameters memory deploymentParameters) {
        deploymentParameters = super._defaultDeploymentParameters(initialOwner, initializationParams);
        
        deploymentParameters.poolParams.pairedToken = address(testPairedToken);
        deploymentParameters.poolParams.useRouterForPairedTransfers = false;
    }

    function _deployToken(
        address deployer,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal override returns (address tokenAddress) {
        vm.startPrank(deployer);
        testPairedToken.approve(address(tokenMasterRouter), type(uint256).max);
        vm.stopPrank();
        return _executeDeployToken(deployer, 0, deploymentParameters, signature, errorSelector);
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