pragma solidity ^0.8.24;

/*
                                                     @@@@@@@@@@@@@@             
                                                    @@@@@@@@@@@@@@@@@@(         
                                                   @@@@@@@@@@@@@@@@@@@@@        
                                                  @@@@@@@@@@@@@@@@@@@@@@@@      
                                                           #@@@@@@@@@@@@@@      
                                                               @@@@@@@@@@@@     
                            @@@@@@@@@@@@@@*                    @@@@@@@@@@@@     
                           @@@@@@@@@@@@@@@     @               @@@@@@@@@@@@     
                          @@@@@@@@@@@@@@@     @                @@@@@@@@@@@      
                         @@@@@@@@@@@@@@@     @@               @@@@@@@@@@@@      
                        @@@@@@@@@@@@@@@     #@@             @@@@@@@@@@@@/       
                        @@@@@@@@@@@@@@.     @@@@@@@@@@@@@@@@@@@@@@@@@@@         
                       @@@@@@@@@@@@@@@     @@@@@@@@@@@@@@@@@@@@@@@@@            
                      @@@@@@@@@@@@@@@     @@@@@@@@@@@@@@@@@@@@@@@@@             
                     @@@@@@@@@@@@@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@@@           
                    @@@@@@@@@@@@@@@     @@@@@&%%%%%%%%&&@@@@@@@@@@@@@@          
                    @@@@@@@@@@@@@@      @@@@@               @@@@@@@@@@@         
                   @@@@@@@@@@@@@@@     @@@@@                 @@@@@@@@@@@        
                  @@@@@@@@@@@@@@@     @@@@@@                 @@@@@@@@@@@        
                 @@@@@@@@@@@@@@@     @@@@@@@                 @@@@@@@@@@@        
                @@@@@@@@@@@@@@@     @@@@@@@                 @@@@@@@@@@@&        
                @@@@@@@@@@@@@@     *@@@@@@@               (@@@@@@@@@@@@         
               @@@@@@@@@@@@@@@     @@@@@@@@             @@@@@@@@@@@@@@          
              @@@@@@@@@@@@@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@           
             @@@@@@@@@@@@@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            
            @@@@@@@@@@@@@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@              
           .@@@@@@@@@@@@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                 
           @@@@@@@@@@@@@@%     @@@@@@@@@@@@@@@@@@@@@@@@(                        
          @@@@@@@@@@@@@@@                                                       
         @@@@@@@@@@@@@@@                                                        
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                         
       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                          
       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&                                          
      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                           
 
* @title Delegate Call
* @author Limit Break, Inc.
* @notice This contract is a set of modifiers which allow for functions to delegatecall to other contracts with a defined
*         function selector and calldata. This is useful for getting around the 24KB contract size limit in Solidity, as
*         more complex contracts can be split into multiple contracts and called via delegatecall.
*
*         It is important to note that delegatecall is designed to support both normal and trusted forwarder calls, and
*         when implementing a trusted forwarder you **MUST** compare the calldata length to an expected length based on 
*         the function signature. If the calldata length is greater than the expected length, it must be exactly 20 
*         bytes greater, and that would be the originating msg.sender from the forwarder.
*/

abstract contract DelegateCall {
    /**
     * @dev Function modifier that generates a delegatecall to `module` with `selector` and `data` as the 
     * @dev calldata. This delegatecall is for functions that have parameters but **DO NOT** take domain
     * @dev separator as a parameter. Additional calldata from a trusted forwarder is appended to the end, when present.
     * 
     * @param module The contract address being called in the delegatecall.
     * @param selector The 4 byte function selector for the function to call in `module`.
     * @param data The calldata to send to the `module`.
     */
    modifier delegateCall(address module, bytes4 selector, bytes calldata data) {
        assembly {
            // This protocol is designed to work both via direct calls and calls from a trusted forwarder that
            // preserves the original msg.sender by appending an extra 20 bytes to the calldata.  
            // The following code supports both cases.  The magic number of 68 is:
            // 4 bytes for the selector
            // 32 bytes calldata offset to the data parameter
            // 32 bytes for the length of the data parameter
            let lengthWithAppendedCalldata := sub(calldatasize(), 68)

            let ptr := mload(0x40)
            mstore(ptr, selector)
            calldatacopy(add(ptr,0x04), data.offset, lengthWithAppendedCalldata)
            mstore(0x40, add(ptr,add(0x04, lengthWithAppendedCalldata)))

            let result := delegatecall(gas(), module, ptr, add(lengthWithAppendedCalldata, 4), 0, 0)
            if iszero(result) {
                // Call has failed, retrieve the error message and revert
                let size := returndatasize()
                returndatacopy(0, 0, size)
                revert(0, size)
            }
        }
        _;
    }

    /**
     * @dev Function modifier that is equivalent to the `delegateCall` modifier, but it returns the result of the
     *      delegatecall. This is useful for functions that return a value, but was separated out to remove any
     *      overhead from the `delegateCall` modifier.
     *
     * @param module The contract address being called in the delegatecall.
     * @param selector The 4 byte function selector for the function to call in `module`.
     * @param data The calldata to send to the `module`.
     */
    modifier delegateCallWithReturn(address module, bytes4 selector, bytes calldata data) {
        assembly {
            // This protocol is designed to work both via direct calls and calls from a trusted forwarder that
            // preserves the original msg.sender by appending an extra 20 bytes to the calldata.
            // The following code supports both cases.  The magic number of 68 is:
            // 4 bytes for the selector
            // 32 bytes calldata offset to the data parameter
            // 32 bytes for the length of the data parameter
            let lengthWithAppendedCalldata := sub(calldatasize(), 68)

            let ptr := mload(0x40)
            mstore(ptr, selector)
            calldatacopy(add(ptr, 0x04), data.offset, lengthWithAppendedCalldata)
            mstore(0x40, add(ptr, add(0x04, lengthWithAppendedCalldata)))

            let result := delegatecall(gas(), module, ptr, add(lengthWithAppendedCalldata, 4), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)
            if iszero(result) {
                // Call has failed, retrieve the error message and revert
                revert(0, size)
            }
            return(0, size)
        }
        _;
    }

    /**
     * @dev Function modifier that generates a delegatecall to `module` with `selector` as the calldata
     * @dev This delegatecall is for functions that do not have parameters. The only calldata added is
     * @dev the extra calldata from a trusted forwarder, when present.
     *
     * @param module The contract address being called in the delegatecall.
     * @param selector The 4 byte function selector for the function to call in `module`.
     */
    modifier delegateCallNoData(address module, bytes4 selector) {
        assembly {
            // This protocol is designed to work both via direct calls and calls from a trusted forwarder that
            // preserves the original msg.sender by appending an extra 20 bytes to the calldata.
            // The following code supports both cases.

            let ptr := mload(0x40)
            mstore(ptr, selector)
            mstore(0x40, add(ptr, calldatasize()))
            calldatacopy(add(ptr, 0x04), 0x04, sub(calldatasize(), 0x04))
            let result := delegatecall(gas(), module, ptr, calldatasize(), 0, 0)
            if iszero(result) {
                // Call has failed, retrieve the error message and revert
                let size := returndatasize()
                returndatacopy(0, 0, size)
                revert(0, size)
            }
        }
        _;
    }
}
