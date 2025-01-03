pragma solidity 0.8.24;

contract ForcePush {
    constructor(address dst) payable {
        selfdestruct(payable(dst));
    }
}