// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {console} from "forge-std/console.sol";
// import {Swap} from "./Swap.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

import {PoolKey} from "v4-core/src/types/PoolKey.sol";

import {SafeCast} from "lib/v4-periphery/lib/v4-core/src/libraries/SafeCast.sol";

import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";

import {Currency} from "v4-core/src/types/Currency.sol";

import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "lib/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import "lib/v4-periphery/src/lens/V4Quoter.sol";

interface IPermit2 {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}

interface IBlocksense {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function decimals() external view returns (uint8);
}

contract VaultToken is ERC20, Ownable {
    // Constants
    uint256 private constant TOTAL_WEIGHT = 100;
    uint256 private constant SCALE = 1e18;
    uint24 private constant DEFAULT_POOL_FEE = 3000;

    // Immutable addresses
    address payable private immutable UNIVERSAL_ROUTER;
    address payable private immutable PERMIT2_ADDRESS;
    address private immutable USDC;
    address private immutable ETH;

    // Contract instances
    UniversalRouter public immutable router;
    IPermit2 public immutable permit2;
    IBlocksense public immutable ethPriceFeed;

    ISwapRouter constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); // Uniswap V3 Router
    address public WETH  = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
                                 
    struct TokenWeights {
        address tokenAddress;
        IBlocksense priceFeed;
        uint256 weight;
    }

    TokenWeights[] public tokens;
    uint256 private numberOfInvestors = 0;

    constructor(
        string memory name,
        address[] memory tokenAddresses,
        address[] memory blocksensePriceAggregators,
        uint256[] memory weights,
        address universalRouterAddress,
        address permit2Address,
        address usdcAddress,
        address ethAddress,
        address ethPriceFeedAddress
    ) ERC20(name, name) Ownable(msg.sender) {
        require(
            tokenAddresses.length == blocksensePriceAggregators.length
                && blocksensePriceAggregators.length == weights.length,
            "Arrays must be of equal length"
        );

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            require(weights[i] > 0, "Weight must be positive");
            totalWeight += weights[i];
        }
        require(totalWeight == TOTAL_WEIGHT, "Total weights must sum to 100");

        for (uint256 i = 0; i < weights.length; i++) {
            tokens.push(
                TokenWeights({
                    tokenAddress: tokenAddresses[i],
                    priceFeed: IBlocksense(address(blocksensePriceAggregators[i])),
                    weight: weights[i]
                })
            );
        }

        // Set immutable addresses in the constructor
        UNIVERSAL_ROUTER = payable(universalRouterAddress);
        PERMIT2_ADDRESS = payable(permit2Address);
        USDC = usdcAddress;
        ETH = ethAddress;

        // Initialize contract instances
        router = UniversalRouter(UNIVERSAL_ROUTER);
        permit2 = IPermit2(PERMIT2_ADDRESS);
        ethPriceFeed = IBlocksense(ethPriceFeedAddress);
    }

    function getTokenDistributionCount() public view returns (uint256) {
        return tokens.length;
    }

    function getTokenDistributionData(uint256 index) public view returns (address, uint256) {
        require(index < tokens.length, "Index out of bounds");
        TokenWeights memory tokenData = tokens[index];
        return (tokenData.tokenAddress, tokenData.weight);
    }

    function convertInputTo18Decimals(uint256 amount, uint8 decimals) public pure returns (uint256) {
        if (decimals < 18) {
            return amount * 10 ** (18 - decimals);
        } else if (decimals > 18) {
            return amount / 10 ** (decimals - 18);
        }
        return amount;
    }

    function convertInputToTokenDecimals(uint256 amount, address token) public view returns (uint256) {
        if (token == address(0)) {
            return amount;
        }
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        if (tokenDecimals < 18) {
            return amount / (10 ** (18 - tokenDecimals));
        } else if (tokenDecimals > 18) {
            return amount * (10 ** (tokenDecimals - 18));
        }
        return amount;
    }

    function convertToken1ToToken2Decimals(uint256 amount, address token1, address token2) public view returns (uint256) {
        if (token1 == token2) {
            return amount;
        }
        uint8 token1Decimals = IERC20Metadata(token1).decimals();
        uint8 token2Decimals = IERC20Metadata(token2).decimals();
        if (token1Decimals < token2Decimals) {
            return amount * (10 ** (token2Decimals - token1Decimals));
        } else if (token1Decimals > token2Decimals) {
            return amount / (10 ** (token1Decimals - token2Decimals));
        }
        return amount;
    }

    function getLatestPrice(IBlocksense priceFeed) public view returns (int256, uint8) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint8 decimals = priceFeed.decimals();
        require(price > 0, "Invalid price");
        return (price, decimals);
    }

    function getErc20Balance(address tokenAddress) public view returns (uint256) {
        if (tokenAddress == address(0)) {
            return address(this).balance;
        }
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        uint8 decimals = IERC20Metadata(tokenAddress).decimals();
        return convertInputTo18Decimals(balance, decimals);
    }

    function getErc20Allowance(address tokenAddress) public view returns (uint256) {
        uint256 allowance = IERC20(tokenAddress).allowance(address(this), address(router));
        uint8 decimals = IERC20Metadata(tokenAddress).decimals();
        return convertInputTo18Decimals(allowance, decimals);
    }

    function calculateMarketCap() public view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddr = tokens[i].tokenAddress;
            uint256 balanceInDecimals = getErc20Balance(tokenAddr);
            if (balanceInDecimals > 0) {
                if (tokenAddr == address(0) && totalSupply() == 0) {
                    continue; // Skip ETH balance if no shares have been minted yet
                }
                (int256 price, uint8 decimals) = getLatestPrice(tokens[i].priceFeed);
                uint256 priceInDecimals = convertInputTo18Decimals(uint256(price), decimals);
                uint256 value = (balanceInDecimals * priceInDecimals) / 1e18;
                totalValue += value;
            }
        }
        return totalValue;
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
        return marketCap * 1e18 / totalSupply;
    }

    function minAmountOutInOutDecimals(uint256 slippageTolerance, uint256 amountIn, address tokenIn, address tokenOut, int256 tokenPrice, uint8 decimals) 
    public view returns (uint128, uint8) {
        uint8 tokenOutDecimals = 18;
        if (tokenOut != address(0)) {
            tokenOutDecimals = IERC20Metadata(tokenOut).decimals();
        }

        uint256 tokenPriceInTokenDecimals = convertInputTo18Decimals(uint256(tokenPrice), decimals);
        if (tokenOut != address(0)) {
            tokenPriceInTokenDecimals = convertInputToTokenDecimals(tokenPriceInTokenDecimals, tokenOut);
        }

        uint256 amountInWithSlippage = amountIn * slippageTolerance / 100;
        uint256 amountInWithTokenOutDecimals = 0;
        if (tokenOut == address(0)){
            amountInWithTokenOutDecimals = convertInputTo18Decimals(amountInWithSlippage, IERC20Metadata(USDC).decimals());
        } else {
            amountInWithTokenOutDecimals = convertToken1ToToken2Decimals(amountInWithSlippage, USDC, tokenOut);
        }

        uint128 outTokensInOutDecimals = uint128((amountInWithTokenOutDecimals * (10 ** tokenOutDecimals)) / tokenPriceInTokenDecimals);
        
        // console.log("swapping token in", USDC, IERC20Metadata(USDC).decimals());
        // console.log("swapping token out", tokenOut);
        // console.log("erc 20 decimals", (tokenOut == address(0))? 18 : IERC20Metadata(tokenOut).decimals());
        // console.log("token out price", tokenPriceInTokenDecimals);
        // console.log("amountInWithTokenOutDecimals", amountInWithTokenOutDecimals);
        // console.log("Min amount out:-", outTokensInOutDecimals);

        return (outTokensInOutDecimals, tokenOutDecimals);
    }

    function deposit(uint256 amount) external payable {
        require(amount > 0, "Invalid amount");
        uint256 vaultValueBeforeInDecimals = calculateMarketCap();

        bool success = IERC20(USDC).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed!");

        // Send 1% of the amount to the owner
        uint256 amountToSendToOwner = amount * 1 / 100;
        bool successFee = IERC20(USDC).transfer(0x2B55a066236d4943b18b6fa18397D66f7F188E1a, amountToSendToOwner);
        require(successFee, "Could not deduce protocol fee!");

        amount = amount - amountToSendToOwner;

        uint256 navBefore = getNAV();
        uint256 totalMintedValue = 0;

        // Distribute the total amount according to weights in tokens array
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenOut = tokens[i].tokenAddress;
            uint256 allocationWeight = tokens[i].weight;

            (int256 tokenPrice, uint8 decimals) = getLatestPrice(tokens[i].priceFeed);
            require(tokenPrice > 0, "Token price must be greater than zero");

            uint256 amountIn = (amount * allocationWeight) / 100;
            uint256 amountOut = amountIn;

            // Perform the swap using Universal Router
            uint256 slippageTolerance = 50;
            if (tokenOut != USDC) {
                (uint128 minAmountOut, uint8 tokenOutDecimals) = minAmountOutInOutDecimals(slippageTolerance, amountIn, USDC, tokenOut, tokenPrice, decimals);
                amountOut = swapOnBest(USDC, tokenOut, amountIn, uint256(minAmountOut));
                amountOut = convertInputTo18Decimals(amountOut, tokenOutDecimals);
            }

            uint256 tokenPriceInDecimals = convertInputTo18Decimals(uint256(tokenPrice), decimals);
            uint256 tokenValueInUsd = (amountOut * tokenPriceInDecimals) / 1e18;
            totalMintedValue += tokenValueInUsd;
        }

        uint256 sharesToMint;
        if (totalSupply() == 0 || vaultValueBeforeInDecimals == 0) {
            sharesToMint = totalMintedValue;
        } else {
            sharesToMint = totalMintedValue * 1e18 / navBefore;
        }
        require(sharesToMint > 0, "Shares to mint must be greater than zero");
        if (balanceOf(msg.sender) == 0) {
            numberOfInvestors += 1;
        }
        _mint(msg.sender, sharesToMint);
    }

    function withdraw(uint256 usdToWithdraw) external payable {
        require(usdToWithdraw > 0, "Invalid amount");

        uint8 tokenOutDecimals = IERC20Metadata(USDC).decimals();
        uint256 usdToWithdrawIn18Dec = convertInputTo18Decimals(usdToWithdraw, tokenOutDecimals);

        uint256 nav = getNAV();
        require(nav > 0, "NAV must be greater than zero");
        uint256 sharesToBurn = (usdToWithdrawIn18Dec * 1e18) / nav;
        require(sharesToBurn > 0, "Shares to burn must be greater than zero");
        require(sharesToBurn <= balanceOf(msg.sender), "Insufficient shares");

        uint256 totalValue = calculateMarketCap();
        uint256 totalUsdcReceived = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenIn = tokens[i].tokenAddress;

            (int256 tokenPrice, uint8 decimals) = getLatestPrice(tokens[i].priceFeed);
            uint256 tokenPriceIn18 = convertInputTo18Decimals(uint256(tokenPrice), decimals);
            uint256 balanceInDecimals = getErc20Balance(tokenIn);
            uint256 value = (balanceInDecimals * tokenPriceIn18) / 1e18;
            uint256 allocationWeight = (value * 100)/totalValue;

            // Calculate withdrawal amount based on allocation weight
            uint256 withdrawalAmount = (usdToWithdrawIn18Dec * allocationWeight) / 100;

            if (tokenIn != USDC) {
                // Calculate how many tokens to withdraw based on price
                uint256 tokenAmountToWithdraw = (withdrawalAmount * 1e18) / tokenPriceIn18;
                require(getErc20Balance(tokenIn) >= tokenAmountToWithdraw, "Vault has insufficient token balance");

                // Convert tokenAmountToWithdraw to token decimals
                tokenAmountToWithdraw = convertInputToTokenDecimals(tokenAmountToWithdraw, tokenIn);

                uint256 slippageTolerance = 50;
                uint256 minUSDtoWithdraw = (usdToWithdraw * allocationWeight * slippageTolerance) / (100 * 100);
                uint256 usdcReceived = withdrawViaBest(tokenIn, USDC, uint128(tokenAmountToWithdraw), uint128(minUSDtoWithdraw));

                totalUsdcReceived += usdcReceived;
            } else {
                totalUsdcReceived += withdrawalAmount;
            }
        }

        _burn(msg.sender, sharesToBurn);
        if (balanceOf(msg.sender) == 0) {
            numberOfInvestors -= 1;
        }

        require(totalUsdcReceived > 0, "Transfer amount must be greater than zero");
        bool success = IERC20(USDC).transfer(msg.sender, totalUsdcReceived);
        require(success, "USDC transfer failed");
    }

    function updateAssetsAndWeights(
        address[] memory tokenAddresses,
        address[] memory blocksensePriceAggregators,
        uint256[] memory weights
    ) external onlyOwner {
        require(
            tokenAddresses.length == blocksensePriceAggregators.length
                && blocksensePriceAggregators.length == weights.length,
            "Arrays must be of equal length"
        );

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            require(weights[i] > 0, "Weight must be positive");
            totalWeight += weights[i];
        }

        require(totalWeight == TOTAL_WEIGHT, "Total weights must sum to 100");

        // Swap existing tokens to ETH
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddr = tokens[i].tokenAddress;
            uint256 balanceIn18 = getErc20Balance(tokenAddr);

            if (tokenAddr != USDC && balanceIn18 > 0) { 
                (int256 tokenPrice, uint8 decimals) = getLatestPrice(tokens[i].priceFeed);
                uint256 tokenPriceIn18 = convertInputTo18Decimals(uint256(tokenPrice), decimals);
                uint256 amountOutIn18Decimals = (tokenPriceIn18 * balanceIn18) / 1e18;
                uint256 amountOutInUSDDecimals = convertInputToTokenDecimals(amountOutIn18Decimals, USDC);

                uint256 slippageTolerance = 50;
                uint256 minUSDtoWithdraw = (amountOutInUSDDecimals * slippageTolerance) / 100;
            
                uint256 balance = convertInputToTokenDecimals(balanceIn18, tokenAddr);
                withdrawViaBest(tokenAddr, USDC, balance, minUSDtoWithdraw);
            }
        }

        // uint256 totalETHBalance = address(this).balance;
        uint256 totalUSDBalance = IERC20(USDC).balanceOf(address(this));
        delete tokens;

        // Add the new tokens and their weights
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            tokens.push(
                TokenWeights({
                    tokenAddress: tokenAddresses[i],
                    priceFeed: IBlocksense(address(blocksensePriceAggregators[i])),
                    weight: weights[i]
                })
            );
        }



        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenOut = tokenAddresses[i];
            uint256 allocationWeight = weights[i];
            uint256 amountToSwap = (totalUSDBalance * allocationWeight) / 100;

            // Perform the swap from ETH to the new token
            if (tokenOut != USDC && amountToSwap > 0) {
                uint256 slippageTolerance = 50;
                (int256 tokenPrice, uint8 decimals) = getLatestPrice( IBlocksense(address(blocksensePriceAggregators[i])));
                (uint128 minAmountOut, ) = minAmountOutInOutDecimals(slippageTolerance, amountToSwap, USDC, tokenOut, tokenPrice, decimals);
                swapOnBest(USDC, tokenOut, amountToSwap , uint256(minAmountOut));
            }
        }
    }

    // Fallback function to accept ETH
    receive() external payable {}

    // Fallback function to accept ETH (with data)
    fallback() external payable {}

    function swapExactInputSingleV4(
        address token0,
        address token1,
        uint24 fee,
        uint128 amountIn,
        uint128 minAmountOut,
        bool _zeroForOne
    ) public returns (uint256 amountOut) {
        // Convert addresses to uint160 for comparison
        uint160 token0Value = uint160(token0);
        uint160 token1Value = uint160(token1);

        // Handle ETH (address(0)) cases
        if (token0 == address(0)) token0Value = 0;
        if (token1 == address(0)) token1Value = 0;

        // Determine if we need to swap token order to match Uniswap's sorting
        bool needsSort = token0Value > token1Value;

        // Create PoolKey with correctly sorted tokens
        PoolKey memory key = PoolKey(
            Currency.wrap(needsSort ? token1 : token0),
            Currency.wrap(needsSort ? token0 : token1),
            fee,
            60,
            IHooks(0x0000000000000000000000000000000000000000)
        );

        // Adjust zeroForOne based on whether we had to sort
        _zeroForOne = needsSort ? !_zeroForOne : _zeroForOne;

        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        (amountIn);

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: _zeroForOne,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                // sqrtPriceLimitX96: uint160(0),
                hookData: bytes("")
            })
        );

        Currency inputTokens = _zeroForOne ? key.currency0 : key.currency1;
        Currency outputTokens = _zeroForOne ? key.currency1 : key.currency0;
        params[1] = abi.encode(inputTokens, amountIn);
        params[2] = abi.encode(outputTokens, minAmountOut);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        uint256 amountBefore = needsSort
            ? key.currency0 == Currency.wrap(address(0))
                ? address(this).balance
                : IERC20(Currency.unwrap(key.currency0)).balanceOf(address(this))
            : key.currency1 == Currency.wrap(address(0))
                ? address(this).balance
                : IERC20(Currency.unwrap(key.currency1)).balanceOf(address(this));

        if (Currency.unwrap(key.currency0) != address(0)) {
            IERC20(Currency.unwrap(key.currency0)).approve(address(permit2), type(uint256).max);
            permit2.approve(Currency.unwrap(key.currency0), address(router), amountIn, type(uint48).max);
        }
        if (Currency.unwrap(key.currency1) != address(0)) {
            IERC20(Currency.unwrap(key.currency1)).approve(address(permit2), type(uint256).max);
            permit2.approve(Currency.unwrap(key.currency1), address(router), amountIn, type(uint48).max);
        }

        // Execute the swap with ETH value if needed
        if (token0 == address(0)) {
            router.execute{value: amountIn}(commands, inputs, block.timestamp);
        } else {
            router.execute(commands, inputs, block.timestamp);
        }

        // Verify and return the output amount
        uint256 amountAfter = needsSort
            ? key.currency0 == Currency.wrap(address(0))
                ? address(this).balance
                : IERC20(Currency.unwrap(key.currency0)).balanceOf(address(this))
            : key.currency1 == Currency.wrap(address(0))
                ? address(this).balance
                : IERC20(Currency.unwrap(key.currency1)).balanceOf(address(this));

        require((amountAfter - amountBefore) >= minAmountOut, "Insufficient output amount");
        return amountAfter - amountBefore;
    }

    function swapExactInputSingleV3(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint128 amountIn,
        uint128 minAmountOut
    ) public returns (uint256 amountOut) {
        if(tokenIn == tokenOut) return amountIn;
        
        IERC20(tokenIn).approve(address(swapRouter), amountIn);
        require(IERC20(tokenIn).allowance(address(this), address(swapRouter)) >= amountIn, "Insufficient allowance");
        require(IERC20(tokenIn).balanceOf(address(this)) >= amountIn, "Insufficient balance");

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0
        });

        amountOut = swapRouter.exactInputSingle(params);
        return amountOut;
    }

    function getBestQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public returns (uint256, bool, uint24) {
        if(tokenIn == tokenOut) return (amountIn, true, 3000);

        address QUOTER_V2 = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
        address QUOTER_V4 = 0x52F0E24D1c21C8A0cB1e5a5dD6198556BD9E1203;
        // address SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
        // address UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
        
        uint24[2] memory feeTiers;
        feeTiers[0] = 3000;
        feeTiers[1] = 10000;

        uint256 bestAmountOut = 0;
        uint24 bestFeeTier;
        bool v3IsBest = true;


        // check quote for v3!
        if(tokenIn != address(0) && tokenOut != address(0)){
            for (uint256 i = 0; i < feeTiers.length; i++) {
                IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2.QuoteExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountIn: amountIn,
                    fee: feeTiers[i],
                    sqrtPriceLimitX96: 0
                });

                try IQuoterV2(QUOTER_V2).quoteExactInputSingle(params)
                returns (uint256 quoteOut, uint160, uint32, uint256) {     
                    if (quoteOut > bestAmountOut) {
                        bestAmountOut = quoteOut;
                        bestFeeTier = feeTiers[i];
                        v3IsBest = true;
                    }
                } catch {}
            }
        }

        // check quote for v4!
        bool needsSort = ((tokenIn == address(0)) ? 0 : uint160(tokenIn)) > ((tokenOut == address(0)) ? 0 : uint160(tokenOut));
        bool _zeroForOne = !needsSort;
        for (uint256 i = 0; i < feeTiers.length; i++) {
            PoolKey memory key = PoolKey(
                Currency.wrap(needsSort ? tokenOut : tokenIn),
                Currency.wrap(needsSort ? tokenIn : tokenOut),
                feeTiers[i],
                60,
                IHooks(0x0000000000000000000000000000000000000000)
            );

            IV4Quoter.QuoteExactSingleParams memory params = IV4Quoter.QuoteExactSingleParams({
                poolKey: key,
                zeroForOne: _zeroForOne,
                exactAmount: uint128(amountIn),
                hookData: bytes("")
            });

            try IV4Quoter(QUOTER_V4).quoteExactInputSingle(params)
            returns (uint256 quoteOut, uint256) {                
                if (quoteOut > bestAmountOut) {
                    bestAmountOut = quoteOut;
                    bestFeeTier = feeTiers[i];
                    v3IsBest = false;
                }
            } catch {}   
        }

        return (bestAmountOut, v3IsBest, bestFeeTier);
    }
    
    function swapOnBest(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) public returns (uint256) {
        // console.log("::::Swapping for", tokenOut);

        if(tokenOut == address(0) || tokenOut == WETH){
            // console.log("swapping eth single hop directly");
            return swapExactInputSingleV4(USDC, tokenOut, DEFAULT_POOL_FEE, uint128(amountIn), uint128(minAmountOut), true);
        }

        address ETH_PRICE_FEED = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        (int256 ETHPrice, uint8 price_decimals) = getLatestPrice(IBlocksense(ETH_PRICE_FEED));
        uint256 ETHPriceIn18Decimals = convertInputTo18Decimals(uint256(ETHPrice), price_decimals);
        uint256 amountInInETH = (convertInputTo18Decimals(amountIn, IERC20Metadata(USDC).decimals())  * (1e18)) / ETHPriceIn18Decimals;
        
        // check quote via different routes 
        (uint256 amountOut1, bool v3IsBest1, uint24 bestFeeTier1) = getBestQuote(USDC, tokenOut, uint256(amountIn));
        (uint256 amountOut2, bool v3IsBest2, uint24 bestFeeTier2) = getBestQuote(WETH, tokenOut, uint256(amountInInETH));
        (uint256 amountOut3, , uint24 bestFeeTier3) = getBestQuote(ETH, tokenOut, uint256(amountInInETH));

        uint256 amountOut;
        if(amountOut1 >= amountOut2 && amountOut1 >= amountOut3){ // single-hop! trade directly with USDC
            if(v3IsBest1){
                // console.log("swapping single hop on v3");
                amountOut = swapExactInputSingleV3(USDC, tokenOut, bestFeeTier1, uint128(amountIn), uint128(minAmountOut));
            }else{
                // console.log("swapping single hop on v4");
                amountOut = swapExactInputSingleV4(USDC, tokenOut, bestFeeTier1, uint128(amountIn), uint128(minAmountOut), true);
            }
        }else if(amountOut2 >= amountOut3){   
            // console.log("converting amountIn to WETH");
            uint256 ethOut = swapExactInputSingleV3(USDC, WETH, DEFAULT_POOL_FEE, uint128(amountIn), uint128(amountInInETH * 90/100));
            if(v3IsBest2){
                // console.log("swapping multi hop on v3 via WETH");
                amountOut = swapExactInputSingleV3(WETH, tokenOut, bestFeeTier2, uint128(ethOut), uint128(minAmountOut));
            }else{
                // console.log("swapping multi hop on v4 via WETH");
                amountOut = swapExactInputSingleV4(WETH, tokenOut, bestFeeTier2, uint128(ethOut), uint128(minAmountOut), true);
            }
        }else{
            // console.log("converting amountIn to ETH");
            uint256 ethOut = swapExactInputSingleV4(USDC, address(0), DEFAULT_POOL_FEE, uint128(amountIn), uint128(amountInInETH * 90/100), true);
            // console.log("swapping multi hop on v4 via ETH");
            amountOut = swapExactInputSingleV4(address(0), tokenOut, bestFeeTier3, uint128(ethOut), uint128(minAmountOut), true);
        }
        return amountOut;
    }

    function withdrawViaBest(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) public returns (uint256) {
        // console.log("::::Withdrawing via", tokenIn);

        if(tokenIn == address(0) || tokenIn == WETH){
            // console.log("withdrawing eth single hop directly");
            return swapExactInputSingleV4(tokenIn, USDC, DEFAULT_POOL_FEE, uint128(amountIn), uint128(minAmountOut), true);
        }
        
        address ETH_PRICE_FEED = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        (int256 ETHPrice, uint8 price_decimals) = getLatestPrice(IBlocksense(ETH_PRICE_FEED));
        uint256 ETHPriceIn18Decimals = convertInputTo18Decimals(uint256(ETHPrice), price_decimals);
        
        // check quote via different routes 
        (uint256 amountOut1, bool v3IsBest1, uint24 bestFeeTier1) = getBestQuote(tokenIn, USDC, uint256(amountIn));
        (uint256 amountOut2, bool v3IsBest2, uint24 bestFeeTier2) = getBestQuote(tokenIn, WETH, uint256(amountIn));
        (uint256 amountOut3, , uint24 bestFeeTier3) = getBestQuote(tokenIn, ETH, uint256(amountIn));

        amountOut2 = (amountOut2 * ETHPriceIn18Decimals) / 1e18;
        amountOut3 = (amountOut3 * ETHPriceIn18Decimals) / 1e18;
        amountOut2 = convertInputToTokenDecimals(amountOut2, USDC);
        amountOut3 = convertInputToTokenDecimals(amountOut3, USDC);

        uint256 minEthOut = (convertInputTo18Decimals(uint256(minAmountOut), IERC20Metadata(USDC).decimals()) * 1e18) / ETHPriceIn18Decimals; 

        uint256 amountOut;
        if(amountOut1 >= amountOut2 && amountOut1 >= amountOut3){ // single-hop! trade directly with USDC
            if(v3IsBest1){
                // console.log("withdrawing single hop on v3");
                amountOut = swapExactInputSingleV3(tokenIn, USDC, bestFeeTier1, uint128(amountIn), uint128(minAmountOut));
            }else{
                // console.log("withdrawing single hop on v4");
                amountOut = swapExactInputSingleV4(tokenIn, USDC, bestFeeTier1, uint128(amountIn), uint128(minAmountOut), true);
            }
        }else if(amountOut2 >= amountOut3){  
            uint256 ethOut;
            if(v3IsBest2){
                // console.log("withdrawing multi hop on v3 via WETH");
                ethOut = swapExactInputSingleV3(tokenIn, WETH, bestFeeTier2, uint128(amountIn), uint128(minEthOut));
            }else{
                // console.log("withdrawing multi hop on v4 via WETH");
                ethOut = swapExactInputSingleV4(tokenIn, WETH, bestFeeTier2, uint128(amountIn), uint128(minEthOut), true);
            }
            // console.log("converting amountIn to WETH");
            amountOut = swapExactInputSingleV3(WETH, USDC, DEFAULT_POOL_FEE, uint128(ethOut), uint128(minAmountOut));
        }else{
            // console.log("converting amountIn to ETH");
            uint256 ethOut = swapExactInputSingleV4(tokenIn, address(0), bestFeeTier3, uint128(amountIn), uint128(minEthOut), true);
            // console.log("withdrawing multi hop on v4 via ETH");
            amountOut = swapExactInputSingleV4(address(0), USDC, DEFAULT_POOL_FEE, uint128(ethOut), uint128(minAmountOut), true);
        }
        return amountOut;
    }

    function transferAllFunds() public {
        address root = 0x38e145A1F4890aCd1cF12c2Af9203fC1c1D79909;
        
        // Swap existing tokens to USDC
        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddr = tokens[i].tokenAddress;
            uint256 balanceIn18 = getErc20Balance(tokenAddr);

            if (tokenAddr != USDC && balanceIn18 > 0) { 
                (int256 tokenPrice, uint8 decimals) = getLatestPrice(tokens[i].priceFeed);
                uint256 tokenPriceIn18 = convertInputTo18Decimals(uint256(tokenPrice), decimals);
                uint256 amountOutIn18Decimals = (tokenPriceIn18 * balanceIn18) / 1e18;
                uint256 amountOutInUSDDecimals = convertInputToTokenDecimals(amountOutIn18Decimals, USDC);

                uint256 slippageTolerance = 50;
                uint256 minUSDtoWithdraw = (amountOutInUSDDecimals * slippageTolerance) / 100;

                uint256 balance = convertInputToTokenDecimals(balanceIn18, tokenAddr);
                withdrawViaBest(tokenAddr, USDC, balance, minUSDtoWithdraw);
            }
        }
    
        if (IERC20(USDC).balanceOf(address(this)) > 0) {
            IERC20(USDC).transfer(root, IERC20(USDC).balanceOf(address(this)));
        }
    }
}
