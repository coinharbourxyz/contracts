// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV3} from "../src/UniswapV3.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

interface IWETH9 {
    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract UniswapV3Test is Test {
    UniswapV3 public uniswapV3;
    address user = address(0x123); // Arbitrary test user
    IWETH9 weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ISwapRouter private constant ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address public constant UNISWAP_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    uint24 public constant FEE = 3000;

    function setUp() public {
        uniswapV3 = new UniswapV3();
        vm.deal(user, 10 ether);
        deal(WETH9, user, 10 ether);
    }

    function testWrapETH() public {
        uint256 initialUserBalance = user.balance;
        // console.log("Initial user balance: ", initialUserBalance);
        uint256 amountToWrap = 1 ether;

        // User calls wrapETH() with 1 ether
        vm.startPrank(user);
        uniswapV3.wrapETH{value: amountToWrap}();
        vm.stopPrank();

        // Check internal balance
        uint256 userWethBalance = uniswapV3.userWETHBalance(user);
        // console.log("User WETH Balance: ", userWethBalance);
        assertEq(
            userWethBalance,
            amountToWrap,
            "User WETH balance should equal wrapped amount"
        );

        // Check user's ETH balance decreases
        uint256 userEthBalanceAfter = user.balance;
        // console.log("Final user balance: ", userEthBalanceAfter);
        assertEq(
            initialUserBalance - amountToWrap,
            userEthBalanceAfter,
            "User ETH balance should decrease by wrapped amount"
        );

        // Check contract holds WETH now (by querying WETH contract)
        uint256 contractWethBalance = weth.balanceOf(address(uniswapV3));
        // console.log("Contract WETH balance (final): ", contractWethBalance);
        assertEq(
            contractWethBalance,
            amountToWrap,
            "Contract WETH balance should equal wrapped amount"
        );
    }

    function testUnwrapETH() public {
        uint256 amountToWrap = 1 ether;

        // First wrap ETH
        vm.startPrank(user);
        uniswapV3.wrapETH{value: amountToWrap}();
        vm.stopPrank();

        // Check pre-state for unwrap
        uint256 initialUserEthBalance = user.balance;
        uint256 initialUserWethBalance = uniswapV3.userWETHBalance(user);

        // Now unwrap half
        uint256 amountToUnwrap = 0.5 ether;
        vm.startPrank(user);
        uniswapV3.unwrapETH(amountToUnwrap);
        vm.stopPrank();

        // Check user's WETH balance after unwrap
        uint256 userWethBalanceAfter = uniswapV3.userWETHBalance(user);
        assertEq(
            userWethBalanceAfter,
            initialUserWethBalance - amountToUnwrap,
            "User WETH balance should have decreased"
        );

        // Check user's ETH balance after unwrap
        // The user should have received 0.5 ETH back
        uint256 userEthBalanceAfter = user.balance;
        assertEq(
            userEthBalanceAfter,
            initialUserEthBalance + amountToUnwrap,
            "User ETH balance should have increased by unwrap amount"
        );

        // Check contract WETH balance decreased
        uint256 contractWethBalanceAfter = weth.balanceOf(address(uniswapV3));
        assertEq(
            contractWethBalanceAfter,
            initialUserWethBalance - amountToUnwrap,
            "Contract WETH balance should have decreased"
        );
    }

    function testUnwrapETHFailsWithInsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert("Insufficient WETH balance");
        uniswapV3.unwrapETH(1 ether);
    }

    function testSwapExactInputSingleHop() public {
        // Wrap ETH first
        vm.prank(user);
        uniswapV3.wrapETH{value: 1 ether}();

        uint256 amountIn = 0.5 ether;

        // Approve router to spend WETH
        weth.approve(address(ROUTER), amountIn);

        vm.prank(user);
        uint256 amountOut = uniswapV3.swapExactInputSingleHop(
            WETH9,
            USDT,
            FEE,
            amountIn
        );

        // Verify balances
        uint256 userBalance = uniswapV3.userWETHBalance(user);
        assertEq(userBalance, 0.5 ether, "WETH balance mismatch after swap");

        console.log("WETH sent: ", amountIn);
        console.log("USDT received: ", amountOut);
        assertTrue(amountOut > 0, "Swap output should be greater than 0");
    }

    function testSwapFailsWithInsufficientWETHBalance() public {
        vm.prank(user);
        vm.expectRevert("Insufficient weth balance");
        uniswapV3.swapExactInputSingleHop(WETH9, DAI, FEE, 1 ether);
    }

    function testReceiveETHDuringUnwrap() public {
        vm.prank(user);
        uniswapV3.wrapETH{value: 1 ether}();

        // Record user's initial ETH balance
        uint256 initialUserBalance = user.balance;

        // Record the contract's initial ETH balance
        uint256 initialContractBalance = address(uniswapV3).balance;

        // Unwrap 0.5 ETH
        vm.prank(user);
        uniswapV3.unwrapETH(0.5 ether);

        // Check user's updated ETH balance
        uint256 expectedUserBalance = initialUserBalance + 0.5 ether;
        assertEq(
            user.balance,
            expectedUserBalance,
            "User ETH balance mismatch after unwrapping"
        );

        // Contract's ETH balance should only increase by gas-related ETH transfers, if any
        uint256 expectedContractBalance = initialContractBalance;
        assertEq(
            address(uniswapV3).balance,
            expectedContractBalance,
            "Unexpected contract ETH balance after unwrapping"
        );
    }
}
