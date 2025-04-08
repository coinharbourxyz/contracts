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
    IERC20 public bnb = IERC20(0xB8c77482e45F1F44dE1745F52C74426C631bDD52);
    IERC20 public sol = IERC20(0xD31a59c85aE9D8edEFeC411D448f90841571b89c);
    IERC20 public tao = IERC20(0x77E06c9eCCf2E797fd462A92B6D7642EF85b0A44);

    address public alice = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address public bob = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        // Setup token addresses and weights for vault
        address[] memory tokens = new address[](5);
        tokens[0] = address(wbtc);
        tokens[1] = address(eth);
        tokens[2] = address(bnb);
        tokens[3] = address(sol);
        tokens[4] = address(tao);

        // Actual Blocksense price feed addresses
        address[] memory priceFeeds = new address[](5);
        priceFeeds[0] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // BTC/USD
        priceFeeds[1] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD
        priceFeeds[2] = 0x14e613AC84a31f709eadbdF89C6CC390fDc9540A; // BNB/USD
        priceFeeds[3] = 0x4ffC43a60e009B551865A93d232E33Fce9f01507; // SOL/USD
        priceFeeds[4] = 0x1c88503c9A52aE6aaE1f9bb99b3b7e9b8Ab35459; // TAO/USD

        uint256[] memory weights = new uint256[](5);
        weights[0] = 20;
        weights[1] = 20;
        weights[2] = 20;
        weights[3] = 20;
        weights[4] = 20;

        // Deploy vault
        vault = new VaultToken(
            "Test Vault",
            tokens,
            priceFeeds,
            weights,
            address(0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af),
            address(0x000000000022D473030F116dDEE9F6B43aC78BA3),
            address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
            address(0x0000000000000000000000000000000000000000),
            address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419)
        );

        // Make ETH persistent
        vm.makePersistent(address(0));
        vm.makePersistent(address(usdc));
        vm.makePersistent(address(wbtc));
        vm.makePersistent(address(eth));
        vm.makePersistent(address(bnb));
        vm.makePersistent(address(sol));
        vm.makePersistent(address(tao));

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
        assertEq(vault.getTokenDistributionCount(), 5);
        (address token0, uint256 weight0) = vault.getTokenDistributionData(0);
        assertEq(token0, address(wbtc));
        assertEq(weight0, 20);
        (address token1, uint256 weight1) = vault.getTokenDistributionData(1);
        assertEq(token1, address(eth));
        assertEq(weight1, 20);
        (address token2, uint256 weight2) = vault.getTokenDistributionData(2);
        assertEq(token2, address(bnb));
        assertEq(weight2, 20);
        (address token3, uint256 weight3) = vault.getTokenDistributionData(3);
        assertEq(token3, address(sol));
        assertEq(weight3, 20);
        (address token4, uint256 weight4) = vault.getTokenDistributionData(4);
        assertEq(token4, address(tao));
        assertEq(weight4, 20);

        // Vault Market Cap should be 0
        assertEq(vault.calculateMarketCap(), 0);
    }

    function testDeposit() public {
        uint256 initialBalance = usdc.balanceOf(alice);
        uint256 depositAmount = 10_000 * 1e6; // 10k USDC

        vm.startPrank(alice);
        vault.deposit(depositAmount);

        assertEq(vault.getNumberOfInvestors(), 1);
        // assertEq(vault.balanceOf(alice), depositAmount);
        // assertEq(vault.totalSupply(), depositAmount);

        // print vaults balance of each token
        console.log("vault.balanceOf(wbtc)", wbtc.balanceOf(address(vault)));
        console.log("vault.balanceOf(eth)", address(vault).balance);
        console.log("vault.balanceOf(bnb)", bnb.balanceOf(address(vault)));
        console.log("vault.balanceOf(sol)", sol.balanceOf(address(vault)));
        console.log("vault.balanceOf(tao)", tao.balanceOf(address(vault)));

        vm.stopPrank();

        vm.startPrank(bob);
        // vault.deposit(depositAmount / 2);
        vm.stopPrank();
    }

    // function testWithdraw() public {
    //     uint256 depositAmount = 10_000 * 1e6; // 10k USDC

    //     vm.startPrank(alice);
    //     vault.deposit(depositAmount);

    //     console.log("deposit completed");
    //     console.log("vault.balanceOf(alice)", vault.balanceOf(alice));
    //     console.log("vault.totalSupply()", vault.totalSupply());

    //     console.log("vault.balanceOf(wbtc)", wbtc.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(eth)", address(vault).balance);
    //     console.log("vault.balanceOf(bnb)", bnb.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(sol)", sol.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(tao)", tao.balanceOf(address(vault)));


    //     vm.roll(block.number + 1);

    //     uint256 depositAmountToWithdraw = depositAmount * 10 / 100;

    //     vault.withdraw(depositAmountToWithdraw);

    //     console.log("vault.balanceOf(wbtc)", wbtc.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(eth)", address(vault).balance);
    //     console.log("vault.balanceOf(bnb)", bnb.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(sol)", sol.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(tao)", tao.balanceOf(address(vault)));

    //     console.log("withdraw completed");
    //     console.log("vault.balanceOf(alice)", vault.balanceOf(alice));
    //     console.log("vault.totalSupply()", vault.totalSupply());

    //     vm.stopPrank();
    // }

    // function testUpdateAssetsAndWeights() public {
    //     // First make a deposit to have some assets in the vault
    //     vm.startPrank(alice);
    //     vault.deposit(10_000 * 1e6);

    //     console.log("vault.balanceOf(wbtc)", wbtc.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(eth)", address(vault).balance);
    //     console.log("vault.balanceOf(bnb)", bnb.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(sol)", sol.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(tao)", tao.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(usdc)", usdc.balanceOf(address(vault)));

    //     vm.stopPrank(); // Stop prank before updating assets and weights

    //     // Create new configuration with different weights
    //     address[] memory newTokens = new address[](2);
    //     newTokens[0] = address(wbtc);
    //     newTokens[1] = address(eth);

    //     address[] memory newPriceFeeds = new address[](2);
    //     newPriceFeeds[0] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // BTC/USD
    //     newPriceFeeds[1] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD

    //     uint256[] memory newWeights = new uint256[](2);
    //     newWeights[0] = 25;
    //     newWeights[1] = 75;

    //     // Start prank as the owner to update assets and weights
    //     vm.startPrank(vault.owner());
    //     vault.updateAssetsAndWeights(newTokens, newPriceFeeds, newWeights);

    //     (address token0, uint256 weight0) = vault.getTokenDistributionData(0);
    //     assertEq(token0, address(wbtc));
    //     assertEq(weight0, 25);
    //     (address token1, uint256 weight1) = vault.getTokenDistributionData(1);
    //     assertEq(token1, address(eth));
    //     assertEq(weight1, 75);

    //     vm.stopPrank(); // Stop prank after updating

    //     console.log("vault.balanceOf(wbtc)", wbtc.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(eth)", address(vault).balance);
    //     console.log("vault.balanceOf(bnb)", bnb.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(sol)", sol.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(tao)", tao.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(usdc)", usdc.balanceOf(address(vault)));
    // }

    // function testTransferAllFunds() public {
    //     uint256 initialBalance = usdc.balanceOf(alice);
    //     uint256 depositAmount = 10_000 * 1e6; // 10k USDC

    //     vm.startPrank(alice);
    //     vault.deposit(depositAmount);
        
    //     console.log("vault.balanceOf(wbtc)", wbtc.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(eth)", address(vault).balance);
    //     console.log("vault.balanceOf(bnb)", bnb.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(sol)", sol.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(tao)", tao.balanceOf(address(vault)));

    //     vault.transferAllFunds();

    //     console.log("vault.balanceOf(wbtc)", wbtc.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(eth)", address(vault).balance);
    //     console.log("vault.balanceOf(bnb)", bnb.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(sol)", sol.balanceOf(address(vault)));
    //     console.log("vault.balanceOf(tao)", tao.balanceOf(address(vault)));


    //     vm.stopPrank();
    // }

    receive() external payable {}
    fallback() external payable {}
}
