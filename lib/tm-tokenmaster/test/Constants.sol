// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

address constant FEE_COLLECTOR = address(0xFEEDFEEDFEED);
address constant TOKENMASTER_ADMIN = 0x591Aa9dfF01B8144DC17Cb416001D9aC84b951cd;
address constant FEE_RECIPIENT = address(0xFEEFEE);
address constant FEE_RECIPIENT_ALTERNATE = address(0x6ABE);
uint16 constant DEFAULT_INFRA_FEE = 100;
bytes32 constant CONFIG_SALT = bytes32(uint256(0));
bytes32 constant ROUTER_SALT = 0x00000000000000000000000000000000000000002a8cd6efed8f9c025bf7955c;
bytes32 constant STANDARD_POOL_SALT = bytes32(uint256(2));
bytes32 constant STABLE_POOL_SALT = bytes32(uint256(3));
bytes32 constant PROMOTIONAL_POOL_SALT = bytes32(uint256(4));
address constant ROLE_SERVER = 0x00000000d7b37203F54e165Fb204B57c30d15835;
bytes32 constant ROLE_SERVER_SALT = 0xee7195957f3048ece933d03b3633b52bb0a768b829eb3a57d6a5f95c8803fe8f;
bytes32 constant TOKENMASTER_ROLE_SERVER_SET_SALT = keccak256("TOKENMASTER_ROLES");

address constant TRUSTED_FORWARDER_FACTORY_ADDRESS = 0xFF0000B6c4352714cCe809000d0cd30A0E0c8DcE;
address constant TRUSTED_FORWARDER_ADDRESS = 0xFF000047aBEA9064C699c0727148776e4E17771C;
address constant KEYLESS_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

address constant TRANSFER_VALIDATOR_ADMIN = address(0xAAAA);

uint256 constant DEPLOYED_CODE_SIZE_LIMIT = 24576;

string constant PERMITC_ADVANCED_TYPEHASH_TO_REGISTER = "AdvancedBuyOrder advancedBuyOrder)AdvancedBuyOrder(address tokenMasterToken,uint256 tokensToBuy,uint256 pairedValueIn,bytes32 creatorBuyIdentifier,address hook,uint8 buyOrderSignatureV,bytes32 buyOrderSignatureR,bytes32 buyOrderSignatureS)";
