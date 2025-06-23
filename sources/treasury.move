module treasury::treasury;

use std::type_name::{Self, TypeName};
use sui::balance::Balance;
use sui::coin::{Coin, TreasuryCap};
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use treasury::role::Role;

//=== Structs ===

// A TreasuryCap wrapper that exposes protected mint/burn functions.
public struct Treasury<phantom Currency> has key, store {
    id: UID,
    authorities: VecMap<TypeName, Role>,
    treasury_cap: TreasuryCap<Currency>,
}

// A TreasuryAdminCap is a capability to add/remove authorities to a Treasury.
public struct TreasuryAdminCap<phantom Currency> has key, store {
    id: UID,
    treasury_id: ID,
}

//=== Events ===

public struct SupplyBurnedEvent<phantom Currency> has copy, drop {
    value: u64,
}

public struct SupplyMintedEvent<phantom Currency> has copy, drop {
    value: u64,
}
public struct TreasuryCreatedEvent<phantom Currency> has copy, drop {
    treasury_id: ID,
}

//=== Public Functions ===

public fun new<Currency>(
    treasury_cap: TreasuryCap<Currency>,
    ctx: &mut TxContext,
): (Treasury<Currency>, TreasuryAdminCap<Currency>) {
    let treasury = Treasury {
        id: object::new(ctx),
        authorities: vec_map::empty(),
        treasury_cap,
    };

    let treasury_id = object::id(&treasury);

    let treasury_admin_cap = TreasuryAdminCap<Currency> {
        id: object::new(ctx),
        treasury_id: treasury_id,
    };

    emit(TreasuryCreatedEvent<Currency> { treasury_id: treasury_id });

    (treasury, treasury_admin_cap)
}

public fun burn_coin<Currency, Authority: drop>(
    self: &mut Treasury<Currency>,
    _: Authority,
    coin: Coin<Currency>,
): u64 {
    let role = self.authorities.get(&type_name::get<Authority>());
    role.assert_can_burn();

    let value = coin.value();

    self.treasury_cap.burn(coin);
    emit(SupplyBurnedEvent<Currency> { value });

    value
}

public fun mint_balance<Currency, Authority: drop>(
    self: &mut Treasury<Currency>,
    _: Authority,
    value: u64,
): Balance<Currency> {
    let role = self.authorities.get(&type_name::get<Authority>());
    role.assert_can_mint();

    let balance = self.treasury_cap.mint_balance(value);
    emit(SupplyMintedEvent<Currency> { value });

    balance
}

public fun mint_coin<Currency, Authority: drop>(
    self: &mut Treasury<Currency>,
    _: Authority,
    value: u64,
    ctx: &mut TxContext,
): Coin<Currency> {
    let role = self.authorities.get(&type_name::get<Authority>());
    role.assert_can_mint();

    let coin = self.treasury_cap.mint(value, ctx);
    emit(SupplyMintedEvent<Currency> { value });

    coin
}

public fun add_authority<Currency, Authority: drop>(
    self: &mut Treasury<Currency>,
    _: &TreasuryAdminCap<Currency>,
    role: Role,
) {
    self.authorities.insert(type_name::get<Authority>(), role);
}

public fun remove_authority<Currency, Authority: drop>(
    self: &mut Treasury<Currency>,
    _: &TreasuryAdminCap<Currency>,
) {
    self.authorities.remove(&type_name::get<Authority>());
}

//=== View Functions ===

public fun total_supply<Currency>(self: &Treasury<Currency>): u64 {
    self.treasury_cap.total_supply()
}
