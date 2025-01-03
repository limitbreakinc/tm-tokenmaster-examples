// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./PromotionalPoolToken.t.sol";

contract PromotionalPoolTokenERC20PairPermitBuyTest is PromotionalPoolTokenTest {

    MockPairedTokenERC20 internal testPairedToken;

    function setUp() public virtual override {
        super.setUp();

        testPairedToken = new MockPairedTokenERC20("Test Pair", "TP", 18);
    }

    function _defaultDeploymentParameters(
        address initialOwner,
        PromotionalPoolInitializationParameters memory initializationParams
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
        if (deploymentParameters.poolParams.pairedToken != address(0)) {
            vm.startPrank(deployer);
            IERC20(deploymentParameters.poolParams.pairedToken).approve(address(tokenMasterRouter), type(uint256).max);
            vm.stopPrank();
        }
        return _executeDeployToken(deployer, msgValue, deploymentParameters, signature, errorSelector);
    }

    function _buyTokensInternal(
        uint256 buyerKey,
        address buyer,
        BuyOrder memory buyOrder,
        uint256 /*msgValue*/,
        bytes4 errorSelector,
        bool expectRevert
    ) internal override {
        vm.startPrank(buyer);
        testPairedToken.approve(address(transferValidator), type(uint256).max);
        vm.stopPrank();

        SignedOrder memory signedOrder;
        (bytes memory signature, uint256 permitNonce) = _signPermitTransfer(buyerKey, buyer, address(testPairedToken), buyOrder, signedOrder);
        PermitTransfer memory permitTransfer;
        permitTransfer.permitProcessor = address(transferValidator);
        permitTransfer.nonce = permitNonce;
        permitTransfer.permitAmount = buyOrder.pairedValueIn;
        permitTransfer.expiration = type(uint256).max;
        permitTransfer.signedPermit = signature;

        _executeBuyTokensAdvanced(buyer, buyOrder, signedOrder, permitTransfer, 0, errorSelector, expectRevert);
    }

    function _dealPaired(address account, uint256 amount) internal override {
        testPairedToken.mint(account, amount);
    }

    function _pairedBalance(address account) internal view override returns (uint256) {
        return testPairedToken.balanceOf(account);
    }
}