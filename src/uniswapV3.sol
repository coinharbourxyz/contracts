// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
}

contract UniswapV3 {
    ISwapRouter private constant ROUTER = ISwapRouter(0x65669fE35312947050C450Bd5d36e6361F85eC12);
    // address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant DAI = 0x68194a729C2450ad26072b3D33ADaCbcef39D574;
    address public constant WETH9 = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    // address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Mapping to store user WETH balances
    mapping(address => uint256) public userWETHBalance;

    // Wrap ETH into WETH
    function wrapETH() external payable {
        require(msg.value > 0, "Must send ETH to wrap");

        // Call the deposit function of WETH9 contract to wrap ETH into WETH
        IWETH9(WETH9).deposit{value: msg.value}();
        userWETHBalance[msg.sender] += msg.value;
    }

    // To-do UnwrapETH() function

    // tokenIn: WETH9
    // tokenOut: DAI
    function swapExactInputSingleHop(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn
    )
        external
        returns (uint256 amountOut)
    {
        require(tokenIn == WETH9, "TokenIn must be WETH9 to use stored balance");
        require(userWETHBalance[msg.sender] >= amountIn, "Insufficient WETH balance");

        // Deduct the user's WETH balance first
        userWETHBalance[msg.sender] -= amountIn;

        // IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        // TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        // IERC20(tokenIn).approve(address(ROUTER), amountIn);
        TransferHelper.safeApprove(tokenIn, address(ROUTER), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
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
}
