// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract VaultToken is ERC20, Ownable {
    struct TokenData {
        address tokenAddress;
        AggregatorV3Interface priceFeed;
        uint256 weight;
    }

    TokenData[] public tokens;
    uint256 private constant PRECISION = 1e8;
    address public usdtAddress = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0; // sepolia

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
            tokens.push(TokenData({
                tokenAddress: tokenAddresses[i],
                priceFeed: AggregatorV3Interface(priceFeeds[i]),
                weight: weights[i]
            }));
            totalWeight += weights[i];
        }

        require(totalWeight == 100, "Total weights must sum to 100");
    }

    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
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

    function mint(address to, uint256 amount) external onlyOwner {
        require(calculateVaultTokenValue() >= amount, "Insufficient collateral");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function deposit(uint256 amount) external {
        uint256 vaultTokenValue = calculateVaultTokenValue();
        require(vaultTokenValue > 0, "Vault value must be greater than zero");

        require(ERC20(usdtAddress).transferFrom(msg.sender, address(this), amount), "USDC transfer failed");
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
        require(ERC20(usdtAddress).transfer(msg.sender, usdcToTransfer), "USDC transfer failed");
    }

}
