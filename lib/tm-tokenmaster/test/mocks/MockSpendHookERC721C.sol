//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@limitbreak/tm-core-lib/src/token/erc721/ERC721C.sol";
import "src/interfaces/ITokenMasterSpendHook.sol";

contract MockSpendHookERC721C is ERC721C, ITokenMasterSpendHook {

    uint256 private nextTokenId;
    address private immutable TOKEN_MASTER_ROUTER;
    address private immutable TOKEN_MASTER_TOKEN;
    bytes32 private immutable CREATOR_SPEND_IDENTIFIER; 
    uint256 private immutable MAX_SUPPLY;

    constructor(address _tokenMasterRouter, address _tokenMasterToken, bytes32 _creatorSpendIdentifier, uint256 _maxSupply) CreatorTokenBase(address(1)) ERC721C("SpendHook", "SH") {
        TOKEN_MASTER_ROUTER = _tokenMasterRouter;
        TOKEN_MASTER_TOKEN = _tokenMasterToken;
        CREATOR_SPEND_IDENTIFIER = _creatorSpendIdentifier;
        MAX_SUPPLY = _maxSupply;
    }
    
    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

    function tokenMasterSpendHook(
        address tokenMasterToken,
        address spender,
        bytes32 creatorSpendIdentifier,
        uint256 multiplier,
        bytes calldata
    ) external {
        uint256 _nextTokenId = nextTokenId;
        uint256 endTokenId = _nextTokenId + multiplier;
        if (!(tokenMasterToken == TOKEN_MASTER_TOKEN && creatorSpendIdentifier == CREATOR_SPEND_IDENTIFIER && msg.sender == TOKEN_MASTER_ROUTER && endTokenId <= MAX_SUPPLY)) {
            revert();
        }
        nextTokenId = endTokenId;
        for (; _nextTokenId < endTokenId; ++_nextTokenId) {
            _mint(spender, _nextTokenId);
        }
    }

    function _requireCallerIsContractOwner() internal view override {

    }
}