// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/vault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultTest is Test {
    VaultToken public vault;
    IERC20 public usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IERC20 public eth = IERC20(0x0000000000000000000000000000000000000000);
    IERC20 public wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    // IERC20 public oneInch = IERC20(0x111111111117dC0aa78b770fA6A738034120C302);

    address public alice = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address public bob = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        // Setup token addresses and weights for vault
        address[] memory tokens = new address[](2);
        tokens[0] = address(eth);
        tokens[1] = address(wbtc);

        // Actual Blocksense price feed addresses
        address[] memory priceFeeds = new address[](2);
        priceFeeds[0] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD
        // priceFeeds[0] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // 1INCH/USD
        priceFeeds[1] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // BTC/USD

        uint256[] memory weights = new uint256[](2);
        weights[0] = 50;
        weights[1] = 50;

        // Deploy vault
        vault = new VaultToken("Test Vault", tokens, priceFeeds, weights);

        // Make ETH persistent
        vm.makePersistent(address(0));
        vm.makePersistent(address(usdc));
        vm.makePersistent(address(wbtc));
        vm.makePersistent(address(eth));

        // Fund test accounts with usdc
        vm.startPrank(alice);
        deal(address(usdc), alice, 1_000_000 * 1e6); // 1M USDC
        usdc.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        deal(address(usdc), bob, 1_000_000 * 1e6); // 1M USDC
        usdc.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(vault.getTokenDistributionCount(), 2);
        (address token0, uint256 weight0) = vault.getTokenDistributionData(0);
        assertEq(token0, address(eth));
        assertEq(weight0, 50);
        (address token1, uint256 weight1) = vault.getTokenDistributionData(1);
        assertEq(token1, address(wbtc));
        assertEq(weight1, 50);

        // Vault Market Cap should be 0
        assertEq(vault.calculateMarketCap(), 0);
    }

    function testDeposit() public {
        uint256 initialBalance = usdc.balanceOf(alice);
        uint256 depositAmount = 10_000 * 1e6; // 10k USDC

        vm.startPrank(alice);
        vault.deposit(depositAmount);

        assertEq(vault.getNumberOfInvestors(), 1);
        vm.stopPrank();

        vm.startPrank(bob);
        vault.deposit(depositAmount / 2);
        vm.stopPrank();
    }

    function testWithdraw() public {
        uint256 depositAmount = 10_000 * 1e6; // 10k USDC

        vm.startPrank(alice);
        vault.deposit(depositAmount);

        vm.roll(block.number + 1);

        uint256 depositAmountToWithdraw = depositAmount * 90 / 100;

        vault.withdraw(depositAmountToWithdraw);
        vm.stopPrank();
    }

    function testUpdateAssetsAndWeights() public {
        // First make a deposit to have some assets in the vault
        vm.startPrank(alice);
        vault.deposit(10_000 * 1e6);

        vm.stopPrank(); // Stop prank before updating assets and weights

        // Create new configuration with different weights
        address[] memory newTokens = new address[](2);
        newTokens[0] = address(wbtc);
        newTokens[1] = address(eth);

        address[] memory newPriceFeeds = new address[](2);
        newPriceFeeds[0] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // BTC/USD
        newPriceFeeds[1] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD

        uint256[] memory newWeights = new uint256[](2);
        newWeights[0] = 25;
        newWeights[1] = 75;

        // Start prank as the owner to update assets and weights
        vm.startPrank(vault.owner());
        vault.updateAssetsAndWeights(newTokens, newPriceFeeds, newWeights);

        (address token0, uint256 weight0) = vault.getTokenDistributionData(0);
        assertEq(token0, address(wbtc));
        assertEq(weight0, 25);
        (address token1, uint256 weight1) = vault.getTokenDistributionData(1);
        assertEq(token1, address(eth));
        assertEq(weight1, 75);

        vm.stopPrank(); // Stop prank after updating
    }

    receive() external payable {}
    fallback() external payable {}
}
