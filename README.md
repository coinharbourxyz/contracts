# coinharbour.xyz contracts

## Overview

This project utilizes Foundry for smart contract development and testing, with integration of Chainlink oracles and Uniswap V3. The setup allows for testing against a mainnet fork using Anvil.

## Prerequisites

- Ensure you have a Unix-based operating system (Linux or macOS).
- Install [Zsh](https://www.zsh.org/) because I use it.

## Installation Steps

1. **Install Foundry**:
   Open your terminal and run the following command to install Foundry:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   ```

2. **Set Up Environment**:
   After installation, source your environment:
   ```bash
   source /home/shubham/.zshenv
   exec zsh
   ```

3. **Update Foundry**:
   Ensure you have the latest version of Foundry:
   ```bash
   foundryup
   ```

4. **Install Dependencies**:
   Install the necessary libraries for Uniswap and Chainlink:
   ```bash
   forge install uniswap/v3-core
   forge install uniswap/v3-periphery
   forge install OpenZeppelin/openzeppelin-contracts
   forge install smartcontractkit/chainlink-brownie-contracts --no-commit
   ```

5. **Clean Up and Reinstall if Necessary**:
   If you encounter issues, you can remove and reinstall the Chainlink library:
   ```bash
   rm -rf lib/chainlink-brownie-contracts
   forge install smartcontractkit/chainlink-brownie-contracts --no-commit
   ```

## Running the Mainnet Fork

1. **Start Anvil**: Get your infura project id from [here](https://app.infura.io/)
   To run a local Ethereum node that forks the mainnet, use the following command:
   ```bash
   anvil --fork-url https://mainnet.infura.io/v3/<your-infura-project-id>
   ```

2. **Fetch Price Data**:
   To validate that you are receiving Chainlink data, run the following script:
   ```bash
   forge script script/FetchPrice.s.sol --fork-url http://localhost:8545 --broadcast
   ```


3. **Run Tests**:
   Execute your tests against the local fork:
   ```bash
   forge test --fork-url http://127.0.0.1:8545 --match-path test/UniswapV3.t.sol -vv
   ```


## Additional Commands

- **Build Contracts**:
   To compile your contracts, use:
   ```bash
   forge build
   ```

- **Run Tests Verbosely**:
   For detailed test output, run:
   ```bash
   forge test -vv
   ```

- **View Remappings**:
   To check your remappings, use:
   ```bash
   forge remappings
   ```

## Conclusion

This setup provides a robust environment for developing and testing smart contracts with Foundry, utilizing Chainlink oracles and Uniswap V3. Follow the steps above to ensure a smooth installation and testing process.