pragma solidity ^0.8.4;

library StorageERC20 {
    bytes32 private constant DATA_STORAGE_SLOT = keccak256("storage.ERC20");

    struct Data {
        uint256 totalSupply;

        string name;
        string symbol;

        mapping(address => uint256) balances;
        mapping (bytes32 => uint256) allowances;
    }

    function data() internal pure returns (Data storage ptr) {
        bytes32 slot = DATA_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }
}

library StorageERC20Initializable {
    bytes32 private constant DATA_STORAGE_SLOT = keccak256("storage.ERC20.Initializable");

    struct Data {
       bool erc20Initialized;
    }

    function data() internal pure returns (Data storage ptr) {
        bytes32 slot = DATA_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }
}