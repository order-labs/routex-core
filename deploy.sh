#!/bin/sh

set -x

# FULLNODE="http://127.0.0.1:8080"
# FAUCET="http://127.0.0.1:8081"
#FULLNODE="https://fullnode.devnet.aptoslabs.com/v1"
#FAUCET="https://faucet.devnet.aptoslabs.com"
FULLNODE="https://aptos.testnet.suzuka.movementlabs.xyz/v1"
FAUCET="https://faucet.testnet.suzuka.movementlabs.xyz/"
PATH_TO_REPO="."

# Initializes an account if keys are not present
#initialize_output=$(echo -ne '\n' | aptos init --network devnet --assume-yes)
initialize_output=$(echo -ne '\n' | aptos init --network custom --rest-url $FULLNODE --faucet-url $FAUCET --assume-yes)

CONFIG_FILE=".aptos/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Initialization failed. Config file not found."
  exit 1
fi

PrivateKey=$(grep 'private_key:' "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d '"')

# Lookup the SwapDeployer address
lookup_address_output=$(aptos account lookup-address)
echo "Lookup Address Output: $lookup_address_output"
SwapDeployer=0x$(echo "$lookup_address_output" | grep -o '"Result": "[0-9a-fA-F]\{64\}"' | sed 's/"Result": "\(.*\)"/\1/')
if [ -z "$SwapDeployer" ]; then
  echo "SwapDeployer extraction failed."
  exit 1
fi

# Lookup the ResourceAccountDeployer address test IS expected to fail as long as we can retrieve the account address anyway
 test_resource_account_output=$(aptos move test --package-dir "$PATH_TO_REPO/Swap/" \
--filter test_resource_account --named-addresses SwapDeployer=$SwapDeployer,uq64x64=$SwapDeployer,u256=$SwapDeployer,ResourceAccountDeployer=$SwapDeployer,ResourceAccountDeployer2=$SwapDeployer)
echo "Test Resource Account Output: $test_resource_account_output"
ResourceAccountDeployer=$(echo "$test_resource_account_output" | grep -o '\[debug\] @[^\s]*' | sed 's/\[debug\] @\(.*\)/\1/')
if [ -z "$ResourceAccountDeployer" ]; then
  echo "ResourceAccountDeployer extraction failed."
  exit 1
fi
 test_resource_account_output=$(aptos move test --package-dir "$PATH_TO_REPO/Swap/" \
--filter test_resource2_account --named-addresses SwapDeployer=$SwapDeployer,uq64x64=$SwapDeployer,u256=$SwapDeployer,ResourceAccountDeployer=$SwapDeployer,ResourceAccountDeployer2=$SwapDeployer)
echo "Test Resource Account 2 Output: $test_resource_account_output"
ResourceAccountDeployer2=$(echo "$test_resource_account_output" | grep -o '\[debug\] @[^\s]*' | sed 's/\[debug\] @\(.*\)/\1/')
if [ -z "$ResourceAccountDeployer2" ]; then
  echo "ResourceAccountDeployer2 extraction failed."
  exit 1
fi

# Save variable to .env file for SDK tests
FILE_TO_BACKUP=".env"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_FILE="${FILE_TO_BACKUP}_backup_${TIMESTAMP}"
mv "$FILE_TO_BACKUP" "$BACKUP_FILE"
add_or_update_env() {
    local key=$1
    local value=$2
    local file=".env"
    echo "$key=$value" >> "$file"
}

add_or_update_env "SWAP_DEPLOYER" $SwapDeployer
add_or_update_env "RESOURCE_ACCOUNT_DEPLOYER" $ResourceAccountDeployer
add_or_update_env "RESOURCE_ACCOUNT_DEPLOYER2" $ResourceAccountDeployer2
add_or_update_env "PRIVATE_KEY" $PrivateKey
add_or_update_env "USER_PRIVATE_KEY" $PrivateKey
add_or_update_env "FULLNODE" $FULLNODE
add_or_update_env "FAUCET" $FAUCET

# publish
echo "Publish uq64x64"
aptos move publish --package-dir $PATH_TO_REPO/uq64x64/ --assume-yes --named-addresses uq64x64=$SwapDeployer
echo "Publish u256"
aptos move publish --package-dir $PATH_TO_REPO/u256/ --assume-yes --named-addresses u256=$SwapDeployer
echo "Publish TestCoin"
aptos move publish --package-dir $PATH_TO_REPO/TestCoin/ --assume-yes --named-addresses SwapDeployer=$SwapDeployer
echo "Publish Faucet"
aptos move publish --package-dir $PATH_TO_REPO/Faucet/ --assume-yes --named-addresses SwapDeployer=$SwapDeployer
echo "Publish Resource Account"
aptos move publish --package-dir $PATH_TO_REPO/LPResourceAccount/ --assume-yes --named-addresses SwapDeployer=$SwapDeployer
# create resource account & publish LPCoin
# use this command to compile LPCoin
aptos move compile --package-dir $PATH_TO_REPO/LPCoin/ --save-metadata --named-addresses ResourceAccountDeployer=$ResourceAccountDeployer
# get the first arg
arg1=$(hexdump -ve '1/1 "%02x"' $PATH_TO_REPO/LPCoin/build/LPCoin/package-metadata.bcs)
# get the second arg
arg2=$(hexdump -ve '1/1 "%02x"' $PATH_TO_REPO/LPCoin/build/LPCoin/bytecode_modules/LPCoinV1.mv)
# This command is to publish LPCoin contract, using ResourceAccountDeployer address. Note: replace two args with the above two hex
echo "Initialize LPAccount"
aptos move run --function-id ${SwapDeployer}::LPResourceAccount::initialize_lp_account \
--args hex:$arg1 hex:$arg2 --assume-yes
# init LPCOIN2
aptos move compile --package-dir $PATH_TO_REPO/LPCoin2/ --save-metadata --named-addresses ResourceAccountDeployer2=$ResourceAccountDeployer2
# get the first arg
arg1=$(hexdump -ve '1/1 "%02x"' $PATH_TO_REPO/LPCoin2/build/LPCoin2/package-metadata.bcs)
# get the second arg
arg2=$(hexdump -ve '1/1 "%02x"' $PATH_TO_REPO/LPCoin2/build/LPCoin2/bytecode_modules/LPCoinV2.mv)
# This command is to publish LPCoin contract, using ResourceAccountDeployer address. Note: replace two args with the above two hex
echo "Initialize LPAccount"
aptos move run --function-id ${SwapDeployer}::LPResourceAccount::initialize_lp_account2 \
--args hex:$arg1 hex:$arg2 --assume-yes

echo "Publishing MovementSwap"
aptos move publish --package-dir $PATH_TO_REPO/Swap/ --assume-yes --named-addresses uq64x64=$SwapDeployer,u256=$SwapDeployer,SwapDeployer=$SwapDeployer,ResourceAccountDeployer=$ResourceAccountDeployer,ResourceAccountDeployer2=$ResourceAccountDeployer2

echo "publishing RouteX"
aptos move publish --package-dir $PATH_TO_REPO/Routex/ --assume-yes --named-addresses uq64x64=$SwapDeployer,u256=$SwapDeployer,SwapDeployer=$SwapDeployer,ResourceAccountDeployer=$ResourceAccountDeployer,ResourceAccountDeployer2=$ResourceAccountDeployer2,Routex=$SwapDeployer

# TestCoinsV1
echo "Initialize TestCoinsV1"
aptos move run --function-id ${SwapDeployer}::TestCoinsV1::initialize --assume-yes
echo "Mint USDT TestCoinsV1"
# mint 2 Billion tokens
aptos move run --function-id ${SwapDeployer}::TestCoinsV1::mint_coin \
--args address:${SwapDeployer} u64:200000000000000000 \
--type-args ${SwapDeployer}::TestCoinsV1::USDT --assume-yes
aptos move run --function-id ${SwapDeployer}::TestCoinsV1::mint_coin \
--args address:${SwapDeployer} u64:200000000000000000 \
--type-args ${SwapDeployer}::TestCoinsV1::USDC --assume-yes
echo "Mint BTC TestCoinsV1"
aptos move run --function-id ${SwapDeployer}::TestCoinsV1::mint_coin \
--args address:${SwapDeployer} u64:200000000000000000 \
--type-args ${SwapDeployer}::TestCoinsV1::BTC --assume-yes
aptos move run --function-id ${SwapDeployer}::TestCoinsV1::mint_coin \
--args address:${SwapDeployer} u64:200000000000000000 \
--type-args ${SwapDeployer}::TestCoinsV1::ETH --assume-yes

# AnimeSwapPool
# RouteSwap1
echo "add BTC:USDT pair, 100 BTC, price 70000"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV1::add_liquidity_entry \
--args u64:10000000000 u64:700000000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::BTC ${SwapDeployer}::TestCoinsV1::USDT --assume-yes
echo "add BTC:USDC pair, 100 BTC, price 72000"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV1::add_liquidity_entry \
--args u64:10000000000 u64:720000000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::BTC ${SwapDeployer}::TestCoinsV1::USDC --assume-yes
echo "add BTC:ETH pair, 100 BTC, price 23"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV1::add_liquidity_entry \
--args u64:10000000000 u64:230000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::BTC ${SwapDeployer}::TestCoinsV1::ETH --assume-yes
echo "add ETH:USDT pair, 100 ETH, price 3000"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV1::add_liquidity_entry \
--args u64:10000000000 u64:30000000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::ETH ${SwapDeployer}::TestCoinsV1::USDT --assume-yes
echo "add ETH:USDC pair, 100 ETH, price 2800"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV1::add_liquidity_entry \
--args u64:10000000000 u64:28000000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::ETH ${SwapDeployer}::TestCoinsV1::USDC --assume-yes
echo "add USDC:USDT pair, 100 USDC, price 1"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV1::add_liquidity_entry \
--args u64:10000000000 u64:10000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::USDC ${SwapDeployer}::TestCoinsV1::USDT --assume-yes
# RouteSwap2
echo "add BTC:USDT pair, 1 BTC, price 71000"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV2::add_liquidity_entry \
--args u64:100000000 u64:7100000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::BTC ${SwapDeployer}::TestCoinsV1::USDT --assume-yes
echo "add BTC:USDC pair, 1 BTC, price 70000"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV2::add_liquidity_entry \
--args u64:100000000 u64:7000000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::BTC ${SwapDeployer}::TestCoinsV1::USDC --assume-yes
echo "add BTC:ETH pair, 1 BTC, price 24"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV2::add_liquidity_entry \
--args u64:100000000 u64:2400000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::BTC ${SwapDeployer}::TestCoinsV1::ETH --assume-yes
echo "add ETH:USDT pair, 1 ETH, price 2900"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV2::add_liquidity_entry \
--args u64:100000000 u64:290000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::ETH ${SwapDeployer}::TestCoinsV1::USDT --assume-yes
echo "add ETH:USDC pair, 1 ETH, price 3300"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV2::add_liquidity_entry \
--args u64:100000000 u64:330000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::ETH ${SwapDeployer}::TestCoinsV1::USDC --assume-yes
echo "add USDC:USDT pair, 10000 USDC, price 1.1"
aptos move run --function-id ${SwapDeployer}::AnimeSwapPoolV2::add_liquidity_entry \
--args u64:1000000000000 u64:1100000000000 u64:1 u64:1 \
--type-args ${SwapDeployer}::TestCoinsV1::USDC ${SwapDeployer}::TestCoinsV1::USDT --assume-yes

# FaucetV1
echo "Create USDT FaucetV1"
aptos move run --function-id ${SwapDeployer}::FaucetV1::create_faucet \
--args u64:10000000000000000 u64:1000000000 u64:3600 \
--type-args ${SwapDeployer}::TestCoinsV1::USDT --assume-yes
aptos move run --function-id ${SwapDeployer}::FaucetV1::create_faucet \
--args u64:10000000000000000 u64:1000000000 u64:3600 \
--type-args ${SwapDeployer}::TestCoinsV1::USDC --assume-yes
echo "Create BTC FaucetV1"
aptos move run --function-id ${SwapDeployer}::FaucetV1::create_faucet \
--args u64:1000000000000 u64:10000000 u64:3600 \
--type-args ${SwapDeployer}::TestCoinsV1::BTC --assume-yes
aptos move run --function-id ${SwapDeployer}::FaucetV1::create_faucet \
--args u64:1000000000000 u64:10000000 u64:3600 \
--type-args ${SwapDeployer}::TestCoinsV1::ETH --assume-yes
