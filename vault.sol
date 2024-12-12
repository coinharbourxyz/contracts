// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract VaultToken is ERC20, Ownable {
    AggregatorV3Interface private wbtcPriceFeed;
    AggregatorV3Interface private ethPriceFeed;

    uint256 public wbtcWeight = 50; // 50% weight
    uint256 public ethWeight = 50;  // 50% weight

    address public wbtc;
    address public eth;

    uint256 private constant PRECISION = 1e8;

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {
        wbtcPriceFeed = AggregatorV3Interface(0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43); // sepolia
        ethPriceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306); // sepolia
        wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        eth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    }


    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }

    function calculateVaultTokenValue() public view returns (uint256) {
        uint256 wbtcPrice = getLatestPrice(wbtcPriceFeed);
        uint256 ethPrice = getLatestPrice(ethPriceFeed);

        uint256 wbtcValue = (wbtcPrice * wbtcWeight) / (100 * PRECISION);
        uint256 ethValue = (ethPrice * ethWeight) / (100 * PRECISION);

        return wbtcValue + ethValue;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        uint256 vaultValue = calculateVaultTokenValue();
        require(vaultValue >= amount, "Insufficient collateral");

        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function updateWeights(uint256 newWbtcWeight, uint256 newEthWeight) external onlyOwner {
        require(newWbtcWeight + newEthWeight == 100, "Weights must sum to 100");
        wbtcWeight = newWbtcWeight;
        ethWeight = newEthWeight;
    }

    function deposit(address token, uint256 amount) external {
        require(token == wbtc || token == eth, "Unsupported token");
        ERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        require(token == wbtc || token == eth, "Unsupported token");
        ERC20(token).transfer(msg.sender, amount);
    }
}
