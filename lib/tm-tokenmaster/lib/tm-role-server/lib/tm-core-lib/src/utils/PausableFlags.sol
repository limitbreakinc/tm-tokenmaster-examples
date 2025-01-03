//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
* @title CollateralizedPausableFlags
* @custom:version 1.0.0
* @author Limit Break, Inc.
* @description Pausable Flags is an extension for contracts that require features to be 
*              pausable in the event of potential or actual threats.
*/
abstract contract PausableFlags {

    /// @dev Emitted when the pausable flags are updated
    event PausableFlagsUpdated(uint256 previousFlags, uint256 newFlags);

    /// @dev Thrown when an execution path requires a flag to not be paused but it is paused
    error PausableFlags__Paused();
    /// @dev Thrown when an executin path requires a flag to be paused but it is not paused
    error PausableFlags__NotPaused();

    /// @dev Flags for current pausable state, each bit is considered a separate flag
    uint256 private pausableFlags;

    /**
     * @dev  Modifier to make a function callable only when the specified flags are not paused
     * @dev  Throws when any of the flags specified are paused
     * 
     * @param _flags  The flags to check for pause state
     */
    modifier whenNotPaused(uint256 _flags) {
        _requireNotPaused(_flags);
        _;
    }

    /**
     * @dev  Modifier to make a function callable only when the specified flags are paused
     * @dev  Throws when any of the flags specified are not paused
     * 
     * @param _flags  The flags to check for pause state
     */
    modifier whenPaused(uint256 _flags) {
        _requirePaused(_flags);
        _;
    }

    /**
     * @dev  Modifier to make a function callable only by a permissioned account
     * @dev  Throws when the caller does not have permission
     */
    modifier onlyPausePermissionedCaller() {
        _requireCallerHasPausePermissions();
        _;
    }

    /**
     * @notice  Updates the pausable flags settings
     * 
     * @dev     Throws when the caller does not have permission
     * @dev     **NOTE:** Pausable flag settings will only take effect if contract balance exceeds 
     * @dev     `nativeValueToPause`
     * 
     * @dev     <h4>Postconditions:</h4>
     * @dev     1. `pausableFlags` is set to the new value
     * @dev     2. Emits a PausableFlagsUpdated event
     * 
     * @param _pausableFlags  The new pausable flags to set
     */
    function pause(uint256 _pausableFlags) external virtual onlyPausePermissionedCaller {
        _setPausableFlags(_pausableFlags);
    }

    /**
     * @notice  Resets all pausable flags to unpaused and withdraws funds
     * 
     * @dev     Throws when the caller does not have permission
     * 
     * @dev     <h4>Postconditions:</h4>
     * @dev     1. `pausableFlags` is set to zero
     * @dev     2. Emits a PausableFlagsUpdated event
     */
    function unpause() external virtual onlyPausePermissionedCaller {
        _setPausableFlags(0);
    }

    /**
     * @notice  Returns collateralized pausable configuration information
     * 
     * @return _pausableFlags  The current pausable flags set, only checked when collateral met
     */
    function getPausableFlags() external view returns(
        uint256 _pausableFlags
    ) {
        _pausableFlags = pausableFlags;
    }

    /**
     * @notice  Updates the `pausableFlags` variable and emits a PausableFlagsUpdated event
     * 
     * @param _pausableFlags  The new pausable flags to set
     */
    function _setPausableFlags(uint256 _pausableFlags) internal {
        uint256 previousFlags = pausableFlags;

        pausableFlags = _pausableFlags;

        emit PausableFlagsUpdated(previousFlags, _pausableFlags);
    }

    /**
     * @notice  Checks the current pause state of the supplied flags and reverts if any are paused
     * 
     * @dev     Throws when one or more of the supplied `_flags` is paused.
     * 
     * @param _flags  The flags to check for pause state
     */
    function _requireNotPaused(uint256 _flags) internal view virtual {
        if (pausableFlags & _flags > 0) {
            revert PausableFlags__Paused();
        }
    }

    /**
     * @notice  Checks the current pause state of the supplied flags and reverts if none are paused
     * 
     * @dev     Throws when none of the supplied `_flags` are paused.
     * 
     * @param _flags  The flags to check for pause state
     */
    function _requirePaused(uint256 _flags) internal view virtual {
        if (pausableFlags & _flags == 0) {
            revert PausableFlags__NotPaused();
        }
    }

    /**
     * @notice  Returns the current state of the pausable flags
     * 
     * @return _pausableFlags  The current state of the pausable flags
     */
    function _getPausableFlags() internal view virtual returns(uint256 _pausableFlags) {
        _pausableFlags = pausableFlags;
    }

    /**
     * @dev  To be implemented by an inheriting contract for authorization to `pause` and `unpause` 
     * @dev  functions as well as any functions in the inheriting contract that utilize the
     * @dev  `onlyPausePermissionedCaller` modifier.
     * 
     * @dev  Implementing contract function **MUST** throw when the caller is not permissioned
     */
    function _requireCallerHasPausePermissions() internal view virtual;
}