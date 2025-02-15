// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// import {console} from "forge-std/console.sol";
import {UniswapV3} from "./UniswapV3.sol";

interface IBlocksense {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract VaultToken is ERC20, Ownable {
    struct TokenWeights {
        address tokenAddress;
        IBlocksense priceFeed;
        uint256 weight;
    }

    TokenWeights[] public tokens;
    IBlocksense public ethPriceFeed =
        IBlocksense(address(0x7c9906cb5a589c6fa3DaB8E56267D3Ab687cA52f));

    mapping(address => uint256) public tokenBalances; // Tracks balance of each token in 1e18 scale
    UniswapV3 uniswapV3 = new UniswapV3();
    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH
    // address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
    address usdc = address(0xb669dC8cC6D044307Ba45366C0c836eC3c7e31AA); // USDC on Citrea
    uint private numberOfInvestors = 0;

    constructor(
        string memory name,
        address[] memory tokenAddresses,
        address[] memory blocksensePriceAggregators,
        uint256[] memory weights
    ) ERC20(name, name) Ownable(msg.sender) {
        require(
            tokenAddresses.length == blocksensePriceAggregators.length &&
                blocksensePriceAggregators.length == weights.length,
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
                    priceFeed: IBlocksense(
                        address(blocksensePriceAggregators[i])
                    ),
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
    ) public view returns (address, uint256) {
        require(index < tokens.length, "Index out of bounds");
        TokenWeights memory tokenData = tokens[index];
        return (tokenData.tokenAddress, tokenData.weight);
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

    function convertInputToTokenDecimals(
        uint256 amount,
        address token
    ) public view returns (uint256) {
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        if (tokenDecimals < 18) {
            return amount / (10 ** (18 - tokenDecimals));
        } else if (tokenDecimals > 18) {
            return amount * (10 ** (tokenDecimals - 18));
        }
        return amount;
    }

    function getLatestPrice(
        IBlocksense priceFeed
    ) public view returns (int256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
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

    function calculateMarketCap() public view returns (uint256) {
        // uint256 totalValue = 0;
        uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        // for (uint256 i = 0; i < tokens.length; i++) {
        //     address tokenAddr = tokens[i].tokenAddress;
        //     uint256 balance = tokenBalances[tokenAddr];
        //     if (balance > 0) {
        //         int256 price = getLatestPrice(tokens[i].priceFeed);
        //         uint256 value = (balance * uint256(price)) / 1e18;
        //         totalValue += value;
        //     }
        // }
        // return totalValue;
        uint8 tokenOutDecimals = IERC20Metadata(usdc).decimals();
        uint256 usdcBalanceInCorrectDecimals = convertInputTo18Decimals(
            usdcBalance,
            tokenOutDecimals
        );

        return usdcBalanceInCorrectDecimals;
    }

    function getNumberOfInvestors() public view returns (uint256) {
        return numberOfInvestors;
    }

    function getNAV() public view returns (uint256) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) {
            return 0;
        }
        uint256 marketCap = calculateMarketCap();
        return (marketCap) / totalSupply;
    }

    function updateAssetsAndWeights(
        address[] memory tokenAddresses,
        address[] memory blocksensePriceAggregators,
        uint256[] memory weights
    ) external onlyOwner {
        require(
            tokenAddresses.length == blocksensePriceAggregators.length &&
                blocksensePriceAggregators.length == weights.length,
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
                    priceFeed: IBlocksense(
                        address(blocksensePriceAggregators[i])
                    ),
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

    function deposit(uint256 amount) external {
        // Amount in USDC
        require(amount > 0, "Invalid amount");
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);
        uint8 tokenOutDecimals = IERC20Metadata(usdc).decimals();
        amount = convertInputTo18Decimals(amount, tokenOutDecimals);

        // Calculate the total vault value before minting
        uint256 vaultValueBefore = calculateMarketCap();

        // address tokenIn = weth;
        // uint256 totalMintedValue = 0;

        // Wrap ETH to WETH
        // uniswapV3.wrapETH{value: amount}();

        // // Distribute the total amount according to weights in tokens array
        // for (uint256 i = 0; i < tokens.length; i++) {
        //     address tokenOut = tokens[i].tokenAddress;
        //     uint256 allocationWeight = tokens[i].weight;
        //     int256 tokenPrice = getLatestPrice(tokens[i].priceFeed);
        //     require(tokenPrice > 0, "Token price must be greater than zero");

        //     uint256 amountIn = (amount * allocationWeight) / 100;
        //     uint256 amountOut = amountIn;

        //     // Perform the swap using UniswapV3
        //     if (tokenIn != tokenOut) {
        //         amountOut = uniswapV3.swapExactInputSingleHop(
        //             tokenIn,
        //             tokenOut,
        //             3000, // TODO: Later try lesser pool of 500
        //             amountIn
        //         );
        //         // get decimals of tokenOut
        //         uint8 tokenOutDecimals = IERC20Metadata(tokenOut).decimals();
        //         amountOut = convertInputTo18Decimals(
        //             amountOut,
        //             tokenOutDecimals
        //         );
        //     }

        //     // Update the vault's token balance
        //     tokenBalances[tokenOut] += amountOut;

        //     uint256 tokenValueInUsd = (amountOut * uint256(tokenPrice)) / 1e18;
        //     totalMintedValue += tokenValueInUsd;
        // }

        uint256 totalMintedValue = amount;

        // Determine shares to mint
        uint256 sharesToMint;
        if (totalSupply() == 0 || vaultValueBefore == 0) {
            sharesToMint = totalMintedValue;
        } else {
            // sharesToMint =
            //     (totalMintedValue * totalSupply()) /
            //     vaultValueBefore;
            sharesToMint = totalMintedValue;
        }

        require(sharesToMint > 0, "Shares to mint must be greater than zero");

        if (balanceOf(msg.sender) == 0) {
            numberOfInvestors += 1;
        }
        // Mint vault tokens to the user
        _mint(msg.sender, sharesToMint);
    }

    function withdraw(uint256 amount) external {
        // require(ethAmount > 0, "Invalid amount");

        // Step 1: Calculate the vault's total USD value
        uint256 marketCap = calculateMarketCap();
        require(marketCap > 0, "Vault is empty");

        // Step 2: Convert ethAmount to USD using Chainlink feed
        // int256 ethPrice = getLatestPrice(ethPriceFeed); // 1e18
        // uint256 usdToWithdraw = (ethAmount * uint256(ethPrice)) / 1e18;
        uint256 tokensAlreadyIssued = totalSupply();

        uint8 tokenOutDecimals = IERC20Metadata(usdc).decimals();
        uint256 usdToWithdraw = convertInputTo18Decimals(
            amount,
            tokenOutDecimals
        );

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
        // uint256 totalWETHReceived = 0;

        // Iterate over each token in the vault and redeem the user's share of each token (total supply changed after burn above, so use older tokensAlreadyIssued)
        // for (uint256 i = 0; i < tokens.length; i++) {
        //     address tokenIn = tokens[i].tokenAddress;
        //     uint256 allocationWeight = tokens[i].weight;

        //     int256 tokenPrice = getLatestPrice(tokens[i].priceFeed);
        //     uint256 userTokenShare = (usdToWithdraw * allocationWeight * 1e18) /
        //         (uint256(tokenPrice) * 100);

        //     require(
        //         tokenBalances[tokenIn] >= userTokenShare,
        //         "Vault has insufficient token balance"
        //     );

        //     // Convert the token to WETH
        //     uint256 wethReceived = userTokenShare;
        //     if (tokenIn != weth) {
        //         // Approve UniswapV3 to spend tokenIn
        //         IERC20(tokenIn).approve(address(uniswapV3), userTokenShare);

        //         uint256 balanceOfTokenIn = getErc20Balance(tokenIn);
        //         uint256 allowanceOfTokenIn = getErc20Allowance(tokenIn);

        //         require(
        //             balanceOfTokenIn >= userTokenShare,
        //             "Insufficient token balance"
        //         );
        //         require(
        //             allowanceOfTokenIn >= userTokenShare,
        //             "Insufficient token allowance"
        //         );

        //         // Perform the swap to WETH using UniswapV3
        //         wethReceived = uniswapV3.swapExactInputSingleHop(
        //             tokenIn,
        //             weth,
        //             3000, // Pool fee
        //             userTokenShare
        //         );
        //     }
        //     // Update the vault's token balance
        //     tokenBalances[tokenIn] -= userTokenShare;

        //     totalWETHReceived += wethReceived;
        // }

        // Unwrap WETH to ETH
        // uniswapV3.unwrapETH(totalWETHReceived);

        // Transfer the ETH to the user
        // (bool success, ) = msg.sender.call{value: totalWETHReceived}("");
        uint256 usdInTheirDecimalToWithdraw = convertInputToTokenDecimals(
            usdToWithdraw,
            usdc
        );
        bool success = IERC20(usdc).transfer(
            msg.sender,
            usdInTheirDecimalToWithdraw
        );
        require(success, "USDC transfer failed");
    }

    // Fallback function to accept ETH
    receive() external payable {}

    // Fallback function to accept ETH (with data)
    fallback() external payable {}
}
