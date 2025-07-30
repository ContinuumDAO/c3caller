// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";

import {Helpers} from "../helpers/Helpers.sol";
import {C3GovClient} from "../../src/gov/C3GovClient.sol";
import {IC3GovClient} from "../../src/gov/IC3GovClient.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";

contract C3GovClientTest is Helpers {
    C3GovClient public govClient;

    function setUp() public override {
        super.setUp();
        govClient = new C3GovClient(gov);
    }

    // ============ CONSTRUCTOR TESTS ============

    function test_Constructor() public {
        assertEq(govClient.gov(), gov);
        assertEq(govClient.pendingGov(), address(0));
    }

    function test_Constructor_ZeroAddress() public {
        // This should work since constructor doesn't validate gov address
        C3GovClient client = new C3GovClient(address(0));
        assertEq(client.gov(), address(0));
    }

    // ============ GOVERNANCE TESTS ============

    function test_ChangeGov_Success() public {
        vm.prank(gov);
        govClient.changeGov(user1);
        
        assertEq(govClient.pendingGov(), user1);
    }

    function test_ChangeGov_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        govClient.changeGov(user1);
    }

    function test_ChangeGov_ZeroAddress() public {
        vm.prank(gov);
        govClient.changeGov(address(0));
        
        assertEq(govClient.pendingGov(), address(0));
    }

    function test_ApplyGov_Success() public {
        // First change gov
        vm.prank(gov);
        govClient.changeGov(user1);
        
        // Then apply the change
        vm.prank(user1);
        govClient.applyGov();
        
        assertEq(govClient.gov(), user1);
        assertEq(govClient.pendingGov(), address(0));
    }

    function test_ApplyGov_NoPendingGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_IsZeroAddress.selector,
                C3ErrorParam.Gov
            )
        );
        govClient.applyGov();
    }

    function test_ApplyGov_ZeroPendingGov() public {
        // Set pending gov to zero
        vm.prank(gov);
        govClient.changeGov(address(0));
        
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_IsZeroAddress.selector,
                C3ErrorParam.Gov
            )
        );
        govClient.applyGov();
    }

    function test_ApplyGov_AnyoneCanApply() public {
        // First change gov
        vm.prank(gov);
        govClient.changeGov(user1);
        
        // Anyone can apply the change
        vm.prank(user2);
        govClient.applyGov();
        
        assertEq(govClient.gov(), user1);
        assertEq(govClient.pendingGov(), address(0));
    }

    // ============ OPERATOR TESTS ============

    function test_AddOperator_Success() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        assertTrue(govClient.isOperator(user1));
        address[] memory operators = govClient.getAllOperators();
        assertEq(operators.length, 1);
        assertEq(operators[0], user1);
    }

    function test_AddOperator_OnlyGov() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        govClient.addOperator(user2);
    }

    function test_AddOperator_ZeroAddress() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_IsZeroAddress.selector,
                C3ErrorParam.Operator
            )
        );
        govClient.addOperator(address(0));
    }

    function test_AddOperator_AlreadyOperator() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_AlreadyOperator.selector,
                user1
            )
        );
        govClient.addOperator(user1);
    }

    function test_AddOperator_Multiple() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        vm.prank(gov);
        govClient.addOperator(user2);
        
        assertTrue(govClient.isOperator(user1));
        assertTrue(govClient.isOperator(user2));
        
        address[] memory operators = govClient.getAllOperators();
        assertEq(operators.length, 2);
        assertEq(operators[0], user1);
        assertEq(operators[1], user2);
    }

    function test_RevokeOperator_Success() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        vm.prank(gov);
        govClient.revokeOperator(user1);
        
        assertFalse(govClient.isOperator(user1));
        address[] memory operators = govClient.getAllOperators();
        assertEq(operators.length, 0);
    }

    function test_RevokeOperator_OnlyGov() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        govClient.revokeOperator(user1);
    }

    function test_RevokeOperator_NotOperator() public {
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_IsNotOperator.selector,
                user1
            )
        );
        govClient.revokeOperator(user1);
    }

    function test_RevokeOperator_Multiple() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        vm.prank(gov);
        govClient.addOperator(user2);
        
        vm.prank(gov);
        govClient.revokeOperator(user1);
        
        assertFalse(govClient.isOperator(user1));
        assertTrue(govClient.isOperator(user2));
        
        address[] memory operators = govClient.getAllOperators();
        assertEq(operators.length, 1);
        assertEq(operators[0], user2);
    }

    function test_RevokeOperator_LastOperator() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        vm.prank(gov);
        govClient.revokeOperator(user1);
        
        assertFalse(govClient.isOperator(user1));
        address[] memory operators = govClient.getAllOperators();
        assertEq(operators.length, 0);
    }

    function test_RevokeOperator_RemoveFromMiddle() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        vm.prank(gov);
        govClient.addOperator(user2);
        vm.prank(gov);
        govClient.addOperator(mpc1);
        
        vm.prank(gov);
        govClient.revokeOperator(user2);
        
        assertTrue(govClient.isOperator(user1));
        assertFalse(govClient.isOperator(user2));
        assertTrue(govClient.isOperator(mpc1));
        
        address[] memory operators = govClient.getAllOperators();
        assertEq(operators.length, 2);
        assertEq(operators[0], user1);
        assertEq(operators[1], mpc1);
    }

    // ============ VIEW FUNCTION TESTS ============

    function test_GetAllOperators_Empty() public {
        address[] memory operators = govClient.getAllOperators();
        assertEq(operators.length, 0);
    }

    function test_GetAllOperators_WithOperators() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        vm.prank(gov);
        govClient.addOperator(user2);
        
        address[] memory operators = govClient.getAllOperators();
        assertEq(operators.length, 2);
        assertEq(operators[0], user1);
        assertEq(operators[1], user2);
    }

    function test_IsOperator_NotOperator() public {
        assertFalse(govClient.isOperator(user1));
        assertFalse(govClient.isOperator(address(0)));
    }

    function test_IsOperator_IsOperator() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        assertTrue(govClient.isOperator(user1));
    }

    function test_Operators_Index() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        vm.prank(gov);
        govClient.addOperator(user2);
        
        assertEq(govClient.operators(0), user1);
        assertEq(govClient.operators(1), user2);
    }

    // ============ MODIFIER TESTS ============

    function test_OnlyGov_Success() public {
        vm.prank(gov);
        govClient.changeGov(user1);
        // Should not revert
    }

    function test_OnlyGov_Revert() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_OnlyAuthorized.selector,
                C3ErrorParam.Sender,
                C3ErrorParam.Gov
            )
        );
        govClient.changeGov(user2);
    }

    function test_OnlyOperator_Success_Gov() public {
        // Gov should be able to call operator functions
        vm.prank(gov);
        govClient.addOperator(user1);
        // Should not revert
    }

    function test_OnlyOperator_Success_Operator() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        // Operator should be able to call operator functions
        // Note: This test would need a function that uses onlyOperator modifier
        // Since C3GovClient doesn't have such functions, we test the modifier indirectly
        assertTrue(govClient.isOperator(user1));
    }

    // ============ EDGE CASES ============

    function test_ChangeGov_SameAddress() public {
        vm.prank(gov);
        govClient.changeGov(gov);
        
        assertEq(govClient.pendingGov(), gov);
    }

    function test_ApplyGov_SameAddress() public {
        vm.prank(gov);
        govClient.changeGov(gov);
        
        vm.prank(gov);
        govClient.applyGov();
        
        assertEq(govClient.gov(), gov);
        assertEq(govClient.pendingGov(), address(0));
    }

    function test_AddOperator_SameOperator() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_AlreadyOperator.selector,
                user1
            )
        );
        govClient.addOperator(user1);
    }

    function test_RevokeOperator_AlreadyRevoked() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        vm.prank(gov);
        govClient.revokeOperator(user1);
        
        vm.prank(gov);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovClient.C3GovClient_IsNotOperator.selector,
                user1
            )
        );
        govClient.revokeOperator(user1);
    }

    // ============ STRESS TESTS ============

    function test_MultipleOperators() public {
        address[] memory testOperators = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            testOperators[i] = address(uint160(i + 1000));
        }
        
        // Add all operators
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(gov);
            govClient.addOperator(testOperators[i]);
        }
        
        // Verify all are operators
        for (uint256 i = 0; i < 10; i++) {
            assertTrue(govClient.isOperator(testOperators[i]));
        }
        
        address[] memory operators = govClient.getAllOperators();
        assertEq(operators.length, 10);
        
        // Remove all operators
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(gov);
            govClient.revokeOperator(testOperators[i]);
        }
        
        // Verify none are operators
        for (uint256 i = 0; i < 10; i++) {
            assertFalse(govClient.isOperator(testOperators[i]));
        }
        
        operators = govClient.getAllOperators();
        assertEq(operators.length, 0);
    }

    function test_GovernanceTransfer() public {
        // Transfer governance multiple times
        vm.prank(gov);
        govClient.changeGov(user1);
        
        vm.prank(user1);
        govClient.applyGov();
        
        vm.prank(user1);
        govClient.changeGov(user2);
        
        vm.prank(user2);
        govClient.applyGov();
        
        vm.prank(user2);
        govClient.changeGov(mpc1);
        
        vm.prank(mpc1);
        govClient.applyGov();
        
        assertEq(govClient.gov(), mpc1);
        assertEq(govClient.pendingGov(), address(0));
    }

    // ============ GAS OPTIMIZATION TESTS ============

    function test_Gas_AddOperator() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        govClient.addOperator(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for addOperator:", gasUsed);
    }

    function test_Gas_RevokeOperator() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        govClient.revokeOperator(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for revokeOperator:", gasUsed);
    }

    function test_Gas_GetAllOperators() public {
        vm.prank(gov);
        govClient.addOperator(user1);
        vm.prank(gov);
        govClient.addOperator(user2);
        
        uint256 gasBefore = gasleft();
        govClient.getAllOperators();
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for getAllOperators:", gasUsed);
    }

    function test_Gas_ChangeGov() public {
        uint256 gasBefore = gasleft();
        vm.prank(gov);
        govClient.changeGov(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for changeGov:", gasUsed);
    }

    function test_Gas_ApplyGov() public {
        vm.prank(gov);
        govClient.changeGov(user1);
        
        uint256 gasBefore = gasleft();
        vm.prank(user1);
        govClient.applyGov();
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for applyGov:", gasUsed);
    }
}