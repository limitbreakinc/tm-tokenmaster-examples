pragma solidity ^0.8.4;

import "./IRoleClient.sol";
import "./IRoleServer.sol";
import "../Errors.sol";

abstract contract RoleClient is IRoleClient {
    event RoleUpdatesRequested(address indexed roleServer, bytes32 indexed role);

    struct RoleRecord {
        address roleHolder;
        uint64 expiration;
        uint32 ttl;
    }

    IRoleServer private immutable _roleServer;

    struct RoleClientStorage {
        mapping (bytes32 role => RoleRecord record) roleRecords;
    }

    bytes32 private constant ROLE_CLIENT_STORAGE_SLOT = keccak256("storage.RoleClient");
    
    function roleClientStorage() internal pure returns (RoleClientStorage storage ptr) {
        bytes32 slot = ROLE_CLIENT_STORAGE_SLOT;
        assembly {
            ptr.slot := slot
        }
    }

    constructor(address roleServer) {
        if (roleServer == address(0)) {
            revert Error__BadConstructorArgument();
        }

        _roleServer = IRoleServer(roleServer);
        _setupRoles();
    }

    modifier callerHasRole(bytes32 role) {
        _requireCallerHasRole(role);
        _;
    }

    function onRoleHolderChanged(bytes32 role, address roleHolder) external {
        if (msg.sender != address(_roleServer)) {
            revert RoleClient__Unauthorized();
        }

        unchecked {
            RoleRecord storage record = roleClientStorage().roleRecords[role];
            record.roleHolder = roleHolder;
            record.expiration = uint64(block.timestamp + record.ttl);
        }
    }

    function _getRoleHolder(bytes32 role) internal returns (address roleHolder) {
        RoleRecord storage record = roleClientStorage().roleRecords[role];
        roleHolder = record.roleHolder;

        unchecked {
            if (record.expiration < block.timestamp) {
                roleHolder = _roleServer.getRoleHolder(role);
                record.roleHolder = roleHolder;
                record.expiration = uint64(block.timestamp + record.ttl);
            }
        }
    }

    function _getRoleHolderView(bytes32 role) internal view returns (address roleHolder) {
        RoleRecord storage record = roleClientStorage().roleRecords[role];
        roleHolder = record.roleHolder;

        unchecked {
            if (record.expiration < block.timestamp) {
                roleHolder = _roleServer.getRoleHolder(role);
            }
        }
    }

    function _requireCallerHasRole(bytes32 role) internal {
        if (msg.sender != _getRoleHolder(role)) {
            revert RoleClient__Unauthorized();
        }
    }

    function _setupRole(bytes32 role, uint32 ttl) internal {
        unchecked {
            RoleRecord storage record = roleClientStorage().roleRecords[role];
            record.roleHolder = _roleServer.getRoleHolder(role);
            record.ttl = ttl;
            record.expiration = uint64(block.timestamp) + ttl;
        }
    }

    function _setupRoles() internal virtual;
}