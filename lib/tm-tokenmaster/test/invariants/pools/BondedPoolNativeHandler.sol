// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "./BondedPoolHandler.sol";

abstract contract BondedPoolNativeHandler is BondedPoolHandler {

    constructor(
        TokenMasterTest _test,
        TokenMasterRouter _router, 
        BondedPool _pool,
        DeploymentParameters memory _deploymentParameters
    ) BondedPoolHandler(_test, _router, _pool, _deploymentParameters) {
        deal(address(this), pairedTokenSupplyInitialMint);
    }

    function _handleCreatorEarningsWithdrawal(
        uint256 withdrawAmount, 
        uint256 infrastructureShare,
        uint256 partnerShare
    ) internal virtual override {
        _payNative(pool.owner(), address(this), withdrawAmount);
        _payNative(test.roleServer().getRoleHolder(keccak256(abi.encode(test.roleSet(), TOKENMASTER_FEE_RECEIVER_BASE_ROLE))), address(this), infrastructureShare);

        (,,,address partnerFeeRecipient) = router.getTokenSettings(address(pool));
        if (partnerFeeRecipient != address(0)) {
            _payNative(partnerFeeRecipient, address(this), partnerShare);
        }
    }

    function _handleInfrastructureEarningsWithdrawal(uint256 infrastructureShare) internal virtual override {
        _payNative(test.roleServer().getRoleHolder(keccak256(abi.encode(test.roleSet(), TOKENMASTER_FEE_RECEIVER_BASE_ROLE))), address(this), infrastructureShare);
    }

    function _handlePartnerEarningsWithdrawal(address recipient, uint256 partnerShare) internal virtual override {
        _payNative(recipient, address(this), partnerShare);
    }

    function _handleLosePairedTokens(uint256 amount) internal virtual override returns (uint256) {
        amount = bound(amount, 0, address(this).balance);
        if (amount == 0) return 0;
        amount = amount % type(uint128).max;
        _payNative(address(this), currentActor, amount);
        vm.startPrank(currentActor);
        new ForcePush{ value: amount }(address(pool));
        vm.stopPrank();
        return amount;
    }

    function _handleBuyTokens(
        address actor, 
        uint256 tokensToBuy, 
        uint256 pairedValueIn
    ) internal virtual override {
        vm.startPrank(actor);
        router.buyTokens{value: pairedValueIn}(BuyOrder({
            tokenMasterToken: address(pool),
            tokensToBuy: tokensToBuy,
            pairedValueIn: pairedValueIn
        }));
        vm.stopPrank();
    }

    function _payNative(address actor, address to, uint256 amount) internal {
        vm.startPrank(actor);
        (bool s,) = to.call{value: amount}("");
        require(s, "pay() failed");
        vm.stopPrank();
    }
}