pragma solidity ^0.8.4;

abstract contract OwnablePermissions {
    function _requireCallerIsContractOwner() internal view virtual;
}
