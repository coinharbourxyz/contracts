// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProxyCall} from "../lib/ProxyCall.sol";
import {IAggregator} from "../lib/interfaces/IAggregator.sol";
/// @title ChainlinkProxy
/// @notice Contract that proxies calls to the dataFeedStore
/// @notice This contract is responsible for fetching data for one feed only
contract ChainlinkProxy is IAggregator {
    uint8 public immutable override decimals;
    uint32 public immutable override key;
    address public immutable override dataFeedStore;

    string public override description;

    /// @notice Constructor
    /// @param _description The description of the feed
    /// @param _decimals The decimals of the feed
    /// @param _key The key ID of the feed
    /// @param _dataFeedStore The address of the data feed store
    constructor(
        string memory _description,
        uint8 _decimals,
        uint32 _key,
        address _dataFeedStore
    ) {
        description = _description;
        decimals = _decimals;
        key = _key;
        dataFeedStore = _dataFeedStore;
    }

    function latestAnswer() external view override returns (int256) {
        return ProxyCall._latestAnswer(key, dataFeedStore);
    }

    function latestRound() external view override returns (uint256) {
        return ProxyCall._latestRound(key, dataFeedStore);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return ProxyCall._latestRoundData(key, dataFeedStore);
    }

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
