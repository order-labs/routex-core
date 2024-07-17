import {
  Account,
  AccountAddress,
  Aptos,
  AptosConfig,
  Ed25519PrivateKey,
  InputGenerateTransactionPayloadData,
  Network,
} from "@aptos-labs/ts-sdk";
import { exec, execSync } from "child_process";
import dotenv from "dotenv";
import { Routex } from "./routex";
dotenv.config();

const config = new AptosConfig({
  network: Network.CUSTOM,
  fullnode: process.env.FULLNODE,
  faucet: process.env.FAUCET,
});

const aptos = new Aptos(config);

async function main() {
  console.log(`--------- routex demo --------`);

  // check chain status
  // const ledgerInfo = await aptos.getLedgerInfo();
  // console.dir({ ledgerInfo }, { depth: null });

  // init deployer account
  const deployerPrivateKeyHex = process.env.PRIVATE_KEY!;
  const deployerPrivateKeyBytes = Buffer.from(
    deployerPrivateKeyHex.slice(2),
    "hex",
  );
  const deployerPrivateKey = new Ed25519PrivateKey(deployerPrivateKeyBytes);
  const deployer = Account.fromPrivateKey({ privateKey: deployerPrivateKey });
  console.log(`Deployer account address: ${deployer.accountAddress}`);
  console.assert(
    deployer.accountAddress.toString() === process.env.SWAP_DEPLOYER!,
    "Deployer account address not match",
  );
  const routexAddress = deployer.accountAddress.toString();
  const userPrivateKeyHex = process.env.USER_PRIVATE_KEY!;
  const userPrivateKeyBytes = Buffer.from(
    userPrivateKeyHex.slice(2),
    "hex",
  );
  const userPrivateKey = new Ed25519PrivateKey(userPrivateKeyBytes);
  const user = Account.fromPrivateKey({ privateKey: userPrivateKey });
  console.log(`User account address: ${user.accountAddress}`);

  // init routex
  const routex = new Routex({
    routexAddress,
    aptos,
  });

  // get supported coins
  const coins = await routex.getCoins();
  console.dir({ coins }, { depth: null });
  // get supported swaps
  const swaps = await routex.getSwaps();
  console.dir({ swaps }, { depth: null });
  // get routing from BTC to USDT
  const btc = `${routexAddress}::TestCoinsV1::BTC`;
  const eth = `${routexAddress}::TestCoinsV1::ETH`;
  const usdt = `${routexAddress}::TestCoinsV1::USDT`;
  const usdc = `${routexAddress}::TestCoinsV1::USDC`;
  const rtx = `${routexAddress}::TestCoinsV1::RTX`;
  // // get token balance
  const btcBalance = await routex.getCoinBalance(btc, user.accountAddress.toString());
  const usdtBalance = await routex.getCoinBalance(usdt, user.accountAddress.toString());
  const notExistAddr = await routex.getCoinBalance(btc, "0x640811396f28b1b27e3b24674defd7d05e77874c949b9919b6281801ddd6952");
  const notExistCoinBalance = await routex.getCoinBalance(`${routexAddress}::TestCoinsV1::NOT_EXIST_COIN`, user.accountAddress.toString());
  console.dir({ btcBalance, notExistCoinBalance, notExistAddr, usdtBalance }, { depth: null });
  // get token from faucet
  await routex.requestToken(btc, user);
  const newBtcBalance = await routex.getCoinBalance(btc, user.accountAddress.toString());
  console.dir({ btcBalance, newBtcBalance }, { depth: null });
  // 0.1 BTC -> USDT
  const startTime = Date.now();
  // const routing = await routex.getRouting(btc, rtx, 10000n);
  const routing = await routex.getRouting(btc, usdt, 10000n);
  // const routing = await routex.getRouting(usdt, usdc, 10000000n);
  const endTime = Date.now();
  console.dir({ routing }, { depth: null });
  console.log(`Routing from BTC to USDT: ${endTime - startTime} ms`);
  // swap txn with routing data
  await routex.swapWithRouting(routing, user, 10);
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
