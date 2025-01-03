//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

import "./DataTypes.sol";
import "../../interfaces/ICreatorEmissionsPool.sol";
import "../../interfaces/ITokenMasterERC20C.sol";

/**
 * @title  IStandardPool
 * @author Limit Break, Inc.
 * @notice Interface definition for a StandardPool contract.
 */
interface IStandardPool is ICreatorEmissionsPool, ITokenMasterERC20C {
    event BuyParametersUpdated();
    event SellParametersUpdated();
    event SpendParametersUpdated();

    function setBuyParameters(StandardPoolBuyParameters calldata _buyParameters) external;
    function setSellParameters(StandardPoolSellParameters calldata _sellParameters) external;
    function setSpendParameters(StandardPoolSpendParameters calldata _spendParameters) external;
    function getBuyParameters() external view returns(StandardPoolBuyParameters memory);
    function getSellParameters() external view returns(StandardPoolSellParameters memory);
    function getSpendParameters() external view returns(StandardPoolSpendParameters memory);
    function targetSupply() external view returns(bool useTargetSupply, uint256 target);
    function getParameterGuardrails() external view returns(
        uint16 minBuySpreadBPS,
        uint16 maxBuySpreadBPS,
        uint16 maxBuyFeeBPS,
        uint16 maxBuyDemandFeeBPS,
        uint16 minSellSpreadBPS,
        uint16 maxSellSpreadBPS,
        uint16 maxSellFeeBPS,
        uint16 maxSpendCreatorShareBPS
    );
}