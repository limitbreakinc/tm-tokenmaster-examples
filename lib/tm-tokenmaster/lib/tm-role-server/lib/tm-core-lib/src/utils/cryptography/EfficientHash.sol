// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title  EfficientHash
 * 
 * @author Limit Break
 * 
 * @notice Performs keccak256 hashing of value type parameters more efficiently than 
 * @notice high-level Solidity by utilizing scratch space for one or two values and
 * @notice efficient utilization of memory for parameter counts greater than two.
 * 
 * @notice Gas savings for EfficientHash compared to keccak256(abi.encode(...)):
 * @notice Parameter Count / Gas Savings (Shanghai) / Gas Savings (Cancun): 1 / 67 / 67
 * @notice Parameter Count / Gas Savings (Shanghai) / Gas Savings (Cancun): 5 / 66 / 66
 * @notice Parameter Count / Gas Savings (Shanghai) / Gas Savings (Cancun): 10 / 58 / 58
 * @notice Parameter Count / Gas Savings (Shanghai) / Gas Savings (Cancun): 15 / 1549 / 565
 * @notice Parameter Count / Gas Savings (Shanghai) / Gas Savings (Cancun): 20 / 3379 / 1027
 * @notice Parameter Count / Gas Savings (Shanghai) / Gas Savings (Cancun): 25 / 5807 / 1650
 * @notice Parameter Count / Gas Savings (Shanghai) / Gas Savings (Cancun): 50 / 23691 / 10107
 * @notice Parameter Count / Gas Savings (Shanghai) / Gas Savings (Cancun): 75 / 69164 / 41620
 * @notice Parameter Count / Gas Savings (Shanghai) / Gas Savings (Cancun): 99 / 172694 / 126646
 * 
 * @dev    Notes:
 * @dev    - `efficientHash` is overloaded for parameter counts between one and eight.
 * @dev    - Parameter counts between nine and sixteen require two functions to avoid
 * @dev        stack too deep errors. Each parameter count has a dedicated set of functions
 * @dev        (`efficientHashNineStep1`/`efficientHashNineStep2` ... `efficientHashSixteenStep1`/`efficientHashSixteenStep2`)
 * @dev        that must both be called to get the hash. 
 * @dev        `Step1` functions take eight parameters and return a memory pointer that is passed to `Step2`
 * @dev        `Step2` functions take the remaining parameters and return the hash of the values
 * @dev        Example: 
 * @dev              bytes32 hash = EfficientHash.efficientHashElevenStep2(
 * @dev                                   EfficientHash.efficientHashElevenStep1(
 * @dev                                       value1,
 * @dev                                       value2,
 * @dev                                       value3,
 * @dev                                       value4,
 * @dev                                       value5,
 * @dev                                       value6,
 * @dev                                       value7,
 * @dev                                       value8
 * @dev                                   ),
 * @dev                                   value9,
 * @dev                                   value10,
 * @dev                                   value11,
 * @dev                               );
 * @dev    - Parameter counts greater than sixteen must use the `Extension` functions.
 * @dev        Extension starts with `efficientHashExtensionStart` which takes the number
 * @dev        of parameters and the first eight parameters as an input and returns a
 * @dev        memory pointer that is passed to the `Continue` and `End` functions.
 * @dev        While the number of parameters remaining is greater than eight, call the
 * @dev        `efficientHashExtensionContinue` function with the pointer value and 
 * @dev        the next eight values.
 * @dev        When the number of parameters remaining is less than or equal to eight
 * @dev        call the `efficientHashExtensionEnd` function with the pointer value
 * @dev        and remaining values.
 * @dev        Example: 
 * @dev            bytes32 hash = EfficientHash.efficientHashExtensionEnd(
 * @dev                             EfficientHash.efficientHashExtensionContinue(
 * @dev                                 EfficientHash.efficientHashExtensionStart(
 * @dev                                     23,
 * @dev                                     value1,
 * @dev                                     value2,
 * @dev                                     value3,
 * @dev                                     value4,
 * @dev                                     value5,
 * @dev                                     value6,
 * @dev                                     value7,
 * @dev                                     value8
 * @dev                                 ), 
 * @dev                                 value9,
 * @dev                                 value10,
 * @dev                                 value11,
 * @dev                                 value12,
 * @dev                                 value13,
 * @dev                                 value14,
 * @dev                                 value15,
 * @dev                                 value16
 * @dev                             ),
 * @dev                             value17,
 * @dev                             value18,
 * @dev                             value19,
 * @dev                             value20,
 * @dev                             value21,
 * @dev                             value22,
 * @dev                             value23
 * @dev                         );
 */
