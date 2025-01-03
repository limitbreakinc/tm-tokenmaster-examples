pragma solidity ^0.8.4;

// General Purpose Custom Errors
error Error__BadConstructorArgument();

// Authorization Errors
error RoleClient__Unauthorized();

// Extensible Custom Errors
error Extensible__ConflictingFunctionSelectorAlreadyInstalled();
error Extensible__ExtensionAlreadyInstalled();
error Extensible__ExtensionNotInstalled();
error Extensible__InvalidExtension();