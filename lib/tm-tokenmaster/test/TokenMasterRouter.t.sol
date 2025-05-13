// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "./TokenMaster.t.sol";
import "src/interfaces/ITokenMasterRouter.sol";

contract TokenMasterRouterTest is TokenMasterTest {
    function testRouterRevertsWhenCallerIsNotAdmin() public {
        vm.expectRevert(TokenMasterRouter__CallerNotAllowed.selector);
        tokenMasterRouter.setAllowedTokenFactory(address(1), true);

        vm.expectRevert(TokenMasterRouter__CallerNotAllowed.selector);
        tokenMasterRouter.setInfrastructureFee(300);
    }

    function testRouterRevertsWhenFeeSetAboveBPS() public {
        vm.startPrank(TOKENMASTER_ADMIN);
        vm.expectRevert(TokenMasterRouter__InvalidInfrastructureFeeBPS.selector);
        tokenMasterRouter.setInfrastructureFee(BPS+1);
        vm.stopPrank();
    }

    function testRouterAdminCanSetFees() public {
        vm.startPrank(TOKENMASTER_ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenMasterRouter.InfrastructureFeeUpdated(500);
        tokenMasterRouter.setInfrastructureFee(500);
        vm.stopPrank();
    }

    function testRouterAdminCanSetAllowedFactories() public {
        vm.startPrank(TOKENMASTER_ADMIN);
        vm.expectEmit(true, true, true, true);
        emit ITokenMasterRouter.AllowedTokenFactoryUpdated(address(promotionalPoolFactory), false);
        tokenMasterRouter.setAllowedTokenFactory(address(promotionalPoolFactory), false);
        emit ITokenMasterRouter.AllowedTokenFactoryUpdated(address(promotionalPoolFactory), true);
        tokenMasterRouter.setAllowedTokenFactory(address(promotionalPoolFactory), true);
        vm.stopPrank();
    }

    function testRevertsWhenTokenIsNotDeployedByRouter() public {
        BuyOrder memory buyOrder;
        buyOrder.tokenMasterToken = address(0xC454);
        buyOrder.tokensToBuy = 1 ether;
        buyOrder.pairedValueIn = 1 ether;
        vm.expectRevert(TokenMasterRouter__TokenNotDeployedByTokenMaster.selector);
        tokenMasterRouter.buyTokens(buyOrder);
    }

    function testCodeSizeLimits() public view {
        _codeSizeCheck("TokenMasterRouter", address(tokenMasterRouter));
        _codeSizeCheck("StandardPoolFactory", address(standardPoolFactory));
        _codeSizeCheck("StablePoolFactory", address(stablePoolFactory));
        _codeSizeCheck("PromotionalPoolFactory", address(promotionalPoolFactory));
        _codeSizeCheck("StandardPoolCreationCode", standardPoolFactory.CREATION_CODE());
        _codeSizeCheck("StablePoolCreationCode", stablePoolFactory.CREATION_CODE());
        _codeSizeCheck("PromotionalPoolCreationCode", promotionalPoolFactory.CREATION_CODE());
    }

    function _codeSizeCheck(string memory _name, address _address) internal view {
        uint256 contractSize = _address.code.length;
        assertLe(contractSize, DEPLOYED_CODE_SIZE_LIMIT);
        console.log(string(bytes.concat(bytes(_name), bytes(" (Size): "))), contractSize);
        console.log(string(bytes.concat(bytes(_name), bytes(" (Remaining): "))), DEPLOYED_CODE_SIZE_LIMIT - contractSize);
    }

    function testFactoryCreationCodeHashesMatch() public view {
        assertEq(keccak256(standardPoolFactory.CREATION_CODE().code), keccak256(vm.getCode("StandardPool.sol:StandardPool")));
        assertEq(keccak256(stablePoolFactory.CREATION_CODE().code), keccak256(vm.getCode("StablePool.sol:StablePool")));
        assertEq(keccak256(promotionalPoolFactory.CREATION_CODE().code), keccak256(vm.getCode("PromotionalPool.sol:PromotionalPool")));
    }
}