library EfficientHash {
    
    /**
     * @notice Hashes one value type.
     * 
     * @param value The value to be hashed.
     * 
     * @return hash The hash of the value.
     */
    function efficientHash(bytes32 value) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(0x00, value)

            hash := keccak256(0x00, 0x20)
        }
    }
    
    /**
     * @notice Hashes two value types.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHash(bytes32 value1, bytes32 value2) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(0x00, value1)
            mstore(0x20, value2)
            
            hash := keccak256(0x00, 0x40)
        }
    }
    
    /**
     * @notice Hashes three value types.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHash(bytes32 value1, bytes32 value2, bytes32 value3) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x60))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            
            hash := keccak256(ptr, 0x60)
        }
    }
    
    /**
     * @notice Hashes four value types.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHash(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x80))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            
            hash := keccak256(ptr, 0x80)
        }
    }
    
    /**
     * @notice Hashes five value types.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHash(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0xA0))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            
            hash := keccak256(ptr, 0xA0)
        }
    }
    
    /**
     * @notice Hashes six value types.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHash(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0xC0))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            
            hash := keccak256(ptr, 0xC0)
        }
    }
    
    /**
     * @notice Hashes seven value types.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHash(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0xE0))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            
            hash := keccak256(ptr, 0xE0)
        }
    }
    
    /**
     * @notice Hashes eight value types.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHash(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x100))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            mstore(add(ptr, 0xE0), value8)
            
            hash := keccak256(ptr, 0x100)
        }
    }
    
    /**
     * @notice Step one of hashing nine values. Must be followed by `efficientHashNineStep2` to hash the values.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptr The memory pointer location for the values to hash.
     */
    function efficientHashNineStep1(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x120))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            mstore(add(ptr, 0xE0), value8)
        }
    }
    
    /**
     * @notice Step two of hashing nine values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value9  Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashNineStep2(
        uint256 ptr,
        bytes32 value9
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(add(ptr, 0x100), value9)

            hash := keccak256(ptr, 0x120)
        }
    }
    
    /**
     * @notice Step one of hashing ten values. Must be followed by `efficientHashTenStep2` to hash the values.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptr The memory pointer location for the values to hash.
     */
    function efficientHashTenStep1(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x140))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            mstore(add(ptr, 0xE0), value8)
        }
    }
    
    /**
     * @notice Step two of hashing ten values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value9  Value to be hashed.
     * @param value10 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashTenStep2(
        uint256 ptr,
        bytes32 value9, bytes32 value10
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(add(ptr, 0x100), value9)
            mstore(add(ptr, 0x120), value10)

            hash := keccak256(ptr, 0x140)
        }
    }
    
    /**
     * @notice Step one of hashing eleven values. Must be followed by `efficientHashElevenStep2` to hash the values.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptr The memory pointer location for the values to hash.
     */
    function efficientHashElevenStep1(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x160))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            mstore(add(ptr, 0xE0), value8)
        }
    }
    
    /**
     * @notice Step two of hashing eleven values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value9  Value to be hashed.
     * @param value10 Value to be hashed.
     * @param value11 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashElevenStep2(
        uint256 ptr,
        bytes32 value9, bytes32 value10, bytes32 value11
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(add(ptr, 0x100), value9)
            mstore(add(ptr, 0x120), value10)
            mstore(add(ptr, 0x140), value11)

            hash := keccak256(ptr, 0x160)
        }
    }
    
    /**
     * @notice Step one of hashing twelve values. Must be followed by `efficientHashTwelveStep2` to hash the values.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptr The memory pointer location for the values to hash.
     */
    function efficientHashTwelveStep1(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x180))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            mstore(add(ptr, 0xE0), value8)
        }
    }
    
    /**
     * @notice Step two of hashing twelve values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value9  Value to be hashed.
     * @param value10 Value to be hashed.
     * @param value11 Value to be hashed.
     * @param value12 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashTwelveStep2(
        uint256 ptr,
        bytes32 value9, bytes32 value10, bytes32 value11, bytes32 value12
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(add(ptr, 0x100), value9)
            mstore(add(ptr, 0x120), value10)
            mstore(add(ptr, 0x140), value11)
            mstore(add(ptr, 0x160), value12)

            hash := keccak256(ptr, 0x180)
        }
    }
    
    /**
     * @notice Step one of hashing thirteen values. Must be followed by `efficientHashThirteenStep2` to hash the values.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptr The memory pointer location for the values to hash.
     */
    function efficientHashThirteenStep1(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x1A0))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            mstore(add(ptr, 0xE0), value8)
        }
    }
    
    /**
     * @notice Step two of hashing thirteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value9  Value to be hashed.
     * @param value10 Value to be hashed.
     * @param value11 Value to be hashed.
     * @param value12 Value to be hashed.
     * @param value13 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashThirteenStep2(
        uint256 ptr,
        bytes32 value9, bytes32 value10, bytes32 value11, bytes32 value12,
        bytes32 value13
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(add(ptr, 0x100), value9)
            mstore(add(ptr, 0x120), value10)
            mstore(add(ptr, 0x140), value11)
            mstore(add(ptr, 0x160), value12)
            mstore(add(ptr, 0x180), value13)

            hash := keccak256(ptr, 0x1A0)
        }
    }
    
    /**
     * @notice Step one of hashing fourteen values. Must be followed by `efficientHashFourteenStep2` to hash the values.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptr The memory pointer location for the values to hash.
     */
    function efficientHashFourteenStep1(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x1C0))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            mstore(add(ptr, 0xE0), value8)
        }
    }
    
    /**
     * @notice Step two of hashing fourteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value9  Value to be hashed.
     * @param value10 Value to be hashed.
     * @param value11 Value to be hashed.
     * @param value12 Value to be hashed.
     * @param value13 Value to be hashed.
     * @param value14 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashFourteenStep2(
        uint256 ptr,
        bytes32 value9, bytes32 value10, bytes32 value11, bytes32 value12,
        bytes32 value13, bytes32 value14
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(add(ptr, 0x100), value9)
            mstore(add(ptr, 0x120), value10)
            mstore(add(ptr, 0x140), value11)
            mstore(add(ptr, 0x160), value12)
            mstore(add(ptr, 0x180), value13)
            mstore(add(ptr, 0x1A0), value14)

            hash := keccak256(ptr, 0x1C0)
        }
    }
    
    /**
     * @notice Step one of hashing fifteen values. Must be followed by `efficientHashFifteenStep2` to hash the values.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptr The memory pointer location for the values to hash.
     */
    function efficientHashFifteenStep1(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x1E0))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            mstore(add(ptr, 0xE0), value8)
        }
    }
    
    /**
     * @notice Step two of hashing fifteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value9  Value to be hashed.
     * @param value10 Value to be hashed.
     * @param value11 Value to be hashed.
     * @param value12 Value to be hashed.
     * @param value13 Value to be hashed.
     * @param value14 Value to be hashed.
     * @param value15 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashFifteenStep2(
        uint256 ptr,
        bytes32 value9, bytes32 value10, bytes32 value11, bytes32 value12,
        bytes32 value13, bytes32 value14, bytes32 value15
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(add(ptr, 0x100), value9)
            mstore(add(ptr, 0x120), value10)
            mstore(add(ptr, 0x140), value11)
            mstore(add(ptr, 0x160), value12)
            mstore(add(ptr, 0x180), value13)
            mstore(add(ptr, 0x1A0), value14)
            mstore(add(ptr, 0x1C0), value15)

            hash := keccak256(ptr, 0x1E0)
        }
    }
    
    /**
     * @notice Step one of hashing sixteen values. Must be followed by `efficientHashSixteenStep2` to hash the values.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptr The memory pointer location for the values to hash.
     */
    function efficientHashSixteenStep1(
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x200))

            mstore(ptr, value1)
            mstore(add(ptr, 0x20), value2)
            mstore(add(ptr, 0x40), value3)
            mstore(add(ptr, 0x60), value4)
            mstore(add(ptr, 0x80), value5)
            mstore(add(ptr, 0xA0), value6)
            mstore(add(ptr, 0xC0), value7)
            mstore(add(ptr, 0xE0), value8)
        }
    }
    
    /**
     * @notice Step two of hashing sixteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value9  Value to be hashed.
     * @param value10 Value to be hashed.
     * @param value11 Value to be hashed.
     * @param value12 Value to be hashed.
     * @param value13 Value to be hashed.
     * @param value14 Value to be hashed.
     * @param value15 Value to be hashed.
     * @param value16 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashSixteenStep2(
        uint256 ptr,
        bytes32 value9, bytes32 value10, bytes32 value11, bytes32 value12,
        bytes32 value13, bytes32 value14, bytes32 value15, bytes32 value16
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            mstore(add(ptr, 0x100), value9)
            mstore(add(ptr, 0x120), value10)
            mstore(add(ptr, 0x140), value11)
            mstore(add(ptr, 0x160), value12)
            mstore(add(ptr, 0x180), value13)
            mstore(add(ptr, 0x1A0), value14)
            mstore(add(ptr, 0x1C0), value15)
            mstore(add(ptr, 0x1E0), value16)

            hash := keccak256(ptr, 0x200)
        }
    }
    
    /**
     * @notice Step one of hashing more than sixteen values.
     * @notice Must be followed by at least one call to 
     * @notice `efficientHashExtensionContinue` and completed with
     * @notice a call to `efficientHashExtensionEnd` with the remaining
     * @notice values.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptr The memory pointer location for the values to hash.
     */
    function efficientHashExtensionStart(
        uint256 numberOfValues,
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
            mstore(0x40, add(add(ptr, 0x20), mul(numberOfValues, 0x20)))
            mstore(ptr, 0x100)
            
            mstore(add(ptr, 0x20), value1)
            mstore(add(ptr, 0x40), value2)
            mstore(add(ptr, 0x60), value3)
            mstore(add(ptr, 0x80), value4)
            mstore(add(ptr, 0xA0), value5)
            mstore(add(ptr, 0xC0), value6)
            mstore(add(ptr, 0xE0), value7)
            mstore(add(ptr, 0x100), value8)
        }
    }
    
    /**
     * @notice Second step of hashing more than sixteen values.
     * @notice Adds another eight values to the values to be hashed.
     * @notice May be called as many times as necessary until the values
     * @notice remaining to be added to the hash is less than or equal to
     * @notice eight.
     * 
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return ptrReturn The memory pointer location for the values to hash.
     */
    function efficientHashExtensionContinue(
        uint256 ptr,
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(uint256 ptrReturn) {
        assembly ("memory-safe") {
            ptrReturn := ptr
            let length := mload(ptrReturn)
            mstore(ptrReturn, add(length, 0x100))

            ptr := add(ptrReturn, length)
            
            mstore(add(ptr, 0x20), value1)
            mstore(add(ptr, 0x40), value2)
            mstore(add(ptr, 0x60), value3)
            mstore(add(ptr, 0x80), value4)
            mstore(add(ptr, 0xA0), value5)
            mstore(add(ptr, 0xC0), value6)
            mstore(add(ptr, 0xE0), value7)
            mstore(add(ptr, 0x100), value8)
        }
    }

    /**
     * @notice Final step of hashing more than sixteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value1 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashExtensionEnd(
        uint256 ptr,
        bytes32 value1
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptrStart := ptr
            let length := mload(ptrStart)

            ptr := add(ptrStart, length)
            
            mstore(add(ptr, 0x20), value1)

            hash := keccak256(add(ptrStart, 0x20), add(length, 0x20))
        }
    }

    /**
     * @notice Final step of hashing more than sixteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashExtensionEnd(
        uint256 ptr,
        bytes32 value1, bytes32 value2
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptrStart := ptr
            let length := mload(ptrStart)

            ptr := add(ptrStart, length)
            
            mstore(add(ptr, 0x20), value1)
            mstore(add(ptr, 0x40), value2)

            hash := keccak256(add(ptrStart, 0x20), add(length, 0x40))
        }
    }

    /**
     * @notice Final step of hashing more than sixteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashExtensionEnd(
        uint256 ptr,
        bytes32 value1, bytes32 value2, bytes32 value3
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptrStart := ptr
            let length := mload(ptrStart)

            ptr := add(ptrStart, length)
            
            mstore(add(ptr, 0x20), value1)
            mstore(add(ptr, 0x40), value2)
            mstore(add(ptr, 0x60), value3)

            hash := keccak256(add(ptrStart, 0x20), add(length, 0x60))
        }
    }

    /**
     * @notice Final step of hashing more than sixteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashExtensionEnd(
        uint256 ptr,
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptrStart := ptr
            let length := mload(ptrStart)

            ptr := add(ptrStart, length)
            
            mstore(add(ptr, 0x20), value1)
            mstore(add(ptr, 0x40), value2)
            mstore(add(ptr, 0x60), value3)
            mstore(add(ptr, 0x80), value4)

            hash := keccak256(add(ptrStart, 0x20), add(length, 0x80))
        }
    }

    /**
     * @notice Final step of hashing more than sixteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashExtensionEnd(
        uint256 ptr,
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptrStart := ptr
            let length := mload(ptrStart)

            ptr := add(ptrStart, length)
            
            mstore(add(ptr, 0x20), value1)
            mstore(add(ptr, 0x40), value2)
            mstore(add(ptr, 0x60), value3)
            mstore(add(ptr, 0x80), value4)
            mstore(add(ptr, 0xA0), value5)

            hash := keccak256(add(ptrStart, 0x20), add(length, 0xA0))
        }
    }

    /**
     * @notice Final step of hashing more than sixteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashExtensionEnd(
        uint256 ptr,
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptrStart := ptr
            let length := mload(ptrStart)

            ptr := add(ptrStart, length)
            
            mstore(add(ptr, 0x20), value1)
            mstore(add(ptr, 0x40), value2)
            mstore(add(ptr, 0x60), value3)
            mstore(add(ptr, 0x80), value4)
            mstore(add(ptr, 0xA0), value5)
            mstore(add(ptr, 0xC0), value6)

            hash := keccak256(add(ptrStart, 0x20), add(length, 0xC0))
        }
    }

    /**
     * @notice Final step of hashing more than sixteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashExtensionEnd(
        uint256 ptr,
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptrStart := ptr
            let length := mload(ptrStart)

            ptr := add(ptrStart, length)
            
            mstore(add(ptr, 0x20), value1)
            mstore(add(ptr, 0x40), value2)
            mstore(add(ptr, 0x60), value3)
            mstore(add(ptr, 0x80), value4)
            mstore(add(ptr, 0xA0), value5)
            mstore(add(ptr, 0xC0), value6)
            mstore(add(ptr, 0xE0), value7)

            hash := keccak256(add(ptrStart, 0x20), add(length, 0xE0))
        }
    }

    /**
     * @notice Final step of hashing more than sixteen values.
     * 
     * @param ptr    The memory pointer location for the values to hash.
     * @param value1 Value to be hashed.
     * @param value2 Value to be hashed.
     * @param value3 Value to be hashed.
     * @param value4 Value to be hashed.
     * @param value5 Value to be hashed.
     * @param value6 Value to be hashed.
     * @param value7 Value to be hashed.
     * @param value8 Value to be hashed.
     * 
     * @return hash The hash of the values.
     */
    function efficientHashExtensionEnd(
        uint256 ptr,
        bytes32 value1, bytes32 value2, bytes32 value3, bytes32 value4,
        bytes32 value5, bytes32 value6, bytes32 value7, bytes32 value8
    ) internal pure returns(bytes32 hash) {
        assembly ("memory-safe") {
            let ptrStart := ptr
            let length := mload(ptrStart)

            ptr := add(ptrStart, length)
            
            mstore(add(ptr, 0x20), value1)
            mstore(add(ptr, 0x40), value2)
            mstore(add(ptr, 0x60), value3)
            mstore(add(ptr, 0x80), value4)
            mstore(add(ptr, 0xA0), value5)
            mstore(add(ptr, 0xC0), value6)
            mstore(add(ptr, 0xE0), value7)
            mstore(add(ptr, 0x100), value8)

            hash := keccak256(add(ptrStart, 0x20), add(length, 0x100))
        }
    }
}
