pragma solidity ^0.8.4;

import "./OwnablePermissions.sol";
import "./Ownable2Step.sol";

abstract contract Ownable2StepBasic is OwnablePermissions, Ownable2Step {
    function _requireCallerIsContractOwner() internal view virtual override {
        _checkOwner();
    }
}
