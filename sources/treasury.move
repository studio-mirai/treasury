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
}

//=== Events ===

public struct AuthorityAddedEvent has copy, drop {
    authority: TypeName,
    currency: TypeName,
    treasury_id: ID,
}

public struct AuthorityRemovedEvent has copy, drop {
    authority: TypeName,
    currency: TypeName,
    treasury_id: ID,
}

public struct SupplyBurnedEvent has copy, drop {
    authority: TypeName,
    currency: TypeName,
    treasury_id: ID,
    value: u64,
}

public struct SupplyMintedEvent has copy, drop {
    authority: TypeName,
    currency: TypeName,
    treasury_id: ID,
    value: u64,
}
public struct TreasuryCreatedEvent has copy, drop {
    currency: TypeName,
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

    let treasury_admin_cap = TreasuryAdminCap<Currency> {
        id: object::new(ctx),
    };

    emit(TreasuryCreatedEvent {
        currency: type_name::get<Currency>(),
        treasury_id: object::id(&treasury),
    });

    (treasury, treasury_admin_cap)
}

// Destroy the Treasury and return the TreasuryCap.
public fun destroy<Currency>(
    self: Treasury<Currency>,
    cap: TreasuryAdminCap<Currency>,
): TreasuryCap<Currency> {
    let Treasury { id, treasury_cap, .. } = self;
    id.delete();

    let TreasuryAdminCap { id } = cap;
    id.delete();

    treasury_cap
}

public fun burn<Currency, Authority: drop>(
    self: &mut Treasury<Currency>,
    _: Authority,
    coin: Coin<Currency>,
): u64 {
    let authority_type = type_name::get<Authority>();

    let role = self.authorities.get(&authority_type);
    role.assert_can_burn();

    let value = coin.value();

    self.treasury_cap.burn(coin);

    emit(SupplyBurnedEvent {
        authority: authority_type,
        currency: type_name::get<Currency>(),
        treasury_id: object::id(self),
        value,
    });

    value
}

public fun mint<Currency, Authority: drop>(
    self: &mut Treasury<Currency>,
    _: Authority,
    value: u64,
    ctx: &mut TxContext,
): Coin<Currency> {
    let authority_type = type_name::get<Authority>();

    let role = self.authorities.get(&authority_type);
    role.assert_can_mint();

    let coin = self.treasury_cap.mint(value, ctx);

    emit(SupplyMintedEvent {
        authority: authority_type,
        currency: type_name::get<Currency>(),
        treasury_id: object::id(self),
        value,
    });

    coin
}

public fun add_authority<Currency, Authority: drop>(
    self: &mut Treasury<Currency>,
    _: &TreasuryAdminCap<Currency>,
    role: Role,
) {
    let authority_type = type_name::get<Authority>();
    self.authorities.insert(authority_type, role);

    emit(AuthorityAddedEvent {
        authority: authority_type,
        currency: type_name::get<Currency>(),
        treasury_id: object::id(self),
    });
}

public fun remove_authority<Currency, Authority: drop>(
    self: &mut Treasury<Currency>,
    _: &TreasuryAdminCap<Currency>,
) {
    let authority_type = type_name::get<Authority>();
    self.authorities.remove(&authority_type);

    emit(AuthorityRemovedEvent {
        authority: authority_type,
        currency: type_name::get<Currency>(),
        treasury_id: object::id(self),
    });
}

//=== View Functions ===

public fun total_supply<Currency>(self: &Treasury<Currency>): u64 {
    self.treasury_cap.total_supply()
}
