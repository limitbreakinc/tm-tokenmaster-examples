// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import "./Constants.sol";
import "src/Errors.sol";
import "@limitbreak/tm-role-server/RoleSetServer.sol";
import "src/TokenMasterRouter.sol";
import {StandardPoolFactory} from "src/pools/standard-token-pool/StandardPoolFactory.sol";
import {StablePoolFactory} from "src/pools/stable-pool/StablePoolFactory.sol";
import {PromotionalPoolFactory} from "src/pools/promotional-pool/PromotionalPoolFactory.sol";
import {TrustedForwarder} from "@limitbreak/trusted-forwarder/TrustedForwarder.sol";
import "@limitbreak/trusted-forwarder/TrustedForwarderFactory.sol";
import {CreatorTokenTransferValidator} from "@limitbreak/creator-token-transfer-validator/CreatorTokenTransferValidator.sol";

contract TokenMasterTest is Test {

    bytes32 public roleSet;
    bytes32 private ROUTER_DOMAIN_SEPARATOR;
    RoleSetServer public roleServer;
    TokenMasterRouter public tokenMasterRouter;
    StandardPoolFactory public standardPoolFactory;
    StablePoolFactory public stablePoolFactory;
    PromotionalPoolFactory public promotionalPoolFactory;
    TrustedForwarder public trustedForwarder;
    TrustedForwarderFactory public trustedForwarderFactory;
    CreatorTokenTransferValidator public transferValidator;

    TrustedForwarder public trustedForwarderTemplate;
    TrustedForwarderFactory public trustedForwarderFactoryTemplate;

    function setUp() public virtual {
        RoleSetServer roleServerTmp = new RoleSetServer();
        vm.etch(ROLE_SERVER, address(roleServerTmp).code);
        roleServer = RoleSetServer(ROLE_SERVER);

        vm.startPrank(TOKENMASTER_ADMIN);
        roleSet = roleServer.createRoleSet(TOKENMASTER_ROLE_SERVER_SET_SALT);
        vm.stopPrank();

        trustedForwarderTemplate = new TrustedForwarder();
        vm.etch(TRUSTED_FORWARDER_ADDRESS, address(trustedForwarderTemplate).code);
        trustedForwarder = TrustedForwarder(TRUSTED_FORWARDER_ADDRESS);
        trustedForwarderFactoryTemplate = new TrustedForwarderFactory(TRUSTED_FORWARDER_ADDRESS);
        vm.etch(TRUSTED_FORWARDER_FACTORY_ADDRESS, address(trustedForwarderFactoryTemplate).code);
        trustedForwarderFactory = TrustedForwarderFactory(TRUSTED_FORWARDER_FACTORY_ADDRESS);

        CreatorTokenTransferValidator tmpTransferValidator = new CreatorTokenTransferValidator(TRANSFER_VALIDATOR_ADMIN, address(1), "TransferValidator", "4.0");
        vm.etch(TRANSFER_VALIDATOR_ADDRESS, address(tmpTransferValidator).code);
        transferValidator = CreatorTokenTransferValidator(TRANSFER_VALIDATOR_ADDRESS);
        vm.store(TRANSFER_VALIDATOR_ADDRESS, keccak256(abi.encode(0, 10)), bytes32(uint256(uint160(TRANSFER_VALIDATOR_ADMIN))));
        transferValidator.registerAdditionalDataHash(PERMITC_ADVANCED_TYPEHASH_TO_REGISTER);
        
        address expectedRouterAddress = TOKENMASTER_ROUTER_ADDRESS;

        IRoleClient[] memory clients = new IRoleClient[](0);
        vm.startPrank(TOKENMASTER_ADMIN);
        roleServer.setRoleHolder(roleSet, TOKENMASTER_ADMIN_BASE_ROLE, TOKENMASTER_ADMIN, true, clients);
        roleServer.setRoleHolder(roleSet, TOKENMASTER_FEE_COLLECTOR_BASE_ROLE, FEE_COLLECTOR, true, clients);
        roleServer.setRoleHolder(roleSet, TOKENMASTER_FEE_RECEIVER_BASE_ROLE, FEE_RECIPIENT, true, clients);
        vm.stopPrank();

        vm.startPrank(KEYLESS_DEPLOYER);
        uint256 currentChainId = block.chainid;
        vm.chainId(currentChainId + 1); // switch chainId to force update on EIP712
        TokenMasterRouter tmpTokenMasterRouter = new TokenMasterRouter(
            address(roleServer),
            roleSet,
            address(trustedForwarderFactory)
        );
        vm.chainId(currentChainId);
        vm.etch(TOKENMASTER_ROUTER_ADDRESS, address(tmpTokenMasterRouter).code);
        tokenMasterRouter = TokenMasterRouter(TOKENMASTER_ROUTER_ADDRESS);
        console.log("TokenMasterRouter: %s", address(tokenMasterRouter));
        vm.stopPrank();

        address[] memory initialAllowedFactories = new address[](3);
        initialAllowedFactories[0] = STANDARD_POOL_ADDRESS;
        initialAllowedFactories[1] = STABLE_POOL_ADDRESS;
        initialAllowedFactories[2] = PROMO_POOL_ADDRESS;

        vm.startPrank(KEYLESS_DEPLOYER);
        StandardPoolFactory tmpStandardPoolFactory = new StandardPoolFactory{salt: STANDARD_POOL_SALT}(address(tokenMasterRouter));
        vm.etch(STANDARD_POOL_ADDRESS, address(tmpStandardPoolFactory).code);
        standardPoolFactory = StandardPoolFactory(STANDARD_POOL_ADDRESS);
        StablePoolFactory tmpStablePoolFactory = new StablePoolFactory{salt: STABLE_POOL_SALT}(address(tokenMasterRouter));
        vm.etch(STABLE_POOL_ADDRESS, address(tmpStablePoolFactory).code);
        stablePoolFactory = StablePoolFactory(STABLE_POOL_ADDRESS);
        PromotionalPoolFactory tmpPromotionalPoolFactory = new PromotionalPoolFactory{salt: PROMOTIONAL_POOL_SALT}(address(tokenMasterRouter));
        vm.etch(PROMO_POOL_ADDRESS, address(tmpPromotionalPoolFactory).code);
        promotionalPoolFactory = PromotionalPoolFactory(PROMO_POOL_ADDRESS);
        vm.stopPrank();

        assertEq(address(standardPoolFactory), initialAllowedFactories[0]);
        assertEq(address(stablePoolFactory), initialAllowedFactories[1]);
        assertEq(address(promotionalPoolFactory), initialAllowedFactories[2]);

        assertEq(address(tokenMasterRouter), expectedRouterAddress);
        ROUTER_DOMAIN_SEPARATOR = _getTokenMasterRouterDomainSeparator();

        vm.startPrank(TRANSFER_VALIDATOR_ADMIN);
        address[] memory whitelistAccounts = new address[](1);
        whitelistAccounts[0] = address(tokenMasterRouter);
        transferValidator.addAccountsToWhitelist(0, whitelistAccounts);
        vm.stopPrank();

        vm.startPrank(TOKENMASTER_ADMIN);
        tokenMasterRouter.setInfrastructureFee(DEFAULT_INFRA_FEE);
        tokenMasterRouter.setAllowedTokenFactory(address(standardPoolFactory), true);
        tokenMasterRouter.setAllowedTokenFactory(address(stablePoolFactory), true);
        tokenMasterRouter.setAllowedTokenFactory(address(promotionalPoolFactory), true);
        vm.stopPrank();
    }

    function _signDeploymentParameters(
        uint256 signerKey_,
        DeploymentParameters memory deploymentParameters
    ) internal view returns (SignatureECDSA memory deploymentSignature) {
        bytes32 digest = 
            ECDSA.toTypedDataHash(
                ROUTER_DOMAIN_SEPARATOR, 
                _hashDeploymentParameters(deploymentParameters)
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey_, digest);
        deploymentSignature = SignatureECDSA({v: v, r: r, s: s});
    }

    function _hashDeploymentParameters(DeploymentParameters memory deploymentParameters) internal pure returns (bytes32 hash) {
        hash = keccak256(
            abi.encode(
                DEPLOYMENT_TYPEHASH,
                deploymentParameters.tokenFactory,
                deploymentParameters.tokenSalt,
                deploymentParameters.tokenAddress,
                deploymentParameters.blockTransactionsFromUntrustedChannels,
                deploymentParameters.restrictPairingToLists
            )
        );
    }

    mapping(address => uint256) private _buyerPermitNonces;

    function _signPermitTransfer(
        uint256 buyerKey_,
        address buyer,
        address token,
        BuyOrder memory buyOrder,
        SignedOrder memory signedOrder
    ) internal returns (bytes memory signature, uint256 permitNonce) {
        permitNonce = _buyerPermitNonces[buyer]++;
        bytes32 hashAdvanced = _hashBuyOrderPermitAdvancedData(buyOrder, signedOrder);
        bytes32 digest = 
            ECDSA.toTypedDataHash(
                transferValidator.domainSeparatorV4(), 
                keccak256(
                    abi.encode(
                        PERMITTED_TRANSFER_ADDITIONAL_DATA_BUY_TYPEHASH,
                        20,
                        token,
                        0,
                        buyOrder.pairedValueIn,
                        permitNonce,
                        address(tokenMasterRouter),
                        type(uint256).max,
                        0,
                        hashAdvanced
                    )
                )
            );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerKey_, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _hashBuyOrderPermitAdvancedData(
        BuyOrder memory buyOrder,
        SignedOrder memory signedOrder
    ) internal pure returns(bytes32 hash) {
        hash = keccak256(
            abi.encode(
                PERMITTED_TRANSFER_BUY_TYPEHASH,
                buyOrder.tokenMasterToken,
                buyOrder.tokensToBuy,
                buyOrder.pairedValueIn,
                signedOrder.creatorIdentifier,
                signedOrder.hook,
                signedOrder.signature.v,
                signedOrder.signature.r,
                signedOrder.signature.s
            )
        );
    }


    function _signSignedOrder(
        address executor,
        uint256 signerKey_,
        address /*signer*/,
        uint256 cosignerKey_,
        address cosigner,
        uint256 cosignatureExpiration,
        bytes32 typehash,
        address tokenMasterToken,
        SignedOrder memory signedOrder
    ) internal view returns (SignatureECDSA memory signature, Cosignature memory cosignature) {
        bytes32 digest = _hashSignedOrder(typehash, tokenMasterToken, signedOrder, cosigner);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey_, digest);
        signature = SignatureECDSA({v: v, r: r, s: s});
        if (cosigner != address(0)) {
            digest = _hashCosignature(executor, signature, cosignatureExpiration);
            (v,r,s) = vm.sign(cosignerKey_, digest);
            cosignature = Cosignature({signer: cosigner, expiration: cosignatureExpiration, v: v, r: r, s: s});
        }
    }

    function _hashSignedOrder(
        bytes32 typehash,
        address tokenMasterToken,
        SignedOrder memory signedOrder,
        address cosigner
    ) internal view returns (bytes32 orderDigest) {
        orderDigest = 
            ECDSA.toTypedDataHash(
                ROUTER_DOMAIN_SEPARATOR, 
                keccak256(
                    abi.encode(
                        typehash,
                        signedOrder.creatorIdentifier,
                        tokenMasterToken,
                        signedOrder.tokenMasterOracle,
                        signedOrder.baseToken,
                        signedOrder.baseValue,
                        signedOrder.maxPerWallet,
                        signedOrder.maxTotal,
                        signedOrder.expiration,
                        signedOrder.hook,
                        cosigner
                    )
                )
            );
    }

    function _hashCosignature(address executor, SignatureECDSA memory signature, uint256 expiration) internal view returns (bytes32 cosignatureDigest) {
        cosignatureDigest = 
            ECDSA.toTypedDataHash(
                ROUTER_DOMAIN_SEPARATOR, 
                keccak256(
                    abi.encode(
                        COSIGNATURE_TYPEHASH,
                        signature.v,
                        signature.r,
                        signature.s,
                        expiration,
                        executor
                    )
                )
            );
    }

    function getSignedSpendOrderAndDigest(
        uint256 signerKey_, 
        SpendOrder memory spendOrder,
        SignedOrder memory signedOrder
    ) public view returns (SignatureECDSA memory signedSpendOrder, bytes32 spendOrderHash) {
        spendOrderHash = keccak256(
            abi.encode(
                SPEND_TYPEHASH,
                signedOrder.creatorIdentifier,
                spendOrder.tokenMasterToken,
                signedOrder.tokenMasterOracle,
                signedOrder.baseToken,
                signedOrder.baseValue,
                signedOrder.maxPerWallet,
                signedOrder.maxTotal,
                signedOrder.expiration,
                signedOrder.hook,
                signedOrder.cosignature.signer
            )
        );
        
        bytes32 digest = 
            ECDSA.toTypedDataHash(
                ROUTER_DOMAIN_SEPARATOR, 
                spendOrderHash
            );
    
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey_, digest);
        signedSpendOrder = SignatureECDSA({v: v, r: r, s: s});
    }

    bytes32 constant __DS_TYPE_HASH__ = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    function _getTokenMasterRouterDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                __DS_TYPE_HASH__, 
                keccak256(bytes("TokenMasterRouter")), 
                keccak256(bytes("1")), 
                block.chainid, 
                address(tokenMasterRouter)
            )
        );
    }
}