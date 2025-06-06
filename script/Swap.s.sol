// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

import {PoolKey} from "v4-core/src/types/PoolKey.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {SafeCast} from "lib/v4-periphery/lib/v4-core/src/libraries/SafeCast.sol";

import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";

import {Currency} from "v4-core/src/types/Currency.sol";

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

/// @notice Forge script for deploying v4 & hooks to **anvil**
/// @dev This script only works on an anvil RPC because v4 exceeds bytecode limits
contract SwapTest is Script {
    using SafeCast for int128;
    using SafeCast for uint256;
    using SafeCast for int256;

    address payable universalRouter = payable(address(0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af));
    UniversalRouter public immutable router = UniversalRouter(universalRouter);

    address payable _permit2 = payable(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    IPermit2 public immutable permit2 = IPermit2(_permit2);

    function run() public {
        vm.startBroadcast();
        testLifecycle();

        vm.stopBroadcast();
    }

    function testLifecycle() internal {
        this.swapExactInputSingle(
            address(0), address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), 3000, 10 ether, 0, true
        );
        this.swapExactInputSingle(
            address(0), address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), 3000, 13774909557, 0, false
        );
    }

    function swapExactInputSingle(
        address token0,
        address token1,
        uint24 fee,
        uint128 amountIn,
        uint128 minAmountOut,
        bool _zeroForOne
    ) public returns (uint256 amountOut) {
        PoolKey memory key = PoolKey(
            Currency.wrap(token0), Currency.wrap(token1), fee, 60, IHooks(0x0000000000000000000000000000000000000000)
        );

        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        (amountIn);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: _zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                // sqrtPriceLimitX96: uint160(0),
                hookData: bytes("")
            })
        );

        Currency inputTokens = _zeroForOne ? key.currency0 : key.currency1;
        Currency outputTokens = _zeroForOne ? key.currency1 : key.currency0;
        params[1] = abi.encode(inputTokens, amountIn);
        params[2] = abi.encode(outputTokens, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        if (Currency.unwrap(key.currency0) != address(0)) {
            IERC20(Currency.unwrap(key.currency0)).approve(address(permit2), type(uint256).max);
            permit2.approve(Currency.unwrap(key.currency0), address(router), amountIn, type(uint48).max);
        }
        if (Currency.unwrap(key.currency1) != address(0)) {
            IERC20(Currency.unwrap(key.currency1)).approve(address(permit2), type(uint256).max);
            permit2.approve(Currency.unwrap(key.currency1), address(router), amountIn, type(uint48).max);
        }

        router.execute{value: amountIn}(commands, inputs, block.timestamp);

        // Verify and return the output amount
        amountOut = IERC20(Currency.unwrap(key.currency1)).balanceOf(address(this));
        require(amountOut >= minAmountOut, "Insufficient output amount");

        return amountOut;
    }

    // Add these functions to receive ETH
    receive() external payable {}
    fallback() external payable {}
}
