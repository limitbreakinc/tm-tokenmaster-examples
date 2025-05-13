pragma solidity 0.8.24;

import "@limitbreak/tm-core-lib/src/utils/security/IRoleClient.sol";

/**
 * @title  RoleServer
 * @author Limit Break, Inc.
 * @notice RoleServer stores holders of roles as defined by the RoleServer admin.
 *         Contracts using the RoleClient implementation may receive pushed updates
 *         from the RoleServer or may call the RoleServer to receive updated role
 *         holder data.
 */
contract RoleServer {
    /// @dev Emitted when the holder of a role is updated.
    event RoleUpdated(bytes32 indexed role, address indexed newRoleHolder);

    /// @dev Thrown when batch updating role holders and the array lengths are not equal.
    error RoleServer__ArrayLengthMismatch();
    /// @dev Thrown when a call is made to set a role and the caller is not the role server admin.
    error RoleServer__CallerMustBeAdmin();
    /// @dev Thrown when constructing the RoleServer and the supplied admin address is the zero address.
    error RoleServer__ZeroAddress();

    /// @dev Address of the administrator for the RoleServer.
    address private immutable INFRASTRUCTURE_ADMIN;

    /// @dev Mapping of roles to the role holders.
    mapping (bytes32 role => address roleHolder) private _roleHolders;
    
    constructor(address admin) {
        if (admin == address(0)) {
            revert RoleServer__ZeroAddress();
        }
        INFRASTRUCTURE_ADMIN = admin;
    }

    /**
     * @notice Returns the holder of a role.
     * 
     * @param role  The role to return role holder for.
     * 
     * @return roleHolder  The holder of the role.
     */
    function getRoleHolder(bytes32 role) external view returns (address roleHolder) {
        roleHolder = _roleHolders[role];
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
     * @param role        The role to set the holder of.
     * @param roleHolder  The address to set as the holder of the role.
     * @param clients     Array of client addresses to call `onRoleHolderChanged` on.
     */
    function setRoleHolder(bytes32 role, address roleHolder, IRoleClient[] calldata clients) external {
        if (msg.sender != INFRASTRUCTURE_ADMIN) {
            revert RoleServer__CallerMustBeAdmin();
        }

        _roleHolders[role] = roleHolder;
        emit RoleUpdated(role, roleHolder);

        for (uint256 i = 0; i < clients.length; ++i) {
            clients[i].onRoleHolderChanged(role, roleHolder);
        }
    }

    /**
     * @notice Updates the role holder for multiple roles.
     * 
     * @dev    Throws when called by an address that is not the admin.
     * @dev    <h4>Postconditions:</h4>
     * @dev    1. Role holder is updated in the storage mapping for each role/holder supplied.
     * @dev    2. A `RoleUpdated` event is emitted for each role/holder supplied.
     * @dev    3. `onRoleHolderChanged` is called on each client supplied in `clients`.
     * 
     * @param roles        Array of roles to set the holder of.
     * @param roleHolders  Array of addresses to set as the holders of roles.
     * @param clients      Array of client addresses to call `onRoleHolderChanged` on.
     */
    function setRoleHolders(
        bytes32[] calldata roles,
        address[] calldata roleHolders,
        IRoleClient[][] calldata clients
    ) external {
        if (msg.sender != INFRASTRUCTURE_ADMIN) {
            revert RoleServer__CallerMustBeAdmin();
        }
        if (roles.length != roleHolders.length || roles.length != clients.length) {
            revert RoleServer__ArrayLengthMismatch();
        }

        bytes32 role;
        address roleHolder;
        for (uint256 i = 0; i < roles.length; i++) {
            role = roles[i];
            roleHolder = roleHolders[i];

            _roleHolders[role] = roleHolder;
            emit RoleUpdated(role, roleHolder);

            IRoleClient[] calldata roleClients = clients[i];
            for (uint256 j = 0; j < roleClients.length; ++j) {
                roleClients[j].onRoleHolderChanged(role, roleHolder);
            }
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
            client.onRoleHolderChanged(role, _roleHolders[role]);
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
            revert RoleServer__ArrayLengthMismatch();
        }

        bytes32 role;
        address roleHolder;
        for (uint256 i = 0; i < roles.length; ++i) {
            role = roles[i];
            roleHolder = _roleHolders[role];

            IRoleClient[] calldata roleClients = clients[i];
            for (uint256 j = 0; j < roleClients.length; ++j) {
                roleClients[j].onRoleHolderChanged(role, roleHolder);
            }
        }
    }
}