// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/vault.sol";
import "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/UniswapV3.sol";

contract VaultTokenTest is Test {
    VaultToken vault;
    address owner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address user = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    // uint256 ownerPrivateKey = vm.envOr("OWNER_PRIVATE_KEY", 0x123);
    // uint256 userPrivateKey = vm.envOr("USER_PRIVATE_KEY", 0x456);

    // Mainnet addresses for price feeds
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant BTC_USD_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

    address constant UNISWAP_V3_ROUTER =
        address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    
    UniswapV3 uniswapV3 = new UniswapV3();


    // Events from VaultToken contract
    event TokensSwapped(address tokenOut, uint256 amountReceived);
    event AllocationsUpdated(address[] tokens, uint256[] weights);

    function setUp() public {
        // Mock data for tokens
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH
        tokenAddresses[1] = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599); // WBTC

        address[] memory priceFeeds = new address[](2);
        priceFeeds[0] = ETH_USD_FEED;
        priceFeeds[1] = BTC_USD_FEED;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 50;
        weights[1] = 50;

        vault = new VaultToken(
            "Vault Token",
            "VT",
            owner,
            tokenAddresses,
            priceFeeds,
            weights
        );
    }

    function testSetUp() public {
        assertEq(
            vault.name(),
            "Vault Token",
            "Vault token name should be correct"
        );
        assertEq(vault.symbol(), "VT", "Vault token symbol should be correct");
        assertEq(vault.owner(), owner, "Vault owner should be correct");
        assertEq(vault.getTokenDistributionCount(), 2, "Vault should have 2 tokens");
        assertEq(
            vault.tokenBalances(
                address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
            ),
            0,
            "Vault should have 0 WETH balance"
        );
        assertEq(
            vault.tokenBalances(
                address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599)
            ),
            0,
            "Vault should have 0 WBTC balance"
        );
        assertEq(
            vault.balanceOf(user),
            0,
            "User should have 0 vault token balance"
        );
        assertEq(vault.totalSupply(), 0, "Vault should have 0 total supply");

        // Test that the allocations are set correctly
        (address tokenAddress0, address priceFeed0, uint256 weight0) = vault
            .getTokenDistributionData(0);
        (address tokenAddress1, address priceFeed1, uint256 weight1) = vault
            .getTokenDistributionData(1);
        assertEq(weight0, 50, "ETH should have 50% allocation");
        assertEq(weight1, 50, "BTC should have 50% allocation");

        assertEq(
            tokenAddress0,
            address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2),
            "ETH should have 50% allocation"
        );
        assertEq(
            tokenAddress1,
            address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599),
            "BTC should have 50% allocation"
        );

        assertEq(
            priceFeed0,
            address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419),
            "ETH should have 50% allocation"
        );
        assertEq(
            priceFeed1,
            address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c),
            "BTC should have 50% allocation"
        );
    }

    // function testGetTokenValue() public {
    //     // Get prices from Chainlink feeds
    //     uint256 ethPrice = vault.getLatestPrice(
    //         AggregatorV3Interface(ETH_USD_FEED)
    //     );
    //     emit log_named_uint("ETH/USD Price", ethPrice);

    //     uint256 btcPrice = vault.getLatestPrice(
    //         AggregatorV3Interface(BTC_USD_FEED)
    //     );
    //     emit log_named_uint("BTC/USD Price", btcPrice);

    //     // Get token weights from the contract
    //     (, , uint256 ethWeight) = vault.getTokenDistributionData(0);
    //     (, , uint256 btcWeight) = vault.getTokenDistributionData(1);

    //     // Calculate expected token value based on weights
    //     uint256 expectedValue = ((ethPrice * ethWeight) / 100) +
    //         ((btcPrice * btcWeight) / 100);

    //     // Get the actual vault token value
    //     uint256 actualValue = vault.calculateVaultTokenValue();

    //     // Log values for debugging
    //     emit log_named_uint("Expected Value", expectedValue);
    //     emit log_named_uint("Actual Value", actualValue);

    //     // Assert that the values match
    //     assertEq(
    //         actualValue,
    //         expectedValue,
    //         "Vault value calculation mismatch"
    //     );

    //     // Assert that weights are correct
    //     assertEq(ethWeight, 50, "ETH weight should be 50%");
    //     assertEq(btcWeight, 50, "BTC weight should be 50%");
    // }

    function testDeposit() public {
        uint256 depositAmount = 1e18; // Amount to deposit

        // Log the user's Ether balance before the deposit
        emit log_named_uint(
            "User Ether balance before deposit",
            user.balance
        );

        // Start the prank as the user
        vm.startPrank(user);

        // Perform the deposit by sending ETH
        vault.deposit{value: depositAmount}(); // Send ETH to the deposit function

        // Log the user's Ether balance after the deposit
        emit log_named_uint(
            "User Ether balance after deposit",
            user.balance
        );
        emit log_named_uint("Vault balance of user", vault.balanceOf(user));
        emit log_named_uint(
            "Contract ETH balance",
            address(vault).balance
        );

        // Verify user received vault tokens
        uint256 finalUserBalance = vault.balanceOf(user);
        assertGt(finalUserBalance, 0, "User should receive vault tokens");

        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        // Log User's WETH balance
        emit log_named_uint(
            "User's WETH balance",
            uniswapV3.userWETHBalance(user)
        );

        // Log User's WBTC balance
        emit log_named_uint(
            "User's WBTC balance",
            IERC20(WBTC).balanceOf(user)
        );

        // Log User's Vault Token balance
        emit log_named_uint(
            "User's Vault Token balance",
            vault.balanceOf(user)
        );

        // Contract's ETH balance
        emit log_named_uint(
            "Contract's ETH balance",
            address(vault).balance
        );

        // Contract's WETH balance
        emit log_named_uint(
            "Contract's WETH balance",
            uniswapV3.getWETHBalance()
        );

        // Contract's WBTC balance
        emit log_named_uint(
            "Contract's WBTC balance",
            IERC20(WBTC).balanceOf(address(vault))
        );

        vault.withdraw(0.9 * 1e18);

        // End the prank
        vm.stopPrank();
    }

    // function testWithdraw() public {
    //     vm.startPrank(user);

    //     vm.stopPrank();
    // }
}
