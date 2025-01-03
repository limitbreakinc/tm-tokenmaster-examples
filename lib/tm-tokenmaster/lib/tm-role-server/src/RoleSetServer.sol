pragma solidity 0.8.24;

import "@limitbreak/tm-core-lib/src/utils/security/IRoleClient.sol";

/**
 * @title  RoleSetServer
 * @author Limit Break, Inc.
 * @notice RoleSetServer stores holders of roles as defined by the role set admin.
 *         Contracts using the RoleClient implementation may receive pushed updates
 *         from the RoleSetServer or may call the RoleSetServer to receive updated role
 *         holder data.
 */
contract RoleSetServer {
    /// @dev Struct that defines the pending admin and allowed transfer timestamp.
    struct PendingAdminTransfer {
        address pendingAdmin;
        uint96 allowedTransferTimestamp;
    }

    struct RoleHolder {
        address roleHolder;
        bool initialized;
        bool unclearable;
    }

    /// @dev Emitted when the holder of a role is updated.
    event RoleUpdated(bytes32 indexed role, address indexed newRoleHolder, bool clearable);
    /// @dev Emitted when a role set admin is updated.
    event RoleSetAdminUpdated(bytes32 indexed roleSet, address indexed prevAdmin, address indexed newAdmin);
    /// @dev Emitted when a role set admin is proposed to transfer to a new address.
    event RoleSetAdminPendingTransfer(bytes32 indexed roleSet, address indexed pendingAdmin, uint96 allowedTransferTimestamp);

    /// @dev Thrown when batch updating role holders and the array lengths are not equal.
    error RoleSetServer__ArrayLengthMismatch();
    /// @dev Thrown when a call is made to set a role and the caller is not the role server admin.
    error RoleSetServer__CallerMustBeAdmin();
    /// @dev Thrown when accepting an admin transfer when the caller is not the pending admin or it is before the allowed transfer time.
    error RoleSetServer__InvalidAdminTransfer();
    /// @dev Thrown when a call is made to create a role set and it already exists.
    error RoleSetServer__RoleSetAlreadyCreated();
    /// @dev Thrown when setting a role holder to the zero address when it is defined as unclearable.
    error RoleSetServer__RoleUnclearable();
    /// @dev Thrown when setting a role and clearable does not match its initial value.
    error RoleSetServer__ClearableMismatch();

    /// @dev Mapping of role sets to admins.
    mapping (bytes32 roleSet => address roleSetAdmin) public roleSetAdmin;
    /// @dev Mapping of role set to pending admin awaiting acceptance of admin transfer.
    mapping (bytes32 roleSet => PendingAdminTransfer pendingAdminTransfer) public roleSetPendingAdmin;

    /// @dev Mapping of roles to the role holders.
    mapping (bytes32 role => RoleHolder roleHolder) private _roleHolders;

    uint48 public constant ADMIN_TRANSFER_DELAY = 1 hours;

    modifier onlyRoleSetAdmin(bytes32 roleSet) {
        if (roleSetAdmin[roleSet] != msg.sender) {
            revert RoleSetServer__CallerMustBeAdmin();
        }
        _;
    }

    modifier onlyRoleSetPendingAdmin(bytes32 roleSet) {
        PendingAdminTransfer memory pendingAdminTransfer = roleSetPendingAdmin[roleSet];
        if (
            pendingAdminTransfer.pendingAdmin != msg.sender 
            || block.timestamp < pendingAdminTransfer.allowedTransferTimestamp
        ) {
            revert RoleSetServer__InvalidAdminTransfer();
        }
        _;
    }

    /**
     * @notice Creates a new role set on the role server that is initially owned by the caller.
     * 
     * @dev    Throws when the role set already exists.
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The caller is set as the role admin.
     * @dev    2. A `RoleSetAdminUpdated` event is emitted.
     * 
     * @param salt  A salt value for creating a unique role set for the admin.
     * 
     * @return roleSet  The role set that has been created.
     */
    function createRoleSet(bytes32 salt) external returns (bytes32 roleSet) {
        roleSet = keccak256(abi.encode(msg.sender, salt));
        if (roleSetAdmin[roleSet] != address(0)) {
            revert RoleSetServer__RoleSetAlreadyCreated();
        }
        roleSetAdmin[roleSet] = msg.sender;
        emit RoleSetAdminUpdated(roleSet, address(0), msg.sender);
    }

    /**
     * @notice Transfers ownership of a role set to a new admin. Utilizes a two-step transfer process that
     * @notice requires the new admin to accept the admin transfer.
     * 
     * @dev    Throws when the caller is not the current role set admin. 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The new admin is stored as the pending admin.
     * @dev    2. A `RoleSetAdminPendingTransfer` event is emitted.
     * 
     * @param roleSet   The role set to update the admin of.
     * @param newAdmin  Address of the new role set admin.
     */
    function transferRoleSetAdmin(bytes32 roleSet, address newAdmin) external onlyRoleSetAdmin(roleSet) {
        roleSetPendingAdmin[roleSet].pendingAdmin = newAdmin;
        uint96 allowedTransferTimestamp = uint96(block.timestamp + ADMIN_TRANSFER_DELAY);
        roleSetPendingAdmin[roleSet].allowedTransferTimestamp = allowedTransferTimestamp;

        emit RoleSetAdminPendingTransfer(roleSet, newAdmin, allowedTransferTimestamp);
    }

    /**
     * @notice Revokes an admin transfer for a role set prior to the new admin accepting.
     * 
     * @dev    Throws when the caller is not the current role set admin.
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The pending admin address is set to the zero address.
     * @dev    2. A `RoleSetAdminPendingTransfer` event is emitted.
     * 
     * @param roleSet   The role set to revoke the pending admin transfer of.
     */
    function revokeRoleSetAdminTransfer(bytes32 roleSet) external onlyRoleSetAdmin(roleSet) {
        delete roleSetPendingAdmin[roleSet];

        emit RoleSetAdminPendingTransfer(roleSet, address(0), 0);
    }

    /**
     * @notice Accepts the transfer of a role set admin by the pending admin.
     * 
     * @dev    Throws when the caller is not the pending role set admin.
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. The new admin is stored as the role set admin.
     * @dev    2. The pending admin is cleared from the role set pending admin mapping.
     * @dev    2. A `RoleSetAdminUpdated` event is emitted.
     * 
     * @param roleSet   The role set to update the admin of.
     */
    function acceptRoleSetAdmin(bytes32 roleSet) external onlyRoleSetPendingAdmin(roleSet) {
        address prevAdmin = roleSetAdmin[roleSet];
        roleSetAdmin[roleSet] = msg.sender;
        delete roleSetPendingAdmin[roleSet];

        emit RoleSetAdminUpdated(roleSet, prevAdmin, msg.sender);
    }

    /**
     * @notice Returns the holder of a role.
     * 
     * @param role  The role to return role holder for.
     * 
     * @return roleHolder  The holder of the role.
     */
    function getRoleHolder(bytes32 role) external view returns (address roleHolder) {
        roleHolder = _roleHolders[role].roleHolder;
    }

    /**
     * @notice Updates the role holder for a role.
     * 
     * @dev    Throws when called by an address that is not the admin.
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Role holder is updated in the storage mapping.
     * @dev    2. A `RoleUpdated` event is emitted.
     * @dev    3. `onRoleHolderChanged` is called on each client supplied in `clients`.
     * 
     * @param roleSet     The role set the role belongs to.
     * @param baseRole    The role to set the holder of prior to hashing with the role set.
     * @param newRoleHolder  The address to set as the holder of the role.
     * @param clients     Array of client addresses to call `onRoleHolderChanged` on.
     */
    function setRoleHolder(bytes32 roleSet, bytes32 baseRole, address newRoleHolder, bool clearable, IRoleClient[] calldata clients) external onlyRoleSetAdmin(roleSet) {
        _setRoleHolder(roleSet, baseRole, newRoleHolder, clearable, clients);
    }

    /**
     * @notice Updates the role holder for multiple roles.
     * 
     * @dev    Throws when called by an address that is not the admin of the role set.
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Role holder is updated in the storage mapping for each role/holder supplied.
     * @dev    2. A `RoleUpdated` event is emitted for each role/holder supplied.
     * @dev    3. `onRoleHolderChanged` is called on each client supplied in `clients`.
     * 
     * @param roleSet         The role set the roles belong to.
     * @param baseRoles       Array of roles to set the holder of.
     * @param newRoleHolders  Array of addresses to set as the holders of roles.
     * @param clients         Array of client addresses to call `onRoleHolderChanged` on.
     */
    function setRoleHolders(
        bytes32 roleSet,
        bytes32[] calldata baseRoles,
        address[] calldata newRoleHolders,
        bool[] calldata clearable,
        IRoleClient[][] calldata clients
    ) external onlyRoleSetAdmin(roleSet) {
        if (baseRoles.length != newRoleHolders.length 
            || baseRoles.length != clients.length 
            || baseRoles.length != clearable.length
        ) {
            revert RoleSetServer__ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < baseRoles.length; i++) {
            _setRoleHolder(roleSet, baseRoles[i], newRoleHolders[i], clearable[i], clients[i]);
        }
    }

    /**
     * @notice Pushes the latest role holder for an array of `roles` to `client`.
     * 
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. `onRoleHolderChanged` is called on `client` for each role in `roles`.
     * 
     * @param roles   Array of roles to update the `client` with.
     * @param client  Address of the client to call `onRoleHolderChanged` on.
     */
    function syncClient(bytes32[] calldata roles, IRoleClient client) external {
        bytes32 role;
        for (uint256 i = 0; i < roles.length; ++i) {
            role = roles[i];
            client.onRoleHolderChanged(role, _roleHolders[role].roleHolder);
        }
    }

    /**
     * @notice Pushes the latest role holder for an array of `roles` to an array of `clients`.
     * 
     * @dev    
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. `onRoleHolderChanged` is called on each client in `clients` for each role in `roles`.
     * 
     * @param roles    Array of roles to update the `client` with.
     * @param clients  Array of client addresses to call `onRoleHolderChanged` on.
     */
    function syncClients(bytes32[] calldata roles, IRoleClient[][] calldata clients) external {
        if (roles.length != clients.length) {
            revert RoleSetServer__ArrayLengthMismatch();
        }

        bytes32 role;
        address roleHolder;
        for (uint256 i = 0; i < roles.length; ++i) {
            role = roles[i];
            roleHolder = _roleHolders[role].roleHolder;

            IRoleClient[] calldata roleClients = clients[i];
            for (uint256 j = 0; j < roleClients.length; ++j) {
                roleClients[j].onRoleHolderChanged(role, roleHolder);
            }
        }
    }



    /**
     * @dev  Internal function to set a role holder.
     * 
     * @param roleSet        The role set the role belongs to.
     * @param baseRole       The role to set the holder of prior to hashing with the role set.
     * @param newRoleHolder  The address to set as the holder of the role.
     * @param clearable      True if the role is clearable in the future.
     * @param clients        Array of client addresses to call `onRoleHolderChanged` on.
     */
    function _setRoleHolder(bytes32 roleSet, bytes32 baseRole, address newRoleHolder, bool clearable, IRoleClient[] calldata clients) internal {
        bytes32 role = keccak256(abi.encode(roleSet, baseRole));

        RoleHolder storage _roleHolder = _roleHolders[role];
        if (_roleHolder.unclearable && newRoleHolder == address(0)) {
            revert RoleSetServer__RoleUnclearable();
        }
        if (_roleHolder.initialized) {
            if (_roleHolder.unclearable == clearable) {
                revert RoleSetServer__ClearableMismatch();
            }
        } else {
            _roleHolder.initialized = true;
            _roleHolder.unclearable = !clearable;
        }

        _roleHolder.roleHolder = newRoleHolder;
        emit RoleUpdated(role, newRoleHolder, clearable);

        for (uint256 i = 0; i < clients.length; ++i) {
            clients[i].onRoleHolderChanged(role, newRoleHolder);
        }
    }
}