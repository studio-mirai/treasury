module treasury::burn_facility;

use sui::balance::{Self, Balance};
use sui::coin::Coin;

//=== Structs ===

public struct BurnFacility<phantom Currency> has key, store {
    id: UID,
    balance: Balance<Currency>,
}

//=== Public Functions ===

// Deposit a coin into the burn facility. Returns the value of the deposited coin.
public fun deposit<Currency>(self: &mut BurnFacility<Currency>, coin: Coin<Currency>): u64 {
    let value = coin.value();
    self.balance.join(coin.into_balance());
    value
}

//=== Package Functions ===

public(package) fun new<Currency>(ctx: &mut TxContext): BurnFacility<Currency> {
    BurnFacility {
        id: object::new(ctx),
        balance: balance::zero(),
    }
}

public(package) fun destroy<Currency>(self: BurnFacility<Currency>): Balance<Currency> {
    let BurnFacility { id, balance } = self;
    id.delete();
    balance
}

public(package) fun withdraw_all<Currency>(self: &mut BurnFacility<Currency>): Balance<Currency> {
    self.balance.withdraw_all()
}

//=== Public View Functions ===

public fun id<Currency>(self: &BurnFacility<Currency>): ID {
    object::id(self)
}

public fun balance_value<Currency>(self: &BurnFacility<Currency>): u64 {
    self.balance.value()
}
