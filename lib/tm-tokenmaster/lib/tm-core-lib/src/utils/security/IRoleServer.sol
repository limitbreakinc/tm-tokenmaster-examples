pragma solidity ^0.8.4;

interface IRoleServer {
    function getRoleHolder(bytes32 /*role*/) external view returns (address);
    function setRoleHolder(bytes32 /*role*/, address /*authority*/, address[] calldata /*clients*/) external;
}