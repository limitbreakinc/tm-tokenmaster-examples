//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./DataTypes.sol";
import "../../interfaces/ITokenMasterERC20C.sol";

/**
 * @title  IStablePool
 * @author Limit Break, Inc.
 * @notice Interface definition for a StablePool contract.
 */
interface IStablePool is ITokenMasterERC20C {
    event BuyParametersUpdated();
    event SellParametersUpdated();

    function setBuyParameters(StablePoolBuyParameters calldata _buyParameters) external;
    function setSellParameters(StablePoolSellParameters calldata _sellParameters) external;
    function getBuyParameters() external view returns(StablePoolBuyParameters memory);
    function getSellParameters() external view returns(StablePoolSellParameters memory);
    function getStablePriceRatio() external view returns(uint96 numerator, uint96 denominator);
    function getParameterGuardrails() external view returns (uint16 maxBuyFeeBPS, uint16 maxSellFeeBPS);
}