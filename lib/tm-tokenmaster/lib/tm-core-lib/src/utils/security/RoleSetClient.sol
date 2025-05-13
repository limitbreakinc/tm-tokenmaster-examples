pragma solidity ^0.8.4;

import "./RoleClientBase.sol";

abstract contract RoleSetClient is RoleClientBase {

    constructor(address roleServer, bytes32 roleSet) RoleClientBase(roleServer) {
        _setupRoles(roleSet);
    }

    function _hashRoleSetRole(
        bytes32 roleSet,
        bytes32 baseRole
    ) internal pure returns (bytes32 role) {
        role = keccak256(abi.encode(roleSet, baseRole));
    }

    function _setupRoles(bytes32 roleSet) internal virtual;
}