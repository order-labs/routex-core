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
import axios from "axios";
import dotenv from "dotenv";
import { Routex } from "./routex";
dotenv.config();

const ENDPOINT = "https://aptos.testnet.suzuka.movementlabs.xyz/v1";
const ROUTEX_ADDR =
  "0xc54fea735a2ad200c712d193a42cd7d575baf7a64487479d4cc71bb47d41a988";

async function galxeTasks(address: string) {
  let btcFaucetTaskFinished = false;
  let swapBtcTaskFinished = false;
  let swapUsdtTaskFinished = false;
  // check btc faucet task
  try {
    const btcRaucetTaskRes = await axios.get(
      `${ENDPOINT}/accounts/${address}/resource/0x1::coin::CoinStore<${ROUTEX_ADDR}::TestCoinsV1::BTC>`,
    );
    console.dir({ data: btcRaucetTaskRes.data }, { depth: null });
    btcFaucetTaskFinished = btcRaucetTaskRes.data.data !== undefined;
  } catch (error) {
    console.error("error", (error as any).response.status);
    // console.dir({ error }, { depth: null })
  }
  // check swap btc task
  const swapBtcTaskRes = await axios.post(`${ENDPOINT}/view`, {
    "function": `${ROUTEX_ADDR}::RoutexV1::check_user_record`,
    "type_arguments": [],
    "arguments": [
      address,
      "425443",
    ],
  });
  console.dir({ data: swapBtcTaskRes.data }, { depth: null });
  swapBtcTaskFinished = swapBtcTaskRes.data[0];
  // check swap usdt task
  const swapUsdtTaskRes = await axios.post(`${ENDPOINT}/view`, {
    "function": `${ROUTEX_ADDR}::RoutexV1::check_user_record`,
    "type_arguments": [],
    "arguments": [
      address,
      "55534454",
    ],
  });
  console.dir({ data: swapUsdtTaskRes.data }, { depth: null });
  swapUsdtTaskFinished = swapUsdtTaskRes.data[0];
  return {
    btcFaucetTaskFinished,
    swapBtcTaskFinished,
    swapUsdtTaskFinished,
  };
}

async function main() {
  console.log(`--------- evetns demo --------`);
  const addr = '0xac6032d57e18604bcfa0717c07723de7ba3a4fb1dd3850aa612edfaa1b7617c0';
  // const addr = "0xac6032d57e18604bcfa0717c07723de7ba3a4fb1dd3850aa612edfaa1b7617c1";
  const result = await galxeTasks(addr);
  console.dir({ result }, { depth: null });
}

main();
