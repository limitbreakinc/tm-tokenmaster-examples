// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract Random {
    bytes32 private _lastHash;

    constructor(uint256 seed) {
        _lastHash = keccak256(abi.encodePacked(seed));
    }

    function getNext(uint256 min, uint256 max) public returns (uint256) {
        _lastHash = keccak256(abi.encodePacked(_lastHash));
        return min + uint256(_lastHash) % (max - min);
    }
}