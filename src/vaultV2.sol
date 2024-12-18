// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV3 {
    function swapExactInputSingleHop(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    function wrapETH() external payable;
}

contract Vault is ERC20, Ownable {
    address public manager;
    address public uniswapContract;

    uint256 public constant PERCENTAGE_BASE = 10000;

    // token address => percentage
    mapping(address => uint256) public allocations;
    // List of tokens
    address[] public tokens;
    // token address => vault balance
    mapping(address => uint256) public tokenBalances;

    event AllocationsUpdated(address[] tokens, uint256[] percentages);
    event TokensSwapped(address tokenOut, uint256 amountReceived);

    constructor(
        address _uniswapContract
    ) ERC20("Exponential Markets", "EXP") Ownable(msg.sender) {
        manager = msg.sender;
        uniswapContract = _uniswapContract;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager can call this function");
        _;
    }

    function setAllocations(
        address[] calldata _tokens,
        uint256[] calldata _percentages
    ) external onlyManager {
        require(
            _tokens.length == _percentages.length,
            "Inputs length mismatch"
        );

        uint256 totalPercentage;
        delete tokens;

        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_percentages[i] > 0, "Invalid percentage");

            tokens.push(_tokens[i]);
            allocations[_tokens[i]] = _percentages[i];
            totalPercentage += _percentages[i];
        }

        require(
            totalPercentage == PERCENTAGE_BASE,
            "Percentages must sum to 100%"
        );
        emit AllocationsUpdated(_tokens, _percentages);
    }

    function buyTokens(
        address tokenIn,
        uint24 poolFee,
        uint256 totalAmount
    ) external payable onlyManager {
        require(totalAmount > 0, "Invalid amount");
        require(
            msg.value == totalAmount,
            "ETH sent does not match totalAmount"
        );

        // To-do: create a separate contract for wrap and unwrap WETH
        IUniswapV3(uniswapContract).wrapETH{value: totalAmount}();

        uint256 totalFundTokenValue;

        // Distribute the totalAmount according to allocations
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenOut = tokens[i];
            uint256 allocationPercentage = allocations[tokenOut];
            uint256 amountIn = (totalAmount * allocationPercentage) /
                PERCENTAGE_BASE;

            // Call UniswapV3 to perform swap
            uint256 amountOut = IUniswapV3(uniswapContract)
                .swapExactInputSingleHop(tokenIn, tokenOut, poolFee, amountIn);

            // Update token balance in vault
            tokenBalances[tokenOut] += amountOut;
            totalFundTokenValue += _getTokenValue(tokenOut, amountOut);

            emit TokensSwapped(tokenOut, amountOut);
        }
        // Issue fund tokens proportional to the deposited value
        _mint(msg.sender, totalFundTokenValue);
    }

    function _getTokenValue(
        address token,
        uint256 amount
    ) internal pure returns (uint256) {
        // replace with real logic later, currently putting 1:1 for all tokens
        return amount;
    }
}
