// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// import {console} from "forge-std/console.sol";
import {UniswapV3} from "./UniswapV3.sol";
import {ChainlinkProxy} from "../lib/ChainLinkProxy.sol";

contract VaultToken is ERC20, Ownable {
    struct TokenWeights {
        address tokenAddress;
        uint32 priceFeedId;
        uint256 weight;
    }

    TokenWeights[] public tokens;
    mapping(address => uint256) public tokenBalances; // Tracks balance of each token in 1e18 scale
    UniswapV3 uniswapV3 = new UniswapV3();
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH
    uint32 ethPriceId = 47; // Chainlink ETH/USD feed
    uint private numberOfInvestors = 0;

    constructor(
        string memory name,
        address[] memory tokenAddresses,
        uint32[] memory priceFeedIds,
        uint256[] memory weights
    ) ERC20(name, name) Ownable(msg.sender) {
        require(
            tokenAddresses.length == priceFeedIds.length &&
                priceFeedIds.length == weights.length,
            "Arrays must be of equal length"
        );

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            require(weights[i] > 0, "Weight must be positive");
            totalWeight += weights[i];
        }
        require(totalWeight == 100, "Total weights must sum to 100");

        for (uint256 i = 0; i < weights.length; i++) {
            tokens.push(
                TokenWeights({
                    tokenAddress: tokenAddresses[i],
                    priceFeedId: priceFeedIds[i],
                    weight: weights[i]
                })
            );
        }
    }

    function getTokenDistributionCount() public view returns (uint256) {
        return tokens.length;
    }

    function getTokenDistributionData(
        uint256 index
    ) public view returns (address, uint256, uint256) {
        require(index < tokens.length, "Index out of bounds");
        TokenWeights memory tokenData = tokens[index];
        return (
            tokenData.tokenAddress,
            tokenData.priceFeedId,
            tokenData.weight
        );
    }

    function convertInputTo18Decimals(
        uint256 amount,
        uint8 decimals
    ) public pure returns (uint256) {
        if (decimals < 18) {
            return amount * 10 ** (18 - decimals);
        } else if (decimals > 18) {
            return amount / 10 ** (decimals - 18);
        }
        return amount;
    }

    function getLatestPrice(uint32 priceFeedId) public returns (int256) {
        (, int256 price, , , ) = new ChainlinkProxy(18, priceFeedId)
            .latestRoundData();
        require(price > 0, "Invalid price");
        return price;
    }

    function getErc20Balance(
        address tokenAddress
    ) public view returns (uint256) {
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        uint8 decimals = IERC20Metadata(tokenAddress).decimals();
        return convertInputTo18Decimals(balance, decimals);
    }

    function getErc20Allowance(
        address tokenAddress
    ) public view returns (uint256) {
        uint256 allowance = IERC20(tokenAddress).allowance(
            address(this),
            address(uniswapV3)
        );
        uint8 decimals = IERC20Metadata(tokenAddress).decimals();
        return convertInputTo18Decimals(allowance, decimals);
    }

    function calculateMarketCap() public returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddr = tokens[i].tokenAddress;
            uint256 balance = tokenBalances[tokenAddr];
            if (balance > 0) {
                int256 price = getLatestPrice(tokens[i].priceFeedId);
                uint256 value = (balance * uint256(price)) / 1e18;
                totalValue += value;
            }
        }
        return totalValue;
    }

    function getNumberOfInvestors() public view returns (uint256) {
        return numberOfInvestors;
    }

    function getNAV() public returns (uint256) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) {
            return 0;
        }
        uint256 marketCap = calculateMarketCap();
        return (marketCap) / totalSupply;
    }

    function updateAssetsAndWeights(
        address[] memory tokenAddresses,
        uint32[] memory priceFeedIds,
        uint256[] memory weights
    ) external onlyOwner {
        require(
            tokenAddresses.length == priceFeedIds.length &&
                priceFeedIds.length == weights.length,
            "Arrays must be of equal length"
        );

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            require(weights[i] > 0, "Weight must be positive");
            totalWeight += weights[i];
        }

        require(totalWeight == 100, "Total weights must sum to 100");

        // Swap existing tokens to WETH
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddr = tokens[i].tokenAddress;
            uint256 balance = tokenBalances[tokenAddr];

            if (tokenAddr != weth && balance > 0) {
                // Approve UniswapV3 to spend tokenAddr
                IERC20(tokenAddr).approve(address(uniswapV3), balance);

                // Swap token for WETH
                uniswapV3.swapExactInputSingleHop(
                    tokenAddr,
                    weth,
                    3000, // Pool fee
                    balance
                );

                // Reset token balance after swap
                tokenBalances[tokenAddr] = 0;
            }
        }

        // Clear the current tokens array
        delete tokens;

        // Add the new tokens and their weights
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            tokens.push(
                TokenWeights({
                    tokenAddress: tokenAddresses[i],
                    priceFeedId: priceFeedIds[i],
                    weight: weights[i]
                })
            );
        }

        // Swap WETH to new tokens based on their weights
        uint256 totalWETHBalance = tokenBalances[weth]; // Get the total WETH balance
        require(totalWETHBalance > 0, "No WETH available for swapping");

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenOut = tokenAddresses[i];
            uint256 allocationWeight = weights[i];
            uint256 amountToSwap = (totalWETHBalance * allocationWeight) / 100;

            // Approve UniswapV3 to spend WETH
            IERC20(weth).approve(address(uniswapV3), amountToSwap);

            // Perform the swap from WETH to the new token
            if (tokenOut != weth && amountToSwap > 0) {
                uint256 amountReceived = uniswapV3.swapExactInputSingleHop(
                    weth,
                    tokenOut,
                    3000, // Pool fee
                    amountToSwap
                );
                uint8 tokenOutDecimals = IERC20Metadata(tokenOut).decimals();
                amountReceived = convertInputTo18Decimals(
                    amountReceived,
                    tokenOutDecimals
                );

                // Update the vault's token balance
                tokenBalances[tokenOut] += amountReceived;
            }
        }
    }

    function deposit() external payable {
        uint256 amount = msg.value;
        require(amount > 0, "Invalid amount");

        // Calculate the total vault value before minting
        uint256 vaultValueBefore = calculateMarketCap();

        address tokenIn = weth;
        uint256 totalMintedValue = 0;

        // Wrap ETH to WETH
        uniswapV3.wrapETH{value: amount}();

        // Distribute the total amount according to weights in tokens array
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenOut = tokens[i].tokenAddress;
            uint256 allocationWeight = tokens[i].weight;
            int256 tokenPrice = getLatestPrice(tokens[i].priceFeedId);
            require(tokenPrice > 0, "Token price must be greater than zero");

            uint256 amountIn = (amount * allocationWeight) / 100;
            uint256 amountOut = amountIn;

            // Perform the swap using UniswapV3
            if (tokenIn != tokenOut) {
                amountOut = uniswapV3.swapExactInputSingleHop(
                    tokenIn,
                    tokenOut,
                    3000, // TODO: Later try lesser pool of 500
                    amountIn
                );
                // get decimals of tokenOut
                uint8 tokenOutDecimals = IERC20Metadata(tokenOut).decimals();
                amountOut = convertInputTo18Decimals(
                    amountOut,
                    tokenOutDecimals
                );
            }

            // Update the vault's token balance
            tokenBalances[tokenOut] += amountOut;

            uint256 tokenValueInUsd = (amountOut * uint256(tokenPrice)) / 1e18;
            totalMintedValue += tokenValueInUsd;
        }

        // Determine shares to mint
        uint256 sharesToMint;
        if (totalSupply() == 0 || vaultValueBefore == 0) {
            sharesToMint = totalMintedValue;
        } else {
            sharesToMint =
                (totalMintedValue * totalSupply()) /
                vaultValueBefore;
        }

        require(sharesToMint > 0, "Shares to mint must be greater than zero");

        if (balanceOf(msg.sender) == 0) {
            numberOfInvestors += 1;
        }
        // Mint vault tokens to the user
        _mint(msg.sender, sharesToMint);
    }

    function withdraw(uint256 ethAmount) external {
        require(ethAmount > 0, "Invalid amount");

        // Step 1: Calculate the vault's total USD value
        uint256 marketCap = calculateMarketCap();
        require(marketCap > 0, "Vault is empty");

        // Step 2: Convert ethAmount to USD using Chainlink feed
        int256 ethPrice = getLatestPrice(ethPriceId); // 1e18
        uint256 usdToWithdraw = (ethAmount * uint256(ethPrice)) / 1e18;
        uint256 tokensAlreadyIssued = totalSupply();

        // Step 3: Calculate shares to burn
        uint256 sharesToBurn = (usdToWithdraw * tokensAlreadyIssued) /
            marketCap;
        require(sharesToBurn > 0, "Shares to burn must be greater than zero");

        // The user must have enough shares
        require(sharesToBurn <= balanceOf(msg.sender), "Insufficient shares");

        // Burn the vault tokens from the user
        _burn(msg.sender, sharesToBurn);
        if (balanceOf(msg.sender) == 0) {
            numberOfInvestors -= 1;
        }
        // Track WETH received
        uint256 totalWETHReceived = 0;

        // Iterate over each token in the vault and redeem the user's share of each token (total supply changed after burn above, so use older tokensAlreadyIssued)
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenIn = tokens[i].tokenAddress;
            uint256 allocationWeight = tokens[i].weight;

            int256 tokenPrice = getLatestPrice(tokens[i].priceFeedId);
            uint256 userTokenShare = (usdToWithdraw * allocationWeight * 1e18) /
                (uint256(tokenPrice) * 100);

            require(
                tokenBalances[tokenIn] >= userTokenShare,
                "Vault has insufficient token balance"
            );

            // Convert the token to WETH
            uint256 wethReceived = userTokenShare;
            if (tokenIn != weth) {
                // Approve UniswapV3 to spend tokenIn
                IERC20(tokenIn).approve(address(uniswapV3), userTokenShare);

                uint256 balanceOfTokenIn = getErc20Balance(tokenIn);
                uint256 allowanceOfTokenIn = getErc20Allowance(tokenIn);

                require(
                    balanceOfTokenIn >= userTokenShare,
                    "Insufficient token balance"
                );
                require(
                    allowanceOfTokenIn >= userTokenShare,
                    "Insufficient token allowance"
                );

                // Perform the swap to WETH using UniswapV3
                wethReceived = uniswapV3.swapExactInputSingleHop(
                    tokenIn,
                    weth,
                    3000, // Pool fee
                    userTokenShare
                );
            }
            // Update the vault's token balance
            tokenBalances[tokenIn] -= userTokenShare;

            totalWETHReceived += wethReceived;
        }

        // Unwrap WETH to ETH
        uniswapV3.unwrapETH(totalWETHReceived);

        // Transfer the ETH to the user
        (bool success, ) = msg.sender.call{value: totalWETHReceived}("");
        require(success, "ETH transfer failed");
    }

    // Fallback function to accept ETH
    receive() external payable {}

    // Fallback function to accept ETH (with data)
    fallback() external payable {}
}
