import {
  Account,
  AccountAddress,
  Aptos,
  MoveVector,
  U16,
  U64,
  U8,
} from "@aptos-labs/ts-sdk";
import { sign } from "crypto";

export interface InternalCoin {
  type_: string;
  amount: bigint;
  routers: Router[];
}

export interface InternalCoins {
  [key: string]: InternalCoin;
}

export interface RoutexBuilder {
  routexAddress: string;
  aptos: Aptos;
}

export interface Coin {
  symbol: string;
  logo: string;
  type_: string;
  decimal: number;
}

export interface Router {
  from: string;
  to: string;
  name: string;
  swap_id: number;
  logo: string;
}

export interface Routing {
  from: string;
  to: string;
  routers: Router[];
  amount_in: bigint;
  amount_out: bigint;
}

export interface Graph {
  [key: string]: Router[];
}

export interface Swap {
  id: number;
  name: string;
  logo: string;
}

export interface Swaps {
  [key: number]: Swap;
}

export const MAX_HOPS = 3;

export class Routex {
  readonly routexAddress: string;
  aptos: Aptos;
  coins: Coin[];
  graph: Graph;
  swaps: Swaps;

  constructor(builder: RoutexBuilder) {
    this.routexAddress = builder.routexAddress;
    this.aptos = builder.aptos;
    this.coins = [
      {
        symbol: "BTC",
        logo: "https://cryptologos.cc/logos/bitcoin-btc-logo.png",
        type_: `${this.routexAddress}::TestCoinsV1::BTC`,
        decimal: 8,
      },
      {
        symbol: "ETH",
        logo: "https://cryptologos.cc/logos/ethereum-eth-logo.png",
        type_: `${this.routexAddress}::TestCoinsV1::ETH`,
        decimal: 8,
      },
      {
        symbol: "USDT",
        logo: "https://cryptologos.cc/logos/tether-usdt-logo.png",
        type_: `${this.routexAddress}::TestCoinsV1::USDT`,
        decimal: 8,
      },
      {
        symbol: "USDC",
        logo: "https://cryptologos.cc/logos/usd-coin-usdc-logo.png",
        type_: `${this.routexAddress}::TestCoinsV1::USDC`,
        decimal: 8,
      },
    ];
    this.swaps = {
      1: {
        id: 1,
        name: "RoutexSwapV1",
        logo: "https://i.imgur.com/RA34xI4.png",
      },
      2: {
        id: 2,
        name: "RoutexSwapV2",
        logo: "https://i.imgur.com/XgzHTMQ.png",
      },
    };
    // construct the graph
    const coinLength = this.coins.length;
    this.graph = {};
    for (let i = 0; i < coinLength; i++) {
      this.graph[this.coins[i].type_] = [];
      for (let j = 0; j < coinLength; j++) {
        if (i === j) {
          continue;
        }
        for (let swap of Object.values(this.swaps)) {
          this.graph[this.coins[i].type_].push({
            from: this.coins[i].type_,
            to: this.coins[j].type_,
            name: swap.name,
            swap_id: swap.id,
            logo: swap.logo,
          });
        }
      }
    }
    // console.dir({ graph: this.graph }, { depth: null })
  }

  // get all supported coins
  getCoins(): Coin[] {
    return this.coins;
  }

  getSwaps(): Swaps {
    return this.swaps;
  }

  async getCoinOut(
    coinIn: InternalCoin,
    router: Router,
  ): Promise<InternalCoin> {
    if (coinIn.type_ !== router.from) {
      throw new Error(
        `coinIn.type_ ${coinIn.type_} is not equal to router.from ${router.from}`,
      );
    }
    const res = await this.aptos.view({
      payload: {
        function: `${this.routexAddress}::RoutexV1::get_amounts_out`,
        functionArguments: [router.swap_id, coinIn.amount],
        typeArguments: [router.from, router.to],
      },
    });
    // console.dir({ res, coinIn, router }, { depth: null })
    return {
      type_: router.to,
      amount: BigInt(parseInt(res[0] as string)),
      routers: [...coinIn.routers, router],
    };
  }

  async getCoinsOut(coinIn: InternalCoin): Promise<InternalCoin[]> {
    if (this.graph[coinIn.type_] === undefined) {
      return [];
    }
    let coinsOut: InternalCoin[] = [];
    const promises = this.graph[coinIn.type_].map((router) =>
      this.getCoinOut(coinIn, router)
    );
    coinsOut = await Promise.all(promises);
    return coinsOut;
  }

