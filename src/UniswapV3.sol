// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IWETH9 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract UniswapV3 is ReentrancyGuard {
    ISwapRouter private constant ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Mapping to store user WETH balances
    mapping(address => uint256) public userWETHBalance;

    // Wrap ETH into WETH
    function wrapETH() external payable nonReentrant {
        require(msg.value > 0, "Must send ETH to wrap");

        // Call the deposit function of WETH9 contract to wrap ETH into WETH
        IWETH9(WETH9).deposit{value: msg.value}();
        userWETHBalance[msg.sender] += msg.value;
    }

    // To-do UnwrapETH() function
    // Unwrap WETH back to ETH
    function unwrapETH(uint256 amount) external nonReentrant {
        require(
            userWETHBalance[msg.sender] >= amount,
            "Insufficient WETH balance"
        );

        // Deduct the user's WETH balance
        userWETHBalance[msg.sender] -= amount;

        uint256 contractWethBalance = IWETH9(WETH9).balanceOf(address(this));
        require(
            contractWethBalance >= amount,
            "Contract WETH balance insufficient"
        );

        // Withdraw the specified amount of WETH, converting it back to ETH sent to this contract
        IWETH9(WETH9).withdraw(amount);

        // Transfer the unwrapped ETH to the user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // tokenIn: WETH9
    // tokenOut: USDT
    function swapExactInputSingleHop(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn
    ) external nonReentrant returns (uint256 amountOut) {
        require(
            tokenIn == WETH9,
            "TokenIn must be WETH9 to use stored balance"
        );
        require(
            userWETHBalance[msg.sender] >= amountIn,
            "Insufficient WETH balance"
        );

        // Deduct the user's WETH balance first
        userWETHBalance[msg.sender] -= amountIn;

        // IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        // TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        // IERC20(tokenIn).approve(address(ROUTER), amountIn);
        TransferHelper.safeApprove(tokenIn, address(ROUTER), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        amountOut = ROUTER.exactInputSingle(params);
    }

    // accept payment during UnWrapETH
    receive() external payable {}
}
