module Routex::RoutexV1 {
    use std::signer;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    use SwapDeployer::AnimeSwapPoolV1Library;
    use SwapDeployer::AnimeSwapPoolV1;
    use SwapDeployer::AnimeSwapPoolV2;

    // routers
    const RoutexSwapV1: u16 = 1;
    const RoutexSwapV2: u16 = 2;

    // errors
    const ERR_INVALID_ROUTER: u64 = 1;
    const ERR_INSUFFICIENT_OUTPUT_AMOUNT: u64 = 2;

    #[view]
    public fun get_amounts_out<X, Y>(
        router: u16,
        amount_in: u64,
    ): u64 {
        if (router == RoutexSwapV1) {
            AnimeSwapPoolV1::get_amounts_out_1_pair<X, Y>(amount_in)
        } else if (router == RoutexSwapV2) {
            AnimeSwapPoolV2::get_amounts_out_1_pair<X, Y>(amount_in)
        } else {
            abort ERR_INVALID_ROUTER
        }
    }

    public fun swap_coins_for_coins<X, Y>(
        router: u16,
        coins_in: Coin<X>,
    ): Coin<Y> {
        if (router == RoutexSwapV1) {
            AnimeSwapPoolV1::swap_coins_for_coins<X, Y>(coins_in)
        } else if (router == RoutexSwapV2) {
            AnimeSwapPoolV2::swap_coins_for_coins<X, Y>(coins_in)
        } else {
            abort ERR_INVALID_ROUTER
        }
    }

    public entry fun swap_exact_coins_for_coins_entry<X, Y>(
        account: &signer,
        routers: vector<u16>,
        amount_in: u64,
        amount_out_min: u64,
    ) {
        assert!(vector::length(&routers) == 1, ERR_INVALID_ROUTER);
        let coins_in = coin::withdraw<X>(account, amount_in);
        let coins_out;
        let router = *vector::borrow(&routers, 0);
        coins_out = swap_coins_for_coins<X, Y>(router, coins_in);
        assert!(coin::value(&coins_out) >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        AnimeSwapPoolV1Library::register_coin<Y>(account);
        coin::deposit<Y>(signer::address_of(account), coins_out);
    }

    public entry fun swap_exact_coins_for_coins_2_pair_entry<X, Y, Z>(
        account: &signer,
        routers: vector<u16>,
        amount_in: u64,
        amount_out_min: u64,
    ) {
        assert!(vector::length(&routers) == 2, ERR_INVALID_ROUTER);
        let coins_in = coin::withdraw<X>(account, amount_in);
        let coins_out;
        let coins_mid;
        coins_mid = swap_coins_for_coins<X, Y>(*vector::borrow(&routers, 0), coins_in);
        coins_out = swap_coins_for_coins<Y, Z>(*vector::borrow(&routers, 1), coins_mid);
        assert!(coin::value(&coins_out) >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        AnimeSwapPoolV1Library::register_coin<Z>(account);
        coin::deposit<Z>(signer::address_of(account), coins_out);
    }

    public entry fun swap_exact_coins_for_coins_3_pair_entry<X, Y, Z, W>(
        account: &signer,
        routers: vector<u16>,
        amount_in: u64,
        amount_out_min: u64,
    ) {
        assert!(vector::length(&routers) == 3, ERR_INVALID_ROUTER);
        let coins_in = coin::withdraw<X>(account, amount_in);
        let coins_out;
        let coins_mid;
        let coins_mid2;
        coins_mid = swap_coins_for_coins<X, Y>(*vector::borrow(&routers, 0), coins_in);
        coins_mid2 = swap_coins_for_coins<Y, Z>(*vector::borrow(&routers, 1), coins_mid);
        coins_out = swap_coins_for_coins<Z, W>(*vector::borrow(&routers, 2), coins_mid2);
        assert!(coin::value(&coins_out) >= amount_out_min, ERR_INSUFFICIENT_OUTPUT_AMOUNT);
        AnimeSwapPoolV1Library::register_coin<W>(account);
        coin::deposit<W>(signer::address_of(account), coins_out);
    }
}
