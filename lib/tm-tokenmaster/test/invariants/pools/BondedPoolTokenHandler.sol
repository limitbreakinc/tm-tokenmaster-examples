// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "./BondedPoolHandler.sol";

abstract contract BondedPoolTokenHandler is BondedPoolHandler {

    constructor(
        TokenMasterTest _test,
        TokenMasterRouter _router, 
        BondedPool _pool,
        DeploymentParameters memory _deploymentParameters
    ) BondedPoolHandler(_test, _router, _pool, _deploymentParameters) {
        MockPairedTokenERC20(pool.PAIRED_TOKEN()).mint(address(this), pairedTokenSupplyInitialMint);
    }

    function _handleCreatorEarningsWithdrawal(
        uint256 withdrawAmount, 
        uint256 infrastructureShare,
        uint256 partnerShare
    ) internal virtual override {
        _payToken(pool.owner(), pool.PAIRED_TOKEN(), address(this), withdrawAmount);
        _payToken(test.roleServer().getRoleHolder(keccak256(abi.encode(test.roleSet(), TOKENMASTER_FEE_RECEIVER_BASE_ROLE))), pool.PAIRED_TOKEN(), address(this), infrastructureShare);

        (,,,address partnerFeeRecipient) = router.getTokenSettings(address(pool));
        if (partnerFeeRecipient != address(0)) {
            _payToken(partnerFeeRecipient, pool.PAIRED_TOKEN(), address(this), partnerShare);
        }
    }

    function _handleInfrastructureEarningsWithdrawal(uint256 infrastructureShare) internal virtual override {
        _payToken(test.roleServer().getRoleHolder(keccak256(abi.encode(test.roleSet(), TOKENMASTER_FEE_RECEIVER_BASE_ROLE))), pool.PAIRED_TOKEN(), address(this), infrastructureShare);
    }

    function _handlePartnerEarningsWithdrawal(address recipient, uint256 partnerShare) internal virtual override {
        _payToken(recipient, pool.PAIRED_TOKEN(), address(this), partnerShare);
    }

    function _handleLosePairedTokens(uint256 amount) internal virtual override returns (uint256) {
        amount = bound(amount, 0, MockPairedTokenERC20(pool.PAIRED_TOKEN()).balanceOf(address(this)));
        amount = amount % type(uint128).max;
        _payToken(address(this), pool.PAIRED_TOKEN(), currentActor, amount);
        _payToken(currentActor, pool.PAIRED_TOKEN(), address(pool), amount);
        return amount;
    }

    function _handleBuyTokens(
        address actor, 
        uint256 tokensToBuy, 
        uint256 pairedValueIn
    ) internal virtual override {
        vm.startPrank(actor);
        MockPairedTokenERC20(pool.PAIRED_TOKEN()).approve(address(router), pairedValueIn);
        router.buyTokens(BuyOrder({
            tokenMasterToken: address(pool),
            tokensToBuy: tokensToBuy,
            pairedValueIn: pairedValueIn
        }));
        vm.stopPrank();
    }

    function _payToken(address actor, address token, address to, uint256 amount) internal {
        vm.startPrank(actor);
        MockPairedTokenERC20(token).transfer(to, amount);
        vm.stopPrank();
    }
}