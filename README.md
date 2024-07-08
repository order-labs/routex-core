# RouteX

RouteX is the DEX aggregator that provides the best price for swapping tokens across multiple DEXes on Movement Network.

RouteX is now available on Movement Testnet.

Visit the dapp at [https://routex.io](https://routex.io).

Add custom network of Movement Testnet with the following settings:

```dotenv
FULLNODE=https://aptos.testnet.suzuka.movementlabs.xyz/v1
FAUCET=https://faucet.testnet.suzuka.movementlabs.xyz/
```

The module address is `0x034a6b320636cf204d0665a5cc5499fc56250ceaa90a766b843c532ba7ff284d`.

## Development

Run the following command to deploy your own contracts of RouteX on Movement Testnet.

```
bash deploy.sh
```

And it will update the `.env` file with the deployed contract addresses.
It also deploys two DEXes, four test tokens, and provides liquidity for the tokens.

Then you can try the demo by running the following command.

```
pnpm i
pnpm demo
```

The core logic of RouteX are:
- `Routex/sources/routex.move`: The main module of RouteX contracts.
- `src/routex.ts`: The router implementation of RouteX. It will be implemented in the backend with off-chain indexers to provide better performance in further versions.