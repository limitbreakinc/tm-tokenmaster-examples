// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./TokenMaster.t.sol";
import "src/pools/promotional-pool/DataTypes.sol";
import "src/pools/standard-token-pool/DataTypes.sol";
import "src/interfaces/ITokenMasterRouter.sol";
import "@limitbreak/permit-c/interfaces/IPermitC.sol";

abstract contract TokenMasterTokenTest is TokenMasterTest {

    bytes4 constant NO_ERROR = bytes4(0);

    function setUp() public virtual override {
        super.setUp();
    }

    function _executeDeployToken(
        address deployer,
        uint256 msgValue,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal returns (address tokenAddress) {
        vm.startPrank(deployer);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        }
        tokenMasterRouter.deployToken{value: msgValue}(
            deploymentParameters,
            signature
        );
        tokenAddress = deploymentParameters.tokenAddress;
        vm.stopPrank();

        if (errorSelector == bytes4(0)) {
            (
                bool deployedByTokenMaster,
                bool blockTransactionsFromUntrustedChannels,
                bool restrictPairingToLists,
                address partnerFeeRecipient
            ) = tokenMasterRouter.getTokenSettings(tokenAddress);
            assertTrue(deployedByTokenMaster);
            assertEq(
                blockTransactionsFromUntrustedChannels,
                deploymentParameters.blockTransactionsFromUntrustedChannels
            );
            assertEq(
                restrictPairingToLists,
                deploymentParameters.restrictPairingToLists
            );
            assertEq(
                partnerFeeRecipient,
                deploymentParameters.poolParams.partnerFeeRecipient
            );
        }
    }

    function _executeDeployTokenForwarder(
        TrustedForwarder forwarder,
        address deployer,
        uint256 msgValue,
        DeploymentParameters memory deploymentParameters,
        SignatureECDSA memory signature,
        bytes4 errorSelector
    ) internal returns (address tokenAddress) {
        bytes memory data = abi.encodeWithSelector(
            TokenMasterRouter.deployToken.selector,
            deploymentParameters,
            signature
        );
        vm.startPrank(deployer);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        }
        forwarder.forwardCall{value: msgValue}(address(tokenMasterRouter), data);
        tokenAddress = deploymentParameters.tokenAddress;
        vm.stopPrank();

        if (errorSelector == bytes4(0)) {
            (
                bool deployedByTokenMaster,
                bool blockTransactionsFromUntrustedChannels,
                bool restrictPairingToLists,
                address partnerFeeRecipient
            ) = tokenMasterRouter.getTokenSettings(tokenAddress);
            assertTrue(deployedByTokenMaster);
            assertEq(
                blockTransactionsFromUntrustedChannels,
                deploymentParameters.blockTransactionsFromUntrustedChannels
            );
            assertEq(
                restrictPairingToLists,
                deploymentParameters.restrictPairingToLists
            );
            assertEq(
                partnerFeeRecipient,
                deploymentParameters.poolParams.partnerFeeRecipient
            );
        }
    }

    function _updateDeploymentAddress(
        DeploymentParameters memory deploymentParameters
    ) internal view {
        deploymentParameters.tokenAddress = ITokenMasterFactory(deploymentParameters.tokenFactory).computeDeploymentAddress(
            deploymentParameters.tokenSalt,
            deploymentParameters.poolParams,
            deploymentParameters.poolParams.initialPairedTokenToDeposit,
            tokenMasterRouter.infrastructureFeeBPS()
        );
    }

    function _executeBuyTokens(
        address buyer,
        BuyOrder memory buyOrder,
        uint256 msgValue,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        vm.startPrank(buyer);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        tokenMasterRouter.buyTokens{value: msgValue}(buyOrder);
        vm.stopPrank();
    }

    function _executeBuyTokensAdvanced(
        address buyer,
        BuyOrder memory buyOrder,
        SignedOrder memory signedOrder,
        PermitTransfer memory permitTransfer,
        uint256 msgValue,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        vm.startPrank(buyer);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        tokenMasterRouter.buyTokensAdvanced{value: msgValue}(buyOrder, signedOrder, permitTransfer);
        vm.stopPrank();
    }

    function _executeBuyTokensForwarder(
        TrustedForwarder forwarder,
        address buyer,
        BuyOrder memory buyOrder,
        uint256 msgValue,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            TokenMasterRouter.buyTokens.selector,
            buyOrder
        );
        vm.startPrank(buyer);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        forwarder.forwardCall{value: msgValue}(address(tokenMasterRouter), data);
        vm.stopPrank();
    }

    function _executeBuyTokensAdvancedForwarder(
        TrustedForwarder forwarder,
        address buyer,
        BuyOrder memory buyOrder,
        uint256 msgValue,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            TokenMasterRouter.buyTokens.selector,
            buyOrder
        );
        vm.startPrank(buyer);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        forwarder.forwardCall{value: msgValue}(address(tokenMasterRouter), data);
        vm.stopPrank();
    }

    function _executeSellTokens(
        address seller,
        SellOrder memory sellOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        vm.startPrank(seller);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        tokenMasterRouter.sellTokens(sellOrder);
        vm.stopPrank();
    }

    function _executeSellTokensAdvanced(
        address seller,
        SellOrder memory sellOrder,
        SignedOrder memory signedOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        vm.startPrank(seller);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        tokenMasterRouter.sellTokensAdvanced(sellOrder, signedOrder);
        vm.stopPrank();
    }

    function _executeSellTokensForwarder(
        TrustedForwarder forwarder,
        address seller,
        SellOrder memory sellOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            TokenMasterRouter.sellTokens.selector,
            sellOrder
        );
        vm.startPrank(seller);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        forwarder.forwardCall(address(tokenMasterRouter), data);
        vm.stopPrank();
    }

    function _executeSellTokensAdvancedForwarder(
        TrustedForwarder forwarder,
        address seller,
        SellOrder memory sellOrder,
        SignedOrder memory signedOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            TokenMasterRouter.sellTokensAdvanced.selector,
            sellOrder,
            signedOrder
        );
        vm.startPrank(seller);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        forwarder.forwardCall(address(tokenMasterRouter), data);
        vm.stopPrank();
    }

    function _executeSpendTokens(
        address spender,
        SpendOrder memory spendOrder,
        SignedOrder memory signedOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        vm.startPrank(spender);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        tokenMasterRouter.spendTokens(spendOrder, signedOrder);
        vm.stopPrank();
    }

    function _executeSpendTokensForwarder(
        TrustedForwarder forwarder,
        address spender,
        SpendOrder memory spendOrder,
        SignedOrder memory signedOrder,
        bytes4 errorSelector,
        bool expectRevert
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            TokenMasterRouter.spendTokens.selector,
            spendOrder,
            signedOrder
        );
        vm.startPrank(spender);
        if (errorSelector != bytes4(0)) {
            vm.expectRevert(errorSelector);
        } else if (expectRevert) {
            vm.expectRevert();
        }
        forwarder.forwardCall(address(tokenMasterRouter), data);
        vm.stopPrank();
    }
}