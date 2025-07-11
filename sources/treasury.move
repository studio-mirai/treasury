module treasury::treasury;

use std::type_name::{Self, TypeName};
use sui::balance::Balance;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};
use treasury::burn_facility::{Self, BurnFacility};
use treasury::role::Role;
use treasury::warrant::{Self, Warrant};

//=== Structs ===

// A TreasuryCap wrapper that exposes protected mint/burn functions.
public struct Treasury<phantom Currency> has key, store {
    id: UID,
    treasury_cap: TreasuryCap<Currency>,
    authorities: VecMap<TypeName, Role>,
    burn_facilities: VecSet<ID>,
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
    currency: TypeName,
    treasury_id: ID,
    value: u64,
}

public struct TreasuryCreatedEvent has copy, drop {
    currency: TypeName,
    treasury_id: ID,
}

const EBurnFacilitiesNotEmpty: u64 = 0;

//=== Public Functions ===

// Create a Treasury for type `Currency`.
// Requires a `TreasuryCap` object, which means only one Treasury
// can exist for the provided currency.
public fun new<Currency>(
    treasury_cap: TreasuryCap<Currency>,
    ctx: &mut TxContext,
): (Treasury<Currency>, TreasuryAdminCap<Currency>) {
    let treasury = Treasury {
        id: object::new(ctx),
        treasury_cap,
        authorities: vec_map::empty(),
        burn_facilities: vec_set::empty(),
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

// Create a new warrant with the provided mintable value.
public fun new_warrant<Currency, Authority: drop>(
    self: &Treasury<Currency>,
    _: Authority,
    value: u64,
    ctx: &mut TxContext,
): Warrant<Currency> {
    let authority_type = type_name::get<Authority>();

    let role = self.authorities.get(&authority_type);
    role.assert_can_mint();

    warrant::new<Currency>(value, ctx)
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

    coin
}

public fun mint_with_warrant<Currency>(
    self: &mut Treasury<Currency>,
    warrant: Warrant<Currency>,
    ctx: &mut TxContext,
): Coin<Currency> {
    let coin = self.treasury_cap.mint(warrant.value(), ctx);

    emit(SupplyMintedEvent {
        currency: type_name::get<Currency>(),
        treasury_id: object::id(self),
        value: warrant.value(),
    });

    warrant.destroy();

    coin
}

public fun new_burn_facility<Currency>(self: &mut Treasury<Currency>, ctx: &mut TxContext) {
    let burn_facility = burn_facility::new<Currency>(ctx);
    self.burn_facilities.insert(burn_facility.id());
    transfer::public_share_object(burn_facility);
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

public fun burn_with_facility<Currency>(
    self: &mut Treasury<Currency>,
    burn_facility: &mut BurnFacility<Currency>,
    ctx: &mut TxContext,
): u64 {
    let coin = burn_facility.withdraw_all().into_coin(ctx);
    let value = coin.value();

    self.treasury_cap.burn(coin);

    value
}

// Destroy the Treasury and return the TreasuryCap.
public fun destroy<Currency>(
    self: Treasury<Currency>,
    cap: TreasuryAdminCap<Currency>,
): TreasuryCap<Currency> {
    assert!(self.burn_facilities.is_empty(), EBurnFacilitiesNotEmpty);

    let Treasury { id, treasury_cap, .. } = self;
    id.delete();

    let TreasuryAdminCap { id } = cap;
    id.delete();

    treasury_cap
}

//=== View Functions ===

public fun total_supply<Currency>(self: &Treasury<Currency>): u64 {
    self.treasury_cap.total_supply()
}
