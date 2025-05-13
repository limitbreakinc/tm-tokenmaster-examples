//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./DataTypes.sol";
import "../../interfaces/ITokenMasterERC20C.sol";

/**
 * @title  IPromotionalPool
 * @author Limit Break, Inc.
 * @notice Interface definition for a PromotionalPool contract.
 */
interface IPromotionalPool is ITokenMasterERC20C {
    event BuyParametersUpdated();

    function setBuyParameters(PromotionalPoolBuyParameters calldata _buyParameters) external;
    function getBuyParameters() external view returns(PromotionalPoolBuyParameters memory);
}