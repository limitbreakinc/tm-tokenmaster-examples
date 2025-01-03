//SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
pragma solidity 0.8.24;

/**
 * @title  ICreatorEmissionsPool
 * @author Limit Break, Inc.
 * @notice Interface definition for pools that implement creator emissions.
 */
interface ICreatorEmissionsPool {
    /// @dev Emitted when the creator updates their hard cap for creator emissions.
    event CreatorEmissionsHardCapUpdated(uint256 newHardCapAmount);

    /// @dev Emitted when a creator claims emissions.
    event CreatorEmissionsClaimed(address to, uint256 claimedAmount, uint256 forfeitedAmount);
    
    function setEmissionsHardCap(uint256 newHardCapAmount) external;
    function claimEmissions(address claimTo, uint256 forfeitAmount) external;
    function getCreatorEmissions() external view returns(
        uint256 claimed,
        uint256 claimable,
        uint256 hardCap,
        uint48 lastClaim,
        uint128 creatorEmissionRateNumerator,
        uint128 creatorEmissionRateDenominator
    );
}