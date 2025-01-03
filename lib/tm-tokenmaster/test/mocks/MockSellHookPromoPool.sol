//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@limitbreak/tm-core-lib/src/token/erc721/ERC721C.sol";
import "src/interfaces/ITokenMasterSellHook.sol";
import "src/interfaces/IMinterBurnerRolePool.sol";

contract MockSellHookPromoPool is ITokenMasterSellHook {

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

    function tokenMasterSellHook(
        address tokenMasterToken,
        address seller,
        bytes32 creatorBuyIdentifier,
        uint256 amountSold,
        bytes calldata //hookExtraData
    ) external {
        if (!(tokenMasterToken == TOKEN_MASTER_TOKEN && creatorBuyIdentifier == CREATOR_BUY_IDENTIFIER && msg.sender == TOKEN_MASTER_ROUTER)) {
            revert();
        }
        PROMO_POOL.mint(seller, amountSold);
    }
}