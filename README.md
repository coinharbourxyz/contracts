# coinharbour.xyz contracts

## Overview

This project utilizes Foundry for smart contract development and testing, with integration of Chainlink oracles and Uniswap V4. The setup allows for testing against a mainnet fork using Anvil.

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
   Install the necessary libraries:
   ```bash
   forge install uniswap/v3-core --no-commit
   forge install uniswap/v3-periphery --no-commit
   forge install uniswap/v2-core --no-commit
   forge install uniswap/universal-router --no-commit
   forge install OpenZeppelin/openzeppelin-contracts --no-commit
   forge install smartcontractkit/chainlink-brownie-contracts --no-commit
   ```

5. **Clean Up and Reinstall if Necessary**:
   If you encounter issues, you can remove and reinstall the Chainlink library:
   ```bash
   rm -rf lib/chainlink-brownie-contracts
   forge install smartcontractkit/chainlink-brownie-contracts --no-commit
   ```

## Running Tests and Scripts

1. **Start Anvil with Mainnet Fork**:
   ```bash
   anvil --fork-url https://mainnet.infura.io/v3/<your-infura-project-id>
   ```

2. **Compile Contracts**:
   For optimal compilation with IR-based optimization:
   ```bash
   forge compile --via-ir
   ```

3. **Run Tests**:
   Execute tests against the forked environment with verbose output:
   ```bash
   forge test --via-ir --fork-url http://localhost:8545 -vv
   ```

4. **Test Scripts**:
   Run test scripts against local fork:
   ```bash
   forge script script/Swap.s.sol --via-ir \
       --rpc-url http://localhost:8545 \
       --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
       --broadcast
   ```

5. **Deploy Contracts**:
   Deploy contracts against local fork:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

## Environment Variables

- **ETH_RPC_URL**:
   The URL of the Ethereum RPC node.
- **PRIVATE_KEY**:
   The private key of the account to use for deployment.
- **ETHERSCAN_API_KEY**:
   The API key for the Etherscan service.

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

This setup provides a robust environment for developing and testing smart contracts with Foundry, utilizing Chainlink oracles and Uniswap V4. Follow the steps above to ensure a smooth installation and testing process.