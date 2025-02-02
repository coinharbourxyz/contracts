// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IAggregator.sol";
import {ProxyCall} from "./ProxyCall.sol";

/// @title ChainlinkProxy
/// @notice Contract that proxies calls to the dataFeedStore
/// @notice This contract is responsible for fetching data for one feed only
contract ChainlinkProxy is IAggregator {
    /// @inheritdoc IChainlinkAggregator
    uint8 public immutable override decimals;
    /// @inheritdoc IAggregator
    uint32 public immutable override key;
    /// @inheritdoc IAggregator
    address public immutable override dataFeedStore;

    /// @inheritdoc IChainlinkAggregator
    string public override description;

    /// @notice Constructor
    /// @param _decimals The decimals of the feed
    /// @param _key The key ID of the feed
    constructor(
        uint8 _decimals,
        uint32 _key
    ) {
        description = "Blocksense on EVM Sepolia";
        decimals = _decimals;
        key = _key;
        dataFeedStore = 0xeE5a4826068C5326a7f06fD6c7cBf816F096846c; // UpgradeableProxy contract on EVM Sepolia
    }

    /// @inheritdoc IChainlinkAggregator
    function latestAnswer() external view override returns (int256) {
        return ProxyCall._latestAnswer(key, dataFeedStore);
    }

    /// @inheritdoc IChainlinkAggregator
    function latestRound() external view override returns (uint256) {
        return ProxyCall._latestRound(key, dataFeedStore);
    }

    /// @inheritdoc IChainlinkAggregator
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return ProxyCall._latestRoundData(key, dataFeedStore);
    }

    /// @inheritdoc IChainlinkAggregator
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return ProxyCall._getRoundData(_roundId, key, dataFeedStore);
    }
}
