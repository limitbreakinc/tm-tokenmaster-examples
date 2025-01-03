pragma solidity ^0.8.24;

import "../misc/Tstorish.sol";

/**
 * @dev Variant of {ReentrancyGuard} that uses transient storage.
 *
 * NOTE: This variant only works on networks where EIP-1153 is available.
 */
abstract contract TstorishReentrancyGuard is Tstorish {

    // keccak256(abi.encode(uint256(keccak256("storage.TstorishReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    uint256 private constant REENTRANCY_GUARD_STORAGE = 
        0xeff9701f8ef712cda0f707f0a4f48720f142bf7e1bce9d4747c32b4eeb890500;

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() Tstorish() {
        if (!_tstoreInitialSupport) {
            _setTstorish(REENTRANCY_GUARD_STORAGE, NOT_ENTERED);
        }
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_getTstorish(REENTRANCY_GUARD_STORAGE) == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _setTstorish(REENTRANCY_GUARD_STORAGE, ENTERED);
    }

    function _nonReentrantAfter() private {
        _setTstorish(REENTRANCY_GUARD_STORAGE, NOT_ENTERED);
    }

    function _onTstoreSupportActivated() internal virtual override {
        _copyFromStorageToTransient(REENTRANCY_GUARD_STORAGE);
    }
}