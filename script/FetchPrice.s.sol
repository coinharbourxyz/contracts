// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract FetchPrice is Script {
    function run() external view {
        // Mainnet ETH/USD price feed address
        address ethUsdPriceFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdPriceFeed);

        // Fetch the latest price
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");

        // Log the price
        console.log("ETH/USD Price:", uint256(price));
    }
} 