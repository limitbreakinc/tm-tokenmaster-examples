//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@limitbreak/tm-core-lib/src/token/erc721/ERC721C.sol";
import "src/interfaces/ITokenMasterBuyHook.sol";
import "src/interfaces/IMinterBurnerRolePool.sol";

contract MockBuyHookPromoPool is ITokenMasterBuyHook {

    address private immutable TOKEN_MASTER_ROUTER;
    address private immutable TOKEN_MASTER_TOKEN;
    bytes32 private immutable CREATOR_BUY_IDENTIFIER;
    IMinterBurnerRolePool private immutable PROMO_POOL;

    constructor(
        address _tokenMasterRouter,
        address _tokenMasterToken,
        bytes32 _creatorBuyIdentifier,
        address _promoPool
    ) {
        TOKEN_MASTER_ROUTER = _tokenMasterRouter;
        TOKEN_MASTER_TOKEN = _tokenMasterToken;
        CREATOR_BUY_IDENTIFIER = _creatorBuyIdentifier;
        PROMO_POOL = IMinterBurnerRolePool(_promoPool);
    }

    function tokenMasterBuyHook(
        address tokenMasterToken,
        address buyer,
        bytes32 creatorBuyIdentifier,
        uint256 amountPurchased,
        bytes calldata //hookExtraData
    ) external {
        if (!(tokenMasterToken == TOKEN_MASTER_TOKEN && creatorBuyIdentifier == CREATOR_BUY_IDENTIFIER && msg.sender == TOKEN_MASTER_ROUTER)) {
            revert();
        }
        PROMO_POOL.mint(buyer, amountPurchased);
    }
}