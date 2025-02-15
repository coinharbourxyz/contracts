// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Swap.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract SwapTest is Test {
    Swap public swapper;
    address constant UNIVERSAL_ROUTER = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public {
        // Deploy the swap contract
        swapper = new Swap(UNIVERSAL_ROUTER);
    }

    function testSwapETHForUSDC() public {
        uint256 startingETH = address(this).balance;
        uint256 startingUSDC = IERC20(USDC).balanceOf(address(this));

        console.log("Starting ETH balance:", startingETH / 1e18, "ETH");
        console.log("Starting USDC balance:", startingUSDC / 1e6, "USDC");

        // Amount to swap: 1 ETH
        uint128 amountIn = 1 ether;
        uint128 minAmountOut = 1000000; // 1 USDC minimum

        // Perform the swap
        swapper.swap{value: amountIn}(
            address(0), // ETH
            USDC,
            3000, // 0.3% fee tier
            amountIn,
            minAmountOut,
            true // zeroForOne
        );

        uint256 endingETH = address(this).balance;
        uint256 endingUSDC = IERC20(USDC).balanceOf(address(this));

        console.log("Ending ETH balance:", endingETH / 1e18, "ETH");
        console.log("Ending USDC balance:", endingUSDC / 1e6, "USDC");

        // Assert that we received more than our minimum amount
        assert(endingUSDC >= minAmountOut);
        // Assert that we spent the ETH
        assert(endingETH == startingETH - amountIn);
    }

    // Required to receive ETH
    receive() external payable {}
}
