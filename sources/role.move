module treasury::role;

//=== Structs ===

// The role of an authority in the treasury (Mint, Burn, or MintBurn).
public enum Role has copy, drop, store {
    Burn,
    Mint,
    MintBurn,
}

//=== Errors ===

const EUnauthorized: u64 = 0;

//=== Public Functions ===

public fun new_burn(): Role {
    Role::Burn
}

public fun new_mint(): Role {
    Role::Mint
}

public fun new_mint_burn(): Role {
    Role::MintBurn
}

//=== Assertion Functions ===

public(package) fun assert_can_burn(self: &Role) {
    assert!(self == Role::Burn || self == Role::MintBurn, EUnauthorized);
}

public(package) fun assert_can_mint(self: &Role) {
    assert!(self == Role::Mint || self == Role::MintBurn, EUnauthorized);
}