  async getCoinBalance(
    coinType: string,
    accountAddress: string,
  ): Promise<bigint> {
    console.dir({ coinType, accountAddress }, { depth: null });
    try {
      const res = await this.aptos.view({
        payload: {
          function: `0x1::coin::balance`,
          functionArguments: [accountAddress],
          typeArguments: [coinType],
        },
      });
      console.dir({ res }, { depth: null });
      return BigInt(parseInt(res[0] as string));
    } catch (e) {
      console.log(`error: ${e}`);
      return BigInt(0);
    }
  }

  async requestToken(
    tokenType: string,
    signer: Account,
  ) {
    const res = await this.aptos.transaction.build.simple({
      sender: signer.accountAddress,
      data: {
        function: `${this.routexAddress}::FaucetV1::request`,
        functionArguments: [this.routexAddress],
        typeArguments: [tokenType],
      },
    });
    const committedTransaction = await this.aptos.signAndSubmitTransaction({
      signer,
      transaction: res,
    });
    console.log(`Transaction hash: ${committedTransaction.hash}`);
  }

  // get routing
  async getRouting(
    from: string,
    to: string,
    amount: bigint,
    maxHops: number = MAX_HOPS,
  ): Promise<Routing> {
    if (this.graph[from] === undefined) {
      throw new Error(`cannot find route from ${from} to ${to}`);
    }
    let internalCoins: InternalCoins = {};
    internalCoins[from] = {
      type_: from,
      amount,
      routers: [],
    };
    let updatedCoins = [from];
    for (let i = 0; i < maxHops; i++) {
      // console.log(`round ${i}`);
      let allCoinsOut: InternalCoin[] = [];
      for (let updatedCoin of updatedCoins) {
        let coinsOut = await this.getCoinsOut(internalCoins[updatedCoin]);
        // console.dir({ updatedCoin, coinsOut }, { depth: null })
        allCoinsOut = allCoinsOut.concat(coinsOut);
      }
      let newUpdatedCoins = new Set<string>();
      for (let coinOut of allCoinsOut) {
        if (
          internalCoins[coinOut.type_] === undefined ||
          internalCoins[coinOut.type_].amount < coinOut.amount
        ) {
          internalCoins[coinOut.type_] = coinOut;
          newUpdatedCoins.add(coinOut.type_);
        }
      }
      updatedCoins = Array.from(newUpdatedCoins);
      // console.dir({ internalCoins, updatedCoins }, { depth: null })
    }
    if (internalCoins[to] === undefined) {
      throw new Error(`cannot find route from ${from} to ${to}`);
    }
    return {
      from,
      to,
      routers: internalCoins[to].routers,
      amount_in: amount,
      amount_out: internalCoins[to].amount,
    };
  }

  // send txn with routing
  // maxSlippage: 5 means 0.5%
  async swapWithRouting(
    routing: Routing,
    signer: Account,
    maxSlippage: number = 10,
  ): Promise<void> {
    const routerLength = routing.routers.length;
    let functionName;
    if (routerLength === 1) {
      functionName =
        `${this.routexAddress}::RoutexV1::swap_exact_coins_for_coins_entry`;
    } else if (routerLength === 2) {
      functionName =
        `${this.routexAddress}::RoutexV1::swap_exact_coins_for_coins_2_pair_entry`;
    } else if (routerLength === 3) {
      functionName =
        `${this.routexAddress}::RoutexV1::swap_exact_coins_for_coins_3_pair_entry`;
    } else {
      throw new Error(`unsupported router length ${routerLength}`);
    }
    const routers = routing.routers.map((router) => router.swap_id);
    const amountOutMin = routing.amount_out * (1000n - BigInt(maxSlippage)) /
      1000n;
    const data = {
      function: functionName as any,
      functionArguments: [
        routers,
        routing.amount_in,
        amountOutMin,
      ],
      typeArguments: [
        routing.from,
        ...routing.routers.map((router) => router.to),
      ],
    };
    console.dir({ data }, { depth: null });
    const res = await this.aptos.transaction.build.simple({
      sender: signer.accountAddress,
      data,
    });
    const committedTransaction = await this.aptos.signAndSubmitTransaction({
      signer,
      transaction: res,
    });
    console.log(`Transaction hash: ${committedTransaction.hash}`);
  }
}
