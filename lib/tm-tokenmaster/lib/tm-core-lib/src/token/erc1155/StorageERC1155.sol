pragma solidity ^0.8.4;

library StorageERC1155 {
    bytes32 private constant DATA_STORAGE_SLOT = keccak256("storage.ERC1155");

    struct Data {
        string uri;
        mapping(bytes32 => uint256) balances;
        mapping(bytes32 => bool) operatorApprovals;
    }

    function data() internal pure returns (Data storage ptr) {
        bytes32 slot = DATA_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }
}