//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@limitbreak/tokenmaster/src/interfaces/ITokenMasterOracle.sol";

contract OracleAlternateAssetPrice is ITokenMasterOracle {

    struct Adjust {
        uint256 numerator;
        uint256 denominator;
    }

    mapping(address => mapping(address => Adjust)) private _adjustments;

    function adjustValue(
        uint256 /*transactionType*/,
        address /*executor*/, 
        address tokenMasterToken,
        address baseToken,
        uint256 baseValue,
        bytes calldata //oracleExtraData
    ) external view returns(uint256 tokenValue) {
        Adjust memory adjustment = _adjustments[tokenMasterToken][baseToken];
        tokenValue = baseValue * adjustment.numerator / adjustment.denominator;
    }

    function setAdjustmentValue(address tokenMasterToken, address baseToken, uint256 numerator, uint256 denominator) external {
        _adjustments[tokenMasterToken][baseToken] = Adjust({
            numerator: numerator,
            denominator: denominator
        });
    }
}