// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol"; // Import Forge console
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
    uint32 constant ETH_USD_FEED_ID = 47;
    uint32 constant BTC_USD_FEED_ID = 31;

    // Mainnet addresses for price feeds
    address constant ETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant BTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

// 0x43A444AC5d00b96Daf62BC00C50FA47c1aFCf3C3


    // address constant UNISWAP_V3_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // UniswapV3 uniswapV3 = new UniswapV3();

    // Events from VaultToken contract
    // event TokensSwapped(address tokenOut, uint256 amountReceived);
    // event AllocationsUpdated(address[] tokens, uint256[] weights);

    function setUp() public {
        console.log("SetUp start");
        // Mock data for tokens
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = ETH_ADDRESS; // WETH
        tokenAddresses[1] = BTC_ADDRESS; // WBTC

        uint32[] memory priceFeeds = new uint32[](2);
        priceFeeds[0] = ETH_USD_FEED_ID;
        priceFeeds[1] = BTC_USD_FEED_ID;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 50;
        weights[1] = 50;

        vault = new VaultToken(
            "Vault Token",
            tokenAddresses,
            priceFeeds,
            weights
        );
        console.log("SetUp end");
    }

    function testSetUp() public {
        assertEq(
            vault.name(),
            "Vault Token",
            "Vault token name should be correct"
        );
        assertEq(
            vault.symbol(),
            "Vault Token",
            "Vault token symbol should be correct"
        );
        // assertEq(vault.owner(), owner, "Vault owner should be correct");
        assertEq(
            vault.getTokenDistributionCount(),
            2,
            "Vault should have 2 tokens"
        );
        assertEq(
            vault.tokenBalances(ETH_ADDRESS),
            0,
            "Vault should have 0 WETH balance"
        );
        assertEq(
            vault.tokenBalances(BTC_ADDRESS),
            0,
            "Vault should have 0 WBTC balance"
        );
        assertEq(
            vault.balanceOf(user),
            0,
            "User should have 0 vault token balance"
        );
        assertEq(vault.totalSupply(), 0, "Vault should have 0 total supply");

        // Get the price of ETH and BTC
        int256 ethPrice = vault.getLatestPrice(ETH_USD_FEED_ID);
        int256 btcPrice = vault.getLatestPrice(BTC_USD_FEED_ID);
        assertGt(ethPrice, 0, "ETH Price should be greater than 0");
        assertGt(btcPrice, 0, "BTC Price should be greater than 0");
        // console.log("ETH Price:", ethPrice);
        // console.log("BTC Price:", btcPrice);

        // Test that the allocations are set correctly
        // (address tokenAddress0, int32 priceFeed0, uint256 weight0) = vault
        //     .getTokenDistributionData(0);
        // (address tokenAddress1, int32 priceFeed1, uint256 weight1) = vault
        //     .getTokenDistributionData(1);
        // assertEq(weight0, 50, "ETH should have 50% allocation");
        // assertEq(weight1, 50, "BTC should have 50% allocation");

        // assertEq(
        //     tokenAddress0,
        //     ETH_ADDRESS,
        //     "ETH should have 50% allocation"
        // );
        // assertEq(
        //     tokenAddress1,
        //     BTC_ADDRESS,
        //     "BTC should have 50% allocation"
        // );

        // assertEq(
        //     priceFeed0,
        //     ETH_USD_FEED_ID,
        //     "ETH should have 50% allocation"
        // );
        // assertEq(
        //     priceFeed1,
        //     BTC_USD_FEED_ID,
        //     "BTC should have 50% allocation"
        // );
    }

    // function testDeposit() public {
    //     // Start the prank as the user
    //     vm.startPrank(user);

    //     uint256 depositAmount = 100*1e18; // Amount to deposit

    //     // Perform the deposit by sending ETH
    //     vault.deposit{value: depositAmount}(); // Send ETH to the deposit function

    //     // Verify user received vault tokens
    //     uint256 finalUserBalance = vault.balanceOf(user);
    //     assertGt(finalUserBalance, 0, "User should receive vault tokens");
    //     console.log("User's Vault Token balance", finalUserBalance/ 1e18);

    //     // Contract's balance
    //     console.log("Contract's WETH balance", IERC20(ETH_ADDRESS).balanceOf(address(vault)));

    //     uint256 btcbalance = IERC20(BTC_ADDRESS).balanceOf(address(vault));
    //     uint8 decimals = IERC20Metadata(BTC_ADDRESS).decimals();
    //     uint256 btcin18  = vault.convertInputTo18Decimals(btcbalance, decimals);
    //     console.log("Contract's WBTC balance", btcin18);

    //     // End the prank
    //     vm.stopPrank();
    // }

    // function testUpdateAssetsAndWeights() public {
    //     // If ETH is being used to mint WETH
    //     vault.deposit{value: 1000*1e18}();  // Deposit 1000 ETH to get WETH in your test

    //     // Contract's balance
    //     console.log("Contract's WETH balance", IERC20(ETH_ADDRESS).balanceOf(address(vault)));

    //     uint256 DAIbalance = IERC20(DAI_ADDRESS).balanceOf(address(vault));
    //     uint8 DAIdecimals = IERC20Metadata(DAI_ADDRESS).decimals();
    //     uint256 DAIin18  = vault.convertInputTo18Decimals(DAIbalance, DAIdecimals);
    //     console.log("Contract's DAI balance", DAIbalance);

    //     uint256 BTCbalance = IERC20(BTC_ADDRESS).balanceOf(address(vault));
    //     uint8 BTCdecimals = IERC20Metadata(BTC_ADDRESS).decimals();
    //     uint256 BTCin18  = vault.convertInputTo18Decimals(BTCbalance, BTCdecimals);
    //     console.log("Contract's WBTC balance", BTCin18);

    //     // New token addresses and weights
    //     address[] memory newTokenAddresses = new address[](2);
    //     newTokenAddresses[0] = BTC_ADDRESS; // BTC
    //     newTokenAddresses[1] = DAI_ADDRESS; // DAI

    //     address[] memory newPriceFeeds = new address[](2);
    //     newPriceFeeds[0] = BTC_USD_FEED; // BTC/USD feed
    //     newPriceFeeds[1] = DAI_USD_FEED; // DAI/USD feed

    //     uint256[] memory newWeights = new uint256[](2);
    //     newWeights[0] = 60;
    //     newWeights[1] = 40;

    //     // Start the prank as the owner
    //     vm.startPrank(owner);

    //     // Update the assets and weights
    //     vault.updateAssetsAndWeights(newTokenAddresses, newPriceFeeds, newWeights);

    //     // Verify the updates
    //     (, , uint256 weight0) = vault.getTokenDistributionData(0);
    //     (, , uint256 weight1) = vault.getTokenDistributionData(1);
    //     assertEq(weight0, 60, "BTC should have 60% allocation");
    //     assertEq(weight1, 40, "DAI should have 40% allocation");

    //     // Contract's balance
    //     console.log("Contract's WETH balance", IERC20(ETH_ADDRESS).balanceOf(address(vault)));
    //     console.log("Contract's DAI balance", IERC20(DAI_ADDRESS).balanceOf(address(vault)));
    //     console.log("Contract's WBTC balance", IERC20(BTC_ADDRESS).balanceOf(address(vault)));
    //     // End the prank
    //     vm.stopPrank();
    // }

    // function testWithdraw() public {
    //     uint256 depositAmount = 1e18; // Amount to deposit
    //     uint256 withdrawAmount = 0.5e18; // Amount to withdraw

    //     // Start the prank as the user
    //     vm.startPrank(user);

    //     console.log("Contract's WETH balance", IERC20(ETH_ADDRESS).balanceOf(address(vault)));

    //     uint256 DAIbalance = IERC20(DAI_ADDRESS).balanceOf(address(vault));
    //     uint8 DAIdecimals = IERC20Metadata(DAI_ADDRESS).decimals();
    //     uint256 DAIin18  = vault.convertInputTo18Decimals(DAIbalance, DAIdecimals);
    //     console.log("Contract's DAI balance", DAIbalance);

    //     uint256 BTCbalance = IERC20(BTC_ADDRESS).balanceOf(address(vault));
    //     uint8 BTCdecimals = IERC20Metadata(BTC_ADDRESS).decimals();
    //     uint256 BTCin18  = vault.convertInputTo18Decimals(BTCbalance, BTCdecimals);
    //     console.log("Contract's WBTC balance", BTCin18);

    //     console.log("User's fund tokens", vault.balanceOf(user));

    //     // Perform the deposit by sending ETH
    //     vault.deposit{value: depositAmount}();

    //     console.log("Contract's WETH balance", IERC20(ETH_ADDRESS).balanceOf(address(vault)));

    //     DAIbalance = IERC20(DAI_ADDRESS).balanceOf(address(vault));
    //     DAIdecimals = IERC20Metadata(DAI_ADDRESS).decimals();
    //     DAIin18  = vault.convertInputTo18Decimals(DAIbalance, DAIdecimals);
    //     console.log("Contract's DAI balance", DAIbalance);

    //     BTCbalance = IERC20(BTC_ADDRESS).balanceOf(address(vault));
    //     BTCdecimals = IERC20Metadata(BTC_ADDRESS).decimals();
    //     BTCin18  = vault.convertInputTo18Decimals(BTCbalance, BTCdecimals);
    //     console.log("Contract's WBTC balance", BTCin18);

    //     console.log("User's fund tokens", vault.balanceOf(user));

    //     // Perform the withdrawal
    //     vault.withdraw(withdrawAmount);

    //     console.log("Contract's WETH balance", IERC20(ETH_ADDRESS).balanceOf(address(vault)));

    //     DAIbalance = IERC20(DAI_ADDRESS).balanceOf(address(vault));
    //     DAIdecimals = IERC20Metadata(DAI_ADDRESS).decimals();
    //     DAIin18  = vault.convertInputTo18Decimals(DAIbalance, DAIdecimals);
    //     console.log("Contract's DAI balance", DAIbalance);

    //     BTCbalance = IERC20(BTC_ADDRESS).balanceOf(address(vault));
    //     BTCdecimals = IERC20Metadata(BTC_ADDRESS).decimals();
    //     BTCin18  = vault.convertInputTo18Decimals(BTCbalance, BTCdecimals);
    //     console.log("Contract's WBTC balance", BTCin18);

    //     console.log("User's fund tokens", vault.balanceOf(user));

    //     // Verify user received ETH back
    //     emit log_named_uint("User Ether balance after withdrawal", user.balance);
    //     assertGt(user.balance, withdrawAmount, "User should receive ETH back");

    //     // End the prank
    //     vm.stopPrank();
    // }

    // function testOtherMetrics() public {
    //     uint256 depositAmount = 1e18; // Amount to deposit

    //     // Start the prank as the user
    //     vm.startPrank(user);

    //     // Perform the deposit by sending ETH
    //     vault.deposit{value: depositAmount}();
    //     uint256 nav = vault.getNAV();
    //     uint256 totalInvestedValue = vault.calculateMarketCap();
    //     uint256 totalSupply = vault.totalSupply();
    //     uint256 numberOfInvestors = vault.getNumberOfInvestors();
    //     console.log("1. Current Vault:");
    //     console.log("Total Invested Value: %s", totalInvestedValue);
    //     console.log("NAV: %s", nav);
    //     console.log("Total Supply: %s", totalSupply);
    //     console.log("Number of Investors: %s", numberOfInvestors);

    //     // Perform the deposit by sending ETH
    //     vault.deposit{value: depositAmount}();
    //     nav = vault.getNAV();
    //     totalInvestedValue = vault.calculateMarketCap();
    //     totalSupply = vault.totalSupply();
    //     numberOfInvestors = vault.getNumberOfInvestors();
    //     console.log("2. Current Vault:");
    //     console.log("Total Invested Value: %s", totalInvestedValue);
    //     console.log("NAV: %s", nav);
    //     console.log("Total Supply: %s", totalSupply);
    //     console.log("Number of Investors: %s", numberOfInvestors);

    //     // Withdraw
    //     vault.withdraw(depositAmount);
    //     nav = vault.getNAV();
    //     totalInvestedValue = vault.calculateMarketCap();
    //     totalSupply = vault.totalSupply();
    //     numberOfInvestors = vault.getNumberOfInvestors();
    //     console.log("3. Current Vault:");
    //     console.log("Total Invested Value: %s", totalInvestedValue);
    //     console.log("NAV: %s", nav);
    //     console.log("Total Supply: %s", totalSupply);
    //     console.log("Number of Investors: %s", numberOfInvestors);

    //     // End the prank
    //     vm.stopPrank();
    // }

    //     function testComplete() public{
    //         testSetUp();
    //         testDeposit();
    //         testUpdateAssetsAndWeights();
    //         testWithdraw();
    //         testOtherMetrics();
    //     }
}
