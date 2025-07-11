module treasury::mint_option;

//=== Structs ===

public struct MintOption<phantom Currency> has key, store {
    id: UID,
    value: u64,
}

// Merge multiple MintOptions into a single MintOption.
public fun merge<Currency>(
    mint_options: vector<MintOption<Currency>>,
    ctx: &mut TxContext,
): MintOption<Currency> {
    let mut merged_value = 0;

    mint_options.destroy!(|mint_option| {
        merged_value = merged_value + mint_option.destroy();
    });

    MintOption {
        id: object::new(ctx),
        value: merged_value,
    }
}

//=== Package Functions ===

public(package) fun new<Currency>(value: u64, ctx: &mut TxContext): MintOption<Currency> {
    MintOption {
        id: object::new(ctx),
        value,
    }
}

public(package) fun destroy<Currency>(cap: MintOption<Currency>): u64 {
    let MintOption { id, value } = cap;
    id.delete();
    value
}

//=== Public View Functions ===

public fun value<Currency>(cap: &MintOption<Currency>): u64 {
    cap.value
}
