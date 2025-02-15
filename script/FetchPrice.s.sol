// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ChainlinkProxy} from "../lib/ChainLinkProxy.sol";

contract FetchPrice is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy ChainlinkProxy contract
        ChainlinkProxy priceFeed = new ChainlinkProxy(
            18, // Decimals for output price
            3 // Feed ID as per https://docs.blocksense.network/docs/contracts/deployed-contracts?network=citrea-testnet#Aggregator%20Proxy%20Contracts
        );

        // Fetch the latest price
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // require(price > 0, "Invalid price");

        console.log("SOL/USD Price:", uint256(price));
        console.log("Timestamp:", updatedAt);
        console.log("Round ID:", roundId);

        vm.stopBroadcast();
    }
}
