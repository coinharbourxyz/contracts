// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";
import {UniswapV3} from "./UniswapV3.sol";

contract VaultToken is ERC20, Ownable {
    struct TokenData {
        address tokenAddress;
        AggregatorV3Interface priceFeed;
        uint256 weight;
    }

    TokenData[] public tokens;
    uint256 private constant PRECISION = 1e18;
    mapping(address => uint256) public tokenBalances;

    event AllocationsUpdated(address[] tokens, uint256[] weights);

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner,
        address[] memory tokenAddresses,
        address[] memory priceFeeds,
        uint256[] memory weights
    ) ERC20(name, symbol) Ownable(initialOwner) {
        require(
            tokenAddresses.length == priceFeeds.length &&
                priceFeeds.length == weights.length,
            "Arrays must be of equal length"
        );

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            require(weights[i] > 0, "Weight must be positive");
            tokens.push(
                TokenData({
                    tokenAddress: tokenAddresses[i],
                    priceFeed: AggregatorV3Interface(priceFeeds[i]),
                    weight: weights[i]
                })
            );
            totalWeight += weights[i];
        }

        require(totalWeight == 100, "Total weights must sum to 100");
    }

    function getTokenDistributionCount() public view returns (uint256) {
        return tokens.length;
    }

    function getTokenDistributionData(
        uint256 index
    ) public view returns (address, address, uint256) {
        require(index < tokens.length, "Index out of bounds");
        TokenData memory tokenData = tokens[index];
        return (
            tokenData.tokenAddress,
            address(tokenData.priceFeed),
            tokenData.weight
        );
    }

    function getLatestPrice(
        AggregatorV3Interface priceFeed
    ) public view returns (uint256) {
        uint8 decimals = priceFeed.decimals();
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");

        if (decimals < 18) {
            return (uint256(price) * 10 ** (18 - decimals));
        } else if (decimals > 18) {
            return (uint256(price) / 10 ** (decimals - 18));
        }
        return (uint256(price));
    }

    function calculateVaultTokenValue() public view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 price = getLatestPrice(tokens[i].priceFeed);
            uint256 value = (price * tokens[i].weight) / 100;
            totalValue += value;
        }

        return totalValue;
    }

    function updateAssetsAndWeights(
        address[] memory tokenAddresses,
        address[] memory priceFeeds,
        uint256[] memory weights
    ) external onlyOwner {
        require(
            tokenAddresses.length == priceFeeds.length &&
                priceFeeds.length == weights.length,
            "Arrays must be of equal length"
        );

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            require(weights[i] > 0, "Weight must be positive");
            totalWeight += weights[i];
        }

        require(totalWeight == 100, "Total weights must sum to 100");

        // Clear the current tokens array
        delete tokens;

        // Add the new tokens and their weights
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            tokens.push(
                TokenData({
                    tokenAddress: tokenAddresses[i],
                    priceFeed: AggregatorV3Interface(priceFeeds[i]),
                    weight: weights[i]
                })
            );
        }
        emit AllocationsUpdated(tokenAddresses, weights);
    }

    function deposit(uint256 amount) external payable {
        require(amount > 0, "Invalid amount");
        require(msg.value == amount, "ETH sent does not match totalAmount");

        UniswapV3 uniswapV3 = new UniswapV3();
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address tokenIn = weth;
        uint256 totalMintedValue = 0;

        // Wrap ETH to WETH
        uniswapV3.wrapETH{value: amount}();

        // Distribute the totalAmount according to weights in tokens array
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenOut = tokens[i].tokenAddress;
            uint256 allocationWeight = tokens[i].weight;
            uint256 tokenPrice = getLatestPrice(tokens[i].priceFeed);
            require(tokenPrice > 0, "Token price must be greater than zero");

            uint256 amountIn = (amount * allocationWeight) / 100;
            uint256 amountOut = amountIn;

            // Perform the swap using UniswapV3
            if (tokenIn != tokenOut) {
                amountOut =
                    uniswapV3.swapExactInputSingleHop(
                        tokenIn,
                        tokenOut,
                        3000, // TODO: Later try lesser pool of 500
                        amountIn
                    ) *
                    1e10;
            }
            tokenBalances[tokenOut] += amountOut;
            totalMintedValue += ((amountOut * tokenPrice) / 1e18);
        }

        // Issue fund tokens proportional to the deposited value
        uint256 vaultTokenValue = calculateVaultTokenValue();
        require(vaultTokenValue > 0, "Vault value must be greater than zero");
        _mint(msg.sender, (totalMintedValue * 1e18) / vaultTokenValue);
    }

    function withdraw(uint256 amount) external {
        // Amount is in ether
        require(amount > 0, "Invalid amount");

        // Calculate the current vault token value
        uint256 vaultTokenValue = calculateVaultTokenValue();
        require(vaultTokenValue > 0, "Vault value must be greater than zero");

        address ethUsdFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

        uint256 ethInUsd = getLatestPrice(AggregatorV3Interface(ethUsdFeed));

        uint256 usdToWithdraw = (amount * ethInUsd) / 1e18;
        // console.log("usdToWithdraw", usdToWithdraw);

        // Calculate tokens to burn
        uint256 tokensToBurn = (usdToWithdraw * 1e18) / vaultTokenValue; // Adjust for precision

        // uint256 vaultTokenBalance = balanceOf(msg.sender);
        // console.log("vaultTokenBalance", vaultTokenBalance);

        // Burn the vault tokens from the user
        _burn(msg.sender, tokensToBurn);
        console.log("burn success");

        UniswapV3 uniswapV3 = new UniswapV3();
        address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address tokenOut = weth;

        uint256 totalETHReceived = 0;

        // Swap each token proportionally back to ETH
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenIn = tokens[i].tokenAddress;
            uint256 allocationWeight = tokens[i].weight; // Token allocation weight

            uint256 tokenAmountToWithdraw =
                (usdToWithdraw * allocationWeight) / 100;

            uint256 ethToWithdraw = (tokenAmountToWithdraw * 1e18) / ethInUsd;

            console.log("asset address", tokenIn);
            console.log("tokenAmountToWithdraw", tokenAmountToWithdraw);
            console.log("ethToWithdraw", ethToWithdraw);
            console.log("tokenBalances[tokenIn]", tokenBalances[tokenIn]);
            // Ensure the vault has enough balance for the withdrawal
            require(
                tokenBalances[tokenIn] >= ethToWithdraw,
                "Insufficient token balance in vault"
            );

            // Update the vault's token balance
            tokenBalances[tokenIn] -= tokenAmountToWithdraw;
            uint256 ethReceived = ethToWithdraw;

            if (tokenIn != tokenOut) {
                // Perform the swap to ETH using UniswapV3
                ethReceived = uniswapV3.swapExactInputSingleHop(
                    tokenIn,
                    tokenOut,
                    3000, // Pool fee
                    ethToWithdraw
                );
            }
            console.log("ethReceived", ethReceived);

            // Accumulate the ETH received
            totalETHReceived += ethReceived;
        }

        // Unwrap WETH to ETH
        // uniswapV3.unwrapETH(totalETHReceived);

        // Transfer the total ETH received to the user
        (bool success, ) = msg.sender.call{value: totalETHReceived}("");
        require(success, "ETH transfer failed");
    }
}
