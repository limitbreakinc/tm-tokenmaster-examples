pragma solidity ^0.8.4;

interface IRoleClient {
    function onRoleHolderChanged(bytes32 /*role*/, address /*roleHolder*/) external;
}