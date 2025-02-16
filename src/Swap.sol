// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import "forge-std/console.sol";

contract Swap {
    UniversalRouter public immutable router;

    constructor(address _universalRouter) {
        router = UniversalRouter(payable(_universalRouter));
    }

    function swap(address token0, address token1, uint24 fee, uint128 amountIn, uint128 minAmountOut, bool zeroForOne)
        external
        payable
        returns (uint256 amountOut)
    {
        PoolKey memory poolKey = PoolKey(Currency.wrap(token0), Currency.wrap(token1), fee, 60, IHooks(address(0)));

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: poolKey,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                hookData: bytes("")
            })
        );

        Currency inputTokens = zeroForOne ? poolKey.currency0 : poolKey.currency1;
        Currency outputTokens = zeroForOne ? poolKey.currency1 : poolKey.currency0;
        params[1] = abi.encode(inputTokens, amountIn);
        params[2] = abi.encode(outputTokens, minAmountOut);

        inputs[0] = abi.encode(actions, params);

        console.log("ETH balance of this ", poolKey.currency0.balanceOf(address(this)));
        console.log("USDC balance of this ", poolKey.currency1.balanceOf(address(this)));

        uint256 valueToPass = zeroForOne ? msg.value : 0;
        router.execute{value: valueToPass}(commands, inputs, block.timestamp);

        amountOut = IERC20(Currency.unwrap(poolKey.currency1)).balanceOf(address(this));
        require(amountOut >= minAmountOut, "Insufficient output amount");

        console.log("ETH balance of this ", poolKey.currency0.balanceOf(address(this)));
        console.log("USDC balance of this ", poolKey.currency1.balanceOf(address(this)));

        // Send the output tokens to the owner
        IERC20(Currency.unwrap(poolKey.currency1)).transfer(msg.sender, amountOut);

        console.log("ETH balance of this ", poolKey.currency0.balanceOf(address(this)));
        console.log("USDC balance of this ", poolKey.currency1.balanceOf(address(this)));

        return amountOut;
    }

    receive() external payable {}
    fallback() external payable {}
}
