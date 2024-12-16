## Instructions

Before running the contract, ensure the following dependencies are installed in your Foundry project:

1. Install **Uniswap V3 Core**:
```bash
forge install uniswap/v3-core
```
2. Install **Uniswap V3 Pheriphery**:
```bash
forge install uniswap/v3-periphery
```
3. Install **OpenZeppelin Contracts**:
```bash
forge install OpenZeppelin/openzeppelin-contracts
```

Make sure to also update your remappings.txt to include the following:

```bash
@uniswap/v3-periphery/=lib/v3-periphery/
@uniswap/v3-core/=lib/v3-core/
@openzeppelin/contracts=lib/openzeppelin-contracts/contracts
```

### .env file
Store your INFURA_KEY in .env file and load .env file
```bash
source .env
```

### Mainnet Fork
Run anvil with mainnet fork:
```bash
anvil --fork-url https://mainnet.infura.io/v3/$INFURA_KEY
```

### Tests
```bash
forge test --fork-url http://127.0.0.1:8545 --match-path test/UniswapV3.t.sol -vv
```