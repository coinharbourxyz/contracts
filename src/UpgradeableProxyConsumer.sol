// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProxyCall} from "../lib/ProxyCall.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract UpgradeableProxyConsumer {
    address public immutable dataFeedStore;

    constructor(address feedAddress) {
        dataFeedStore = feedAddress;
    }

    function getDataById(
        uint32 key
    ) external view returns (uint256 value, uint64 timestamp) {
        bytes32 data = ProxyCall._callDataFeed(
            dataFeedStore,
            abi.encodePacked(0x80000000 | key)
        );

        return (uint256(uint192(bytes24(data))), uint64(uint256(data)));
    }

    function getFeedAtCounter(
        uint32 key,
        uint32 counter
    ) external view returns (uint256 value, uint64 timestamp) {
        bytes32 data = ProxyCall._callDataFeed(
            dataFeedStore,
            abi.encodeWithSelector(bytes4(0x20000000 | key), counter)
        );

        return (uint256(uint192(bytes24(data))), uint64(uint256(data)));
    }

    function getLatestCounter(
        uint32 key
    ) external view returns (uint32 counter) {
        return uint32(ProxyCall._latestRound(key, dataFeedStore));
    }

    function getLatestRoundData(
        uint32 key
    ) external view returns (int256 value, uint256 timestamp, uint80 counter) {
        (counter, value, timestamp, , ) = ProxyCall._latestRoundData(
            key,
            dataFeedStore
        );
    }
}
