pragma solidity ^0.8.4;

library StorageERC721 {
    bytes32 private constant DATA_STORAGE_SLOT = keccak256("storage.ERC721");

    struct Data {
        string name;
        string symbol;

        mapping(uint256 => address) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => address) tokenApprovals;
        mapping(bytes32 => bool) operatorApprovals;
    }

    function data() internal pure returns (Data storage ptr) {
        bytes32 slot = DATA_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }
}