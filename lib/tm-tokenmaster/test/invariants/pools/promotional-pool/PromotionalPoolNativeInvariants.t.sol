// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "./PromotionalPoolNativeHandler.sol";
import "src/TokenMasterRouter.sol";
import "src/pools/promotional-pool/PromotionalPoolFactory.sol";
import "src/pools/promotional-pool/PromotionalPoolCreationCode.sol";
import "src/pools/promotional-pool/PromotionalPool.sol";
import "@limitbreak/tm-role-server/RoleServer.sol";
import {TrustedForwarder} from "@limitbreak/trusted-forwarder/TrustedForwarder.sol";
import "@limitbreak/trusted-forwarder/TrustedForwarderFactory.sol";
import "test/mocks/MockPairedTokenERC20.sol";
import "../../../Constants.sol";
import "test/TokenMaster.t.sol";

contract PromotionalPoolNativeInvariants is TokenMasterTest {
    BondedPool public pool;
    PromotionalPoolNativeHandler public handler;

    function setUp() public override {
        super.setUp();
        
        uint256 sysTime = vm.unixTime();

        bytes32 poolSalt = _getPoolSalt(sysTime);
        address initialOwner = _getPoolOwner(sysTime);
        uint16 infrastructureFeeBPS = _getInfrastructureFeeBPS(sysTime);
        vm.prank(TOKENMASTER_ADMIN);
        tokenMasterRouter.setInfrastructureFee(infrastructureFeeBPS);

        (
            PoolDeploymentParameters memory poolParams, 
            PromotionalPoolInitializationParameters memory initParams
        ) = _getPoolDeploymentParams(sysTime, initialOwner);

        DeploymentParameters memory deploymentParameters = DeploymentParameters({
            tokenFactory: address(promotionalPoolFactory),
            tokenSalt: poolSalt,
            tokenAddress: address(0),
            blockTransactionsFromUntrustedChannels: false,
            restrictPairingToLists: false,
            poolParams: poolParams,
            maxInfrastructureFeeBPS: 10_000
        });

        address poolAddress = promotionalPoolFactory.computeDeploymentAddress(
            deploymentParameters.tokenSalt,
            deploymentParameters.poolParams,
            deploymentParameters.poolParams.initialPairedTokenToDeposit,
            infrastructureFeeBPS);

        deploymentParameters.tokenAddress = poolAddress;

        vm.deal(initialOwner, deploymentParameters.poolParams.initialPairedTokenToDeposit);

        vm.startPrank(initialOwner);
        tokenMasterRouter.deployToken{value: deploymentParameters.poolParams.initialPairedTokenToDeposit}(
            deploymentParameters,
            SignatureECDSA({v: 0, r: bytes32(0), s: bytes32(0)})
        );
        vm.stopPrank();

        pool = BondedPool(poolAddress);
        handler = new PromotionalPoolNativeHandler(TokenMasterTest(address(this)), tokenMasterRouter, pool, deploymentParameters, initParams);

        handler.addRestrictedAccount(address(handler));
        handler.addRestrictedAccount(address(roleServer));
        handler.addRestrictedAccount(address(trustedForwarder));
        handler.addRestrictedAccount(address(trustedForwarderFactory));
        handler.addRestrictedAccount(address(trustedForwarderTemplate));
        handler.addRestrictedAccount(address(trustedForwarderFactoryTemplate));
        handler.addRestrictedAccount(address(tokenMasterRouter));
        handler.addRestrictedAccount(address(standardPoolFactory));
        handler.addRestrictedAccount(address(stablePoolFactory));
        handler.addRestrictedAccount(address(promotionalPoolFactory));
        handler.addRestrictedAccount(standardPoolFactory.CREATION_CODE());
        handler.addRestrictedAccount(stablePoolFactory.CREATION_CODE());
        handler.addRestrictedAccount(promotionalPoolFactory.CREATION_CODE());
        handler.addRestrictedAccount(address(this));

        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = PromotionalPoolNativeHandler.buyTokens.selector;
        selectors[1] = BondedPoolHandler.addSpendSigner.selector;
        selectors[2] = BondedPoolHandler.spendTokens.selector;
        selectors[3] = PromotionalPoolNativeHandler.setBuyParameters.selector;
        selectors[4] = BondedPoolHandler.withdrawCreatorShare.selector;
        selectors[5] = BondedPoolHandler.withdrawFees.selector;
        selectors[6] = BondedPoolHandler.approve.selector;
        selectors[7] = BondedPoolHandler.transfer.selector;
        selectors[8] = BondedPoolHandler.transferFrom.selector;
        selectors[9] = BondedPoolHandler.losePairedTokens.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));

        excludeContract(address(roleServer));
        excludeContract(address(trustedForwarder));
        excludeContract(address(trustedForwarderFactory));
        excludeContract(address(trustedForwarderTemplate));
        excludeContract(address(trustedForwarderFactoryTemplate));
        excludeContract(address(tokenMasterRouter));
        excludeContract(address(standardPoolFactory));
        excludeContract(address(stablePoolFactory));
        excludeContract(address(promotionalPoolFactory));
        excludeContract(standardPoolFactory.CREATION_CODE());
        excludeContract(stablePoolFactory.CREATION_CODE());
        excludeContract(promotionalPoolFactory.CREATION_CODE());
    }

    function invariant_totalSupply() public view {
        assertEq(
            pool.totalSupply(), 
            handler.ghost_initialTokenSupply() +
            handler.ghost_tokensBought() - 
            handler.ghost_tokensSold() -
            handler.ghost_tokensSpent()
        );
    }

    function invariant_totalSupplySolvency() public {
        uint256 sumOfBalances = handler.reduceActors(0, this.accumulatePoolTokenBalance);
        assertEq(pool.totalSupply(), sumOfBalances);
    }

    function invariant_outflowsCannotExceedInflows() public view {
        assertTrue(handler.ghost_pairedTokenIntoPool() >= handler.ghost_pairedTokenOutOfPool());
    }

    function invariant_netInflowsBalanceOutWithBondedValueAndEarnings() public view {
        (
            uint256 marketShare, 
            uint256 creatorShare, 
            uint256 infrastructureShare,
            uint256 partnerShare
        ) = pool.pairedTokenShares();

        uint256 netInflows = handler.ghost_pairedTokenIntoPool() - handler.ghost_pairedTokenOutOfPool();
        uint256 totalPoolShares = marketShare + creatorShare + infrastructureShare + partnerShare;
        uint256 earningsWithdrawn = 
            handler.ghost_creatorEarningsWithdrawn() + 
            handler.ghost_protocolEarningsWithdrawn() +
            handler.ghost_partnerEarningsWithdrawn();
        uint256 lostPairedTokens = handler.ghost_lostPairedTokens();

        assertEq(netInflows, totalPoolShares + earningsWithdrawn - lostPairedTokens);
    }

    function invariant_protocolFeesAreCorrect() public view {
        (
            /*uint256 marketShare*/, 
            uint256 creatorShare, 
            uint256 infrastructureShare,
            uint256 partnerShare
        ) = pool.pairedTokenShares();

        uint256 combinedEarnings = 
            creatorShare + 
            infrastructureShare +
            partnerShare +
            handler.ghost_creatorEarningsWithdrawn() + 
            handler.ghost_protocolEarningsWithdrawn() +
            handler.ghost_partnerEarningsWithdrawn();

        uint256 protocolEarnings = infrastructureShare + handler.ghost_protocolEarningsWithdrawn();

        if (combinedEarnings > BPS) {
            assertLe((combinedEarnings * tokenMasterRouter.infrastructureFeeBPS() / BPS) - protocolEarnings, BPS);
        }
    }

    function invariant_partnerFeesAreCorrect() public view {
        (
            /*uint256 marketShare*/, 
            uint256 creatorShare, 
            /*uint256 infrastructureShare*/,
            uint256 partnerShare
        ) = pool.pairedTokenShares();

        uint256 combinedEarnings = 
            creatorShare + 
            partnerShare +
            handler.ghost_creatorEarningsWithdrawn() + 
            handler.ghost_partnerEarningsWithdrawn();

        uint256 partnerEarnings = partnerShare + handler.ghost_partnerEarningsWithdrawn();

        if (combinedEarnings > BPS) {
            assertLe((combinedEarnings * handler.getPoolParams().partnerFeeBPS / BPS) - partnerEarnings, BPS);
        }
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }

    function accumulatePoolTokenBalance(uint256 balance, address caller) external view returns (uint256) {
        return balance + pool.balanceOf(caller);
    }

    // Scenario 0: Paired Native, 18 decimals
    // Scenario 1: Paired Native, random decimals
    function _getScenario(uint256 _seed) internal pure returns (uint256) {
        return uint256(_getRandomHash(_seed, 0)) % 2;
    }

    function _getPoolSalt(uint256 _seed) internal virtual view returns (bytes32) {
        return _getRandomHash(_seed, 1);
    }

    function _getPoolOwner(uint256 _seed) internal virtual view returns (address) {
        return vm.addr(1 + uint160(uint256(_getRandomHash(_seed, 2)) % type(uint160).max - 1));
    }

    function _getInfrastructureFeeBPS(uint256 _seed) internal virtual view returns (uint16) {
        return uint16(uint256(_getRandomHash(_seed, 3)) % 10000);
    }

    function _getPoolDeploymentParams(uint256 _seed, address initialOwner) internal virtual returns (PoolDeploymentParameters memory, PromotionalPoolInitializationParameters memory) {
        (
            /*uint8 pairedTokenDecimals*/, 
            uint8 poolTokenDecimals, 
            address pairedToken
        ) = _getDecimalsAndTokenAddressForScenario(_getScenario(_seed), initialOwner);

        PromotionalPoolInitializationParameters memory initializationParameters = PromotionalPoolInitializationParameters({
            initialSupplyRecipient: initialOwner,
            initialSupplyAmount: uint256(_getRandomHash(_seed, 20)) % 2 == 0 ? 0 : uint256(_getRandomHash(_seed, 21)) & type(uint32).max,
            initialBuyParameters: PromotionalPoolBuyParameters({
                buyCostPairedTokenNumerator: 0,
                buyCostPoolTokenDenominator: 10000
            })
        });

        uint256 initialPairedTokenToDeposit = 0;

        return (PoolDeploymentParameters({
            name: "PromotionalPool1",
            symbol: "PROMOPOOL1",
            tokenDecimals: poolTokenDecimals,
            initialOwner: initialOwner,
            pairedToken: pairedToken,
            initialPairedTokenToDeposit: initialPairedTokenToDeposit,
            encodedInitializationArgs: abi.encode(initializationParameters),
            defaultTransferValidator: address(0),
            useRouterForPairedTransfers: false,
            partnerFeeRecipient: vm.addr(1 + uint160(uint256(_getRandomHash(_seed, 30)) % type(uint160).max - 1)),
            partnerFeeBPS: uint16(uint256(_getRandomHash(_seed, 30)) % 10000)
        }), initializationParameters);
    }

    function _getDecimalsAndTokenAddressForScenario(
        uint256 scenario,
        address /*deployer*/
    ) internal pure returns (uint8 pairedTokenDecimals, uint8 poolTokenDecimals, address pairedToken) {
        pairedTokenDecimals = 18;
        poolTokenDecimals = 18;
        pairedToken = address(0);

        // Scenario 0: Paired Native, 18 decimals
        // Scenario 1: Paired Native, random decimals
        if (scenario == 1) {
            poolTokenDecimals = uint8(uint256(_getRandomHash(0, 4))) % 19;
        }
    }

    function _getRandomHash(uint256 _seed, uint256 index) internal pure returns (bytes32 hash) {
        hash = keccak256(abi.encodePacked(_seed));
        for (uint256 i = 0; i < index; i++) {
            hash = keccak256(abi.encodePacked(hash));
        }
    }
}