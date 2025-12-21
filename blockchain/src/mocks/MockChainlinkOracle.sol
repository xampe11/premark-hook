// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockChainlinkOracle
 * @notice Mock Chainlink oracle for testing prediction market resolution
 * @dev Implements AggregatorV3Interface with manual result setting
 */
contract MockChainlinkOracle is AggregatorV3Interface {
    uint8 public constant override decimals = 0;
    string public constant override description = "Mock Prediction Oracle";
    uint256 public constant override version = 1;

    struct RoundData {
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    mapping(uint80 => RoundData) public rounds;
    uint80 public latestRound;

    /**
     * @notice Set the result for the latest round
     * @param _answer The outcome (0 for NO, 1 for YES in binary markets)
     */
    function setLatestAnswer(int256 _answer) external {
        latestRound++;
        rounds[latestRound] = RoundData({
            answer: _answer, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: latestRound
        });
    }

    /**
     * @notice Set the result for the latest round with custom timestamp
     * @param _answer The outcome (0 for NO, 1 for YES in binary markets)
     * @param _updatedAt Custom timestamp for when the data was updated
     */
    function setLatestAnswerWithTimestamp(int256 _answer, uint256 _updatedAt) external {
        latestRound++;
        rounds[latestRound] = RoundData({
            answer: _answer, startedAt: _updatedAt, updatedAt: _updatedAt, answeredInRound: latestRound
        });
    }

    /**
     * @notice Get data about the latest round
     */
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory data = rounds[latestRound];
        return (latestRound, data.answer, data.startedAt, data.updatedAt, data.answeredInRound);
    }

    /**
     * @notice Get data about a specific round
     */
    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory data = rounds[_roundId];
        return (_roundId, data.answer, data.startedAt, data.updatedAt, data.answeredInRound);
    }
}
