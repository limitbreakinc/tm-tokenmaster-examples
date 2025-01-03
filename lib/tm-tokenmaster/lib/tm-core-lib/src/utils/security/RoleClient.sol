pragma solidity ^0.8.4;

import "./RoleClientBase.sol";

abstract contract RoleClient is RoleClientBase {

    constructor(address roleServer) RoleClientBase(roleServer) {
        _setupRoles();
    }

    function _setupRoles() internal virtual;
}