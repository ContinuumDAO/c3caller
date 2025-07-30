// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {C3Governor} from "../../src/gov/C3Governor.sol";
import {IC3Governor} from "../../src/gov/IC3Governor.sol";
import {C3ErrorParam} from "../../src/utils/C3CallerUtils.sol";
import {MockC3GovernDapp} from "../helpers/mocks/MockC3GovernDapp.sol";
import {Helpers} from "../helpers/Helpers.sol";
import {C3UUIDKeeper} from "../../src/uuid/C3UUIDKeeper.sol";
import {C3Caller} from "../../src/C3Caller.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TestGovernor} from "../helpers/mocks/TestGovernor.sol";

// TODO: Add tests for C3Governor
contract C3GovernorTest is Helpers {
    C3Governor public c3Governor;
    TestGovernor public testGovernor;
    C3UUIDKeeper public c3UUIDKeeper;
    C3Caller public c3Caller;
    MockC3GovernDapp public mockC3GovernDapp;
    
    uint256 public testDappID = 123;
    bytes32 public testProposalId = keccak256("test-proposal");
    
    // Test data for cross-chain calls
    uint256[] private testChainIds = [1, 137, 42161, 10, 56]; // Ethereum, Polygon, Arbitrum, Optimism, BSC
    string[] private testTargets = [
        "0x1234567890123456789012345678901234567890",
        "0x2345678901234567890123456789012345678901", 
        "0x3456789012345678901234567890123456789012",
        "0x4567890123456789012345678901234567890123",
        "0x5678901234567890123456789012345678901234"
    ];
    bytes[] private testCalldata = [
        abi.encodeWithSignature("transfer(address,uint256)", address(0x123), 1000),
        abi.encodeWithSignature("mint(address,uint256)", address(0x456), 500),
        abi.encodeWithSignature("burn(uint256)", 123),
        abi.encodeWithSignature("approve(address,uint256)", address(0x789), 2000),
        abi.encodeWithSignature("transferFrom(address,address,uint256)", address(0xabc), address(0xdef), 750)
    ];

    // Helper function to safely access test data
    function getTestChainId(uint256 index) internal view returns (uint256) {
        require(index < testChainIds.length, "Index out of bounds");
        return testChainIds[index];
    }

    function getTestTarget(uint256 index) internal view returns (string memory) {
        require(index < testTargets.length, "Index out of bounds");
        return testTargets[index];
    }

    function getTestCalldata(uint256 index) internal view returns (bytes memory) {
        require(index < testCalldata.length, "Index out of bounds");
        return testCalldata[index];
    }

    function setUp() public virtual override {
        super.setUp();

        // Deploy C3UUIDKeeper and C3Caller
        vm.startPrank(gov);
        c3UUIDKeeper = new C3UUIDKeeper();
        c3Caller = new C3Caller(address(c3UUIDKeeper));
        
        // Add operator permissions
        c3UUIDKeeper.addOperator(address(c3Caller));
        c3Caller.addOperator(gov);
        c3Caller.addOperator(mpc1);
        vm.stopPrank();

        // Deploy TestGovernor
        testGovernor = new TestGovernor("TestGovernor", IVotes(address(ctm)), 4, 1, 50400, 0);

        // Deploy C3Governor with gov as the governance contract
        c3Governor = new C3Governor(
            address(testGovernor), // Use testGovernor as the governance contract
            address(c3Caller),
            user1, // Use user1 as txSender like in C3GovernDapp test
            testDappID
        );

        // Deploy mock C3GovernDapp for comparison
        mockC3GovernDapp = new MockC3GovernDapp(
            address(testGovernor), // Use testGovernor as the governance contract
            address(c3Caller),
            user1, // Use user1 as txSender
            testDappID
        );
    }
}
