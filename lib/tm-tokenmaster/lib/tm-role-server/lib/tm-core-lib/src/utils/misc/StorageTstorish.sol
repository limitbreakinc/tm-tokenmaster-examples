pragma solidity ^0.8.24;

library StorageTstorish {   
    // keccak256(abi.encode(uint256(keccak256("storage.Tstorish")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DATA_STORAGE_SLOT = 
        0xdacd49f6a6c42b45a5c3d195b83b324104542d9147bb8064a39c6a8d23ba9b00;

    struct Data {
        // Indicates if TSTORE support has been activated during or post-deployment.
        bool tstoreSupport;
    }

    function data() internal pure returns (Data storage ptr) {
        bytes32 slot = DATA_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }
}