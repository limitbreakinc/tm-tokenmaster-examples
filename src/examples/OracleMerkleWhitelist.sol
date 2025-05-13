//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@limitbreak/tokenmaster/src/interfaces/ITokenMasterOracle.sol";

contract OracleMerkleWhitelist is ITokenMasterOracle {

    struct Adjust {
        uint256 numerator;
        uint256 denominator;
    }

    mapping(bytes32 => Adjust) private _adjustments;

    function adjustValue(
        uint256 /*transactionType*/,
        address executor, 
        address tokenMasterToken,
        address baseToken,
        uint256 baseValue,
        bytes calldata oracleExtraData
    ) external view returns(uint256 tokenValue) {
        tokenValue = baseValue;
        bytes32[] memory proof = abi.decode(oracleExtraData, (bytes32[]));
        if (proof.length > 0) {
            bytes32 root = bytes32(uint256(uint160(executor)));
            bytes32 leaf;
            for (uint256 i; i < proof.length; ++i) {
                leaf = proof[i];
                if (root < leaf) {
                    root = keccak256(abi.encode(root, leaf));
                } else {
                    root = keccak256(abi.encode(leaf, root));
                }
            }
            root = keccak256(abi.encode(tokenMasterToken, baseToken, root));
            Adjust memory adjustment = _adjustments[root];
            if (adjustment.numerator > 0) {
                tokenValue = tokenValue * adjustment.numerator / adjustment.denominator;
            }
        }
    }

    function setAdjustmentValue(bytes32 root, uint256 numerator, uint256 denominator) external {
        _adjustments[root] = Adjust({
            numerator: numerator,
            denominator: denominator
        });
    }
}