pragma solidity ^0.8.4;

import "./OwnablePermissions.sol";
import "./Ownable.sol";

abstract contract OwnableBasic is OwnablePermissions, Ownable {
    function _requireCallerIsContractOwner() internal view virtual override {
        _checkOwner();
    }
}
