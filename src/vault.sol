// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IUniswapV3 {
    function swapExactInputSingleHop(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    function wrapETH() external payable;

    function unwrapETH(uint256 amount) external;
}

contract VaultToken is ERC20, Ownable {
    struct TokenData {
        address tokenAddress;
        AggregatorV3Interface priceFeed;
        uint256 weight;
    }

    address public uniswapContract;
    TokenData[] public tokens;
    uint256 private constant PRECISION = 1e8;
    address public usdtAddress = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0; // sepolia
    // mapping(address => uint256) public allocations;
    mapping(address => uint256) public tokenBalances;

    event AllocationsUpdated(address[] tokens, uint256[] weights);
    event TokensSwapped(address tokenOut, uint256 amountReceived);

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner,
        address[] memory tokenAddresses,
        address[] memory priceFeeds,
        uint256[] memory weights,
        address _uniswapContract
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
        uniswapContract = _uniswapContract;
    }

    function getLatestPrice(
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }

    function calculateVaultTokenValue() public view returns (uint256) {
        uint256 totalValue = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 price = getLatestPrice(tokens[i].priceFeed);
            // uint256 balance = ERC20(tokens[i].tokenAddress).balanceOf(address(this));
            uint256 value = (price * tokens[i].weight) / (100 * PRECISION);
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

    function mint(address to, uint256 amount) external onlyOwner {
        require(
            calculateVaultTokenValue() >= amount,
            "Insufficient collateral"
        );
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function buyTokens(
        address tokenIn,
        uint24 poolFee,
        uint256 totalAmount
    ) external payable {
        require(totalAmount > 0, "Invalid amount");
        require(
            msg.value == totalAmount,
            "ETH sent does not match totalAmount"
        );

        // Wrap ETH into WETH
        IUniswapV3(uniswapContract).wrapETH{value: totalAmount}();

        uint256 totalMintedValue = 0;

        // Distribute the totalAmount according to weights in tokens array
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenOut = tokens[i].tokenAddress;
            uint256 allocationWeight = tokens[i].weight;
            uint256 amountIn = (totalAmount * allocationWeight) / 100;

            // Handle precision for token swaps
            uint256 preciseAmountIn = (amountIn * PRECISION) / 100;

            // Perform the swap using UniswapV3
            uint256 amountOut = IUniswapV3(uniswapContract)
                .swapExactInputSingleHop(
                    tokenIn,
                    tokenOut,
                    poolFee,
                    preciseAmountIn
                );

            // Update token balance in the vault
            tokenBalances[tokenOut] += amountOut;

            // Accumulate the minted value based on the price of the token
            uint256 tokenPrice = getLatestPrice(tokens[i].priceFeed);
            totalMintedValue += (amountOut * tokenPrice) / PRECISION;

            emit TokensSwapped(tokenOut, amountOut);
        }

        // Issue fund tokens proportional to the deposited value
        _mint(msg.sender, totalMintedValue / calculateVaultTokenValue());
    }

    function deposit(address tokenIn, uint256 amount) external {
        uint256 vaultTokenValue = calculateVaultTokenValue();
        require(vaultTokenValue > 0, "Vault value must be greater than zero");

        // Transfer tokens from the user to this contract
        require(
            ERC20(tokenIn).transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        // Approve the Uniswap contract to spend the tokens
        ERC20(tokenIn).approve(uniswapContract, amount);

        uint256 tokensToMint = (amount * 1e8) / vaultTokenValue; // 1e8 is used for precision adjustment
        _mint(msg.sender, tokensToMint);
    }

    function withdraw(uint256 amount) external {
        uint256 vaultTokenValue = calculateVaultTokenValue();
        require(vaultTokenValue > 0, "Vault value must be greater than zero");

        // Burn the VaultTokens from the user
        _burn(msg.sender, amount);

        // Transfer the corresponding USDC to the user
        uint256 usdcToTransfer = (amount * vaultTokenValue) / 1e18;
        require(
            ERC20(usdtAddress).transfer(msg.sender, usdcToTransfer),
            "USDC transfer failed"
        );
    }
}
