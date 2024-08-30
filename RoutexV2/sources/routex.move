module Routex::RoutexV2 {
    use std::signer;
    use std::string::String;
    use std::vector;
    use aptos_std::smart_table;
    use aptos_std::smart_table::SmartTable;
    use aptos_std::type_info::{type_name, struct_name, type_of};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::emit;
    use razor::RazorSwapPool;

    // routers
    const Razor: u16 = 1;

    // errors
    const ERR_INVALID_ROUTER: u64 = 1;
    const ERR_INSUFFICIENT_OUTPUT_AMOUNT: u64 = 2;

    #[event]
    struct SwapEvent has drop, store {
        sender: address,
        routers: vector<u16>,
        coin_types: vector<String>,
        amounts: vector<u64>,
    }

    struct RoutexStore has key, store {
        btc_users: SmartTable<address, bool>,
        usdt_users: SmartTable<address, bool>,
        rtx_users: SmartTable<address, bool>,
        move_users: SmartTable<address, bool>,
    }

    fun init_module(account: &signer) {
        let store = RoutexStore {
            btc_users: smart_table::new(),
            usdt_users: smart_table::new(),
            rtx_users: smart_table::new(),
            move_users: smart_table::new(),
        };
        move_to(account, store);
    }

    fun record_user<T>(account: address) acquires RoutexStore {
        let store = borrow_global_mut<RoutexStore>(@Routex);
        let token_struct_name = struct_name(&type_of<T>());
        if (token_struct_name == b"BTC") {
            smart_table::upsert(&mut store.btc_users, account, true)
        } else if (token_struct_name == b"USDT") {
            smart_table::upsert(&mut store.usdt_users, account, true)
        } else if (token_struct_name == b"RTX") {
            smart_table::upsert(&mut store.rtx_users, account, true)
        } else if (token_struct_name == b"AptosCoin") {
            smart_table::upsert(&mut store.move_users, account, true)
        }
    }

    #[view]
    public fun check_user_record(account: address, token: vector<u8>): bool acquires RoutexStore {
        let store = borrow_global<RoutexStore>(@Routex);
        if (token == b"BTC") {
            *smart_table::borrow_with_default(&store.btc_users, account, &false)
        } else if (token == b"USDT") {
            *smart_table::borrow_with_default(&store.usdt_users, account, &false)
        } else if (token == b"RTX") {
            *smart_table::borrow_with_default(&store.rtx_users, account, &false)
        } else if (token == b"MOVE") {
            *smart_table::borrow_with_default(&store.move_users, account, &false)
        } else {
            false
        }
    }

    #[view]
    public fun get_amounts_out<X, Y>(
        router: u16,
        amount_in: u64,
    ): u64 {
        if (router == Razor) {
            RazorSwapPool::get_amounts_out_1_pair<X, Y>(amount_in)
        } else {
            abort ERR_INVALID_ROUTER
        }
    }

    public fun swap_coins_for_coins<X, Y>(
        router: u16,
        coins_in: Coin<X>,
    ): Coin<Y> {
        if (router == Razor) {
            RazorSwapPool::swap_coins_for_coins<X, Y>(coins_in)
        } else {
            abort ERR_INVALID_ROUTER
        }
    }

    public entry fun swap_exact_coins_for_coins_entry<X, Y>(
        account: &signer,
        routers: vector<u16>,
        amount_in: u64,
        amount_out_min: u64,
    ) acquires RoutexStore {
        assert!(vector::length(&routers) == 1, ERR_INVALID_ROUTER);
        let coins_in = coin::withdraw<X>(account, amount_in);
        let coins_out;
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, amount_in);
        let router = *vector::borrow(&routers, 0);
        coins_out = swap_coins_for_coins<X, Y>(router, coins_in);
        vector::push_back(&mut amounts, coin::value(&coins_out));
        assert!(coin::value(&coins_out) >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        register_coin<Y>(account);
        coin::deposit<Y>(signer::address_of(account), coins_out);
        let coin_types = vector::empty<String>();
        vector::push_back(&mut coin_types, type_name<X>());
        vector::push_back(&mut coin_types, type_name<Y>());
        let event = SwapEvent {
            sender: signer::address_of(account),
            routers,
            coin_types,
            amounts,
        };
        emit(event);
        record_user<X>(signer::address_of(account));
    }

    public entry fun swap_exact_coins_for_coins_2_pair_entry<X, Y, Z>(
        account: &signer,
        routers: vector<u16>,
        amount_in: u64,
        amount_out_min: u64,
    ) acquires RoutexStore {
        assert!(vector::length(&routers) == 2, ERR_INVALID_ROUTER);
        let coins_in = coin::withdraw<X>(account, amount_in);
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, amount_in);
        let coins_out;
        let coins_mid;
        coins_mid = swap_coins_for_coins<X, Y>(*vector::borrow(&routers, 0), coins_in);
        vector::push_back(&mut amounts, coin::value(&coins_mid));
        coins_out = swap_coins_for_coins<Y, Z>(*vector::borrow(&routers, 1), coins_mid);
        vector::push_back(&mut amounts, coin::value(&coins_out));
        assert!(coin::value(&coins_out) >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        register_coin<Z>(account);
        coin::deposit<Z>(signer::address_of(account), coins_out);
        let coin_types = vector::empty<String>();
        vector::push_back(&mut coin_types, type_name<X>());
        vector::push_back(&mut coin_types, type_name<Y>());
        vector::push_back(&mut coin_types, type_name<Z>());
        let event = SwapEvent {
            sender: signer::address_of(account),
            routers,
            coin_types,
            amounts,
        };
        emit(event);
        record_user<X>(signer::address_of(account));
    }

    public entry fun swap_exact_coins_for_coins_3_pair_entry<X, Y, Z, W>(
        account: &signer,
        routers: vector<u16>,
        amount_in: u64,
        amount_out_min: u64,
    ) acquires RoutexStore {
        assert!(vector::length(&routers) == 3, ERR_INVALID_ROUTER);
        let coins_in = coin::withdraw<X>(account, amount_in);
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, amount_in);
        let coins_out;
        let coins_mid;
        let coins_mid2;
        coins_mid = swap_coins_for_coins<X, Y>(*vector::borrow(&routers, 0), coins_in);
        vector::push_back(&mut amounts, coin::value(&coins_mid));
        coins_mid2 = swap_coins_for_coins<Y, Z>(*vector::borrow(&routers, 1), coins_mid);
        vector::push_back(&mut amounts, coin::value(&coins_mid2));
        coins_out = swap_coins_for_coins<Z, W>(*vector::borrow(&routers, 2), coins_mid2);
        vector::push_back(&mut amounts, coin::value(&coins_out));
        assert!(coin::value(&coins_out) >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        register_coin<W>(account);
        coin::deposit<W>(signer::address_of(account), coins_out);
        let coin_types = vector::empty<String>();
        vector::push_back(&mut coin_types, type_name<X>());
        vector::push_back(&mut coin_types, type_name<Y>());
        vector::push_back(&mut coin_types, type_name<Z>());
        vector::push_back(&mut coin_types, type_name<W>());
        let event = SwapEvent {
            sender: signer::address_of(account),
            routers,
            coin_types,
            amounts,
        };
        emit(event);
        record_user<X>(signer::address_of(account));
    }

    // register coin if not registered
    public fun register_coin<CoinType>(
        account: &signer
    ) {
        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<CoinType>(account_addr)) {
            coin::register<CoinType>(account);
        };
    }
}
