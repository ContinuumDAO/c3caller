// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title TestGovernor
 * @dev A simple Governor implementation for testing purposes that extends OpenZeppelin's Governor
 * with basic configuration and only the required overrides to make it compile.
 */
contract TestGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction
{
    /**
     * @dev Constructor for the test governor
     * @param _name Name of the governor
     * @param _token Voting token
     * @param _quorumPercentage Quorum percentage
     * @param _votingDelay Voting delay
     * @param _votingPeriod Voting period
     * @param _proposalThreshold Proposal threshold
     */
    constructor(
        string memory _name,
        IVotes _token,
        uint256 _quorumPercentage,
        uint48 _votingDelay,
        uint32 _votingPeriod,
        uint256 _proposalThreshold
    )
        Governor(_name)
        GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumPercentage)
    {}

    // ============ REQUIRED OVERRIDES ============

    /**
     * @dev Required override for GovernorCountingSimple
     */
    function _quorumReached(uint256 proposalId)
        internal
        view
        override(Governor, GovernorCountingSimple)
        returns (bool)
    {
        return quorum(proposalSnapshot(proposalId)) <= 1000; // Mock quorum check
    }

    /**
     * @dev Required override for GovernorCountingSimple
     */
    function _voteSucceeded(
        uint256 /*proposalId*/
    )
        internal
        pure
        override(Governor, GovernorCountingSimple)
        returns (bool)
    {
        return true; // Mock: always succeeds
    }

    /**
     * @dev Required override for GovernorCountingSimple
     */
    function _countVote(
        uint256,
        /*proposalId*/
        address,
        /*account*/
        uint8,
        /*support*/
        uint256 weight,
        bytes memory /*params*/
    )
        internal
        pure
        override(Governor, GovernorCountingSimple)
        returns (uint256)
    {
        // Basic vote counting implementation - just return the weight
        return weight;
    }

    /**
     * @dev Required override for proposalThreshold
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }
}
