// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "../HandlerBase.sol";
import "../ForcePush.sol";
import "src/pools/BondedPool.sol";
import "src/TokenMasterRouter.sol";
import "test/TokenMaster.t.sol";
import "test/mocks/MockPairedTokenERC20.sol";
import "test/Constants.sol";

uint256 constant PAIRED_TOKEN_SUPPLY = type(uint256).max;

abstract contract BondedPoolHandler is HandlerBase {
    using LibAddressSet for AddressSet;
    using LibUint256Set for Uint256Set;

    TokenMasterTest internal test;
    TokenMasterRouter public router;
    BondedPool public pool;
    DeploymentParameters public deploymentParameters;
    AddressSet private restrictedAccounts;

    uint256 public pairedTokenSupplyInitialMint;

    uint256 public ghost_mintedToRouter;
    uint256 public ghost_initialTokenSupply;
    uint256 public ghost_tokensBought;
    uint256 public ghost_tokensSold;
    uint256 public ghost_tokensSpent;

    uint256 public ghost_pairedTokenIntoPool;
    uint256 public ghost_pairedTokenOutOfPool;

    uint256 public ghost_creatorEarningsWithdrawn;
    uint256 public ghost_protocolEarningsWithdrawn;
    uint256 public ghost_partnerEarningsWithdrawn;

    uint256 public ghost_lostPairedTokens;

    constructor(
        TokenMasterTest _test,
        TokenMasterRouter _router, 
        BondedPool _pool,
        DeploymentParameters memory _deploymentParameters
    ) addActor(_pool.owner()) {
        test = _test;
        router = _router;
        pool = _pool;
        deploymentParameters = _deploymentParameters;

        pairedTokenSupplyInitialMint = PAIRED_TOKEN_SUPPLY;
        pairedTokenSupplyInitialMint -= deploymentParameters.poolParams.initialPairedTokenToDeposit;

        ghost_pairedTokenIntoPool = deploymentParameters.poolParams.initialPairedTokenToDeposit;
    }

    function getDeploymentParams() external view returns (DeploymentParameters memory) {
        return deploymentParameters;
    }

    function getPoolParams() external view returns (PoolDeploymentParameters memory) {
        return deploymentParameters.poolParams;
    }

    function addSpendSigner(uint160 signerPk) public createSignerFromPK(signerPk) countCall("addSpendSigner") {
        vm.startPrank(pool.owner());
        router.setOrderSigner(address(pool), vm.addr(currentSignerPk), true);
        vm.stopPrank();
    }

    function spendTokens(
        uint256 actorSeed, 
        uint256 signerSeed, 
        uint256 tokensToSpend,
        bytes32 spendId
    ) 
    public virtual
    useActor(actorSeed)
    useSigner(signerSeed)
    countCall("spendTokens") {
        tokensToSpend = bound(tokensToSpend, 0, pool.balanceOf(currentActor));
        
        SpendOrder memory spendOrder;
        SignedOrder memory signedOrder;
        signedOrder.creatorIdentifier = spendId;
        spendOrder.multiplier = 1;
        spendOrder.maxAmountToSpend = tokensToSpend;
        spendOrder.tokenMasterToken = address(pool);
        signedOrder.tokenMasterOracle = address(0);
        signedOrder.baseToken = address(0);
        signedOrder.baseValue = tokensToSpend;
        signedOrder.maxPerWallet = type(uint256).max;
        signedOrder.maxTotal = type(uint256).max;
        signedOrder.expiration = type(uint256).max;
        signedOrder.hook = address(0);
        signedOrder.signature = SignatureECDSA({
            v: 0,
            r: 0,
            s: 0
        });
        signedOrder.cosignature = Cosignature({
            signer: address(0),
            expiration: 0,
            v: 0,
            r: 0,
            s: 0
        });

        (
            SignatureECDSA memory signedSpendOrder, 
            /*bytes32 spendOrderHash*/
        ) = test.getSignedSpendOrderAndDigest(currentSignerPk, spendOrder, signedOrder);

        signedOrder.signature = signedSpendOrder;

        vm.startPrank(currentActor);
        router.spendTokens(spendOrder, signedOrder);
        vm.stopPrank();

        ghost_tokensSpent += tokensToSpend;
    }

    function withdrawCreatorShare(uint256 withdrawAmount) public {
        (
            /*uint256 marketShare*/, 
            uint256 creatorShare, 
            uint256 infrastructureShare,
            uint256 partnerShare
        ) = pool.pairedTokenShares();

        withdrawAmount = bound(withdrawAmount, 0, creatorShare);

        vm.startPrank(pool.owner());
        router.withdrawCreatorShare(ITokenMasterERC20C(address(pool)), pool.owner(), withdrawAmount);
        vm.stopPrank();

        _handleCreatorEarningsWithdrawal(withdrawAmount, infrastructureShare, partnerShare);

        ghost_creatorEarningsWithdrawn += withdrawAmount;
        ghost_protocolEarningsWithdrawn += infrastructureShare;
        ghost_partnerEarningsWithdrawn += partnerShare;
    }

    function withdrawFees() public {
        (
            /*uint256 marketShare*/, 
            /*uint256 creatorShare*/, 
            uint256 infrastructureShare,
            uint256 partnerShare
        ) = pool.pairedTokenShares();
        (,,,address partnerFeeRecipient) = router.getTokenSettings(address(pool));

        ITokenMasterERC20C[] memory pools = new ITokenMasterERC20C[](1);
        pools[0] = ITokenMasterERC20C(address(pool));

        vm.startPrank(FEE_COLLECTOR);
        router.withdrawFees(pools);
        vm.stopPrank();

        _handleInfrastructureEarningsWithdrawal(infrastructureShare);
        _handlePartnerEarningsWithdrawal(partnerFeeRecipient, partnerShare);

        ghost_protocolEarningsWithdrawn += infrastructureShare;
        ghost_partnerEarningsWithdrawn += partnerShare;
    }

    function losePairedTokens(uint256 amount) public createActor countCall("losePairedTokens") {
        uint256 adjustedAmount = _handleLosePairedTokens(amount);
        ghost_lostPairedTokens += adjustedAmount;
    }

    function approve(uint256 actorSeed, uint256 spenderSeed, uint256 amount)
        public
        useActor(actorSeed)
        countCall("approve")
    {
        address spender = _actors.rand(spenderSeed);

        if (spender == currentActor) {
            return;
        }

        vm.prank(currentActor);
        pool.approve(spender, amount);
    }

    function transfer(uint256 actorSeed, uint256 toSeed, uint256 amount)
        public
        useActor(actorSeed)
        countCall("transfer")
    {
        address to = _actors.rand(toSeed);

        amount = bound(amount, 0, pool.balanceOf(currentActor));

        vm.prank(currentActor);
        pool.transfer(to, amount);
    }

    function transferFrom(uint256 actorSeed, uint256 fromSeed, uint256 toSeed, bool _approve, uint256 amount)
        public
        useActor(actorSeed)
        countCall("transferFrom")
    {
        address from = _actors.rand(fromSeed);
        address to = _actors.rand(toSeed);

        amount = bound(amount, 0, pool.balanceOf(from));

        if (_approve) {
            vm.prank(from);
            pool.approve(currentActor, amount);
        } else {
            amount = bound(amount, 0, pool.allowance(from, currentActor));
        }

        vm.prank(currentActor);
        pool.transferFrom(from, to, amount);
    }

    function callSummary() external view override {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("buyTokens", calls["buyTokens"]);
        console.log("sellTokens", calls["sellTokens"]);
        console.log("addSpendSigner", calls["addSpendSigner"]);
        console.log("spendTokens", calls["spendTokens"]);
        console.log("-------------------");
        console.log("Tokens Bought:", ghost_tokensBought);
        console.log("Tokens Sold:", ghost_tokensSold);
        console.log("Tokens Spent:", ghost_tokensSpent);
    }

    function addRestrictedAccount(address account) external {
        restrictedAccounts.add(account);
    }

    function _handleBuyTokens(
        address actor, 
        uint256 tokensToBuy, 
        uint256 pairedValueIn
    ) internal virtual;

    function _sellTokens(address actor, uint256 tokensToSell) internal {
        vm.startPrank(actor);
        router.sellTokens(SellOrder({
            tokenMasterToken: address(pool),
            tokensToSell: tokensToSell,
            minimumOut: 0
        }));
        vm.stopPrank();
    }

    function buyTokens(uint256 tokensToBuy, uint256 pairedValueIn) public virtual;

    function sellTokens(uint256 actorSeed, uint256 tokensToSell) public virtual;

    function setBuyParameters(uint256 randomSeed) public virtual;
    
    function setSellParameters(uint256 randomSeed) public virtual;

    function _handleCreatorEarningsWithdrawal(
        uint256 withdrawAmount, 
        uint256 infrastructureShare,
        uint256 partnerShare
    ) internal virtual;

    function _handleInfrastructureEarningsWithdrawal(uint256 infrastructureShare) internal virtual;

    function _handlePartnerEarningsWithdrawal(address recipient, uint256 partnerShare) internal virtual;

    function _handleLosePairedTokens(uint256 amount) internal virtual returns (uint256);

    function _getRandomHash(uint256 _seed, uint256 index) internal pure returns (bytes32 hash) {
        hash = keccak256(abi.encodePacked(_seed));
        for (uint256 i = 0; i < index; i++) {
            hash = keccak256(abi.encodePacked(hash));
        }
    }

    function _isAdditionalRestrictedAccount(address account) internal virtual view override returns (bool) {
        return 
        account == address(pool) || 
        account == address(router) ||
        restrictedAccounts.contains(account) ||
        uint256(uint160(account)) < 1024 ||
        account == console.CONSOLE_ADDRESS;
    }
}