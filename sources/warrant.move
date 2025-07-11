module treasury::warrant;

//=== Structs ===

public struct Warrant<phantom Currency> has key, store {
    id: UID,
    value: u64,
}

// Merge multiple Warrants into a single Warrant.
public fun merge<Currency>(
    warrants: vector<Warrant<Currency>>,
    ctx: &mut TxContext,
): Warrant<Currency> {
    let mut merged_value = 0;

    warrants.destroy!(|warrant| {
        merged_value = merged_value + warrant.destroy();
    });

    Warrant {
        id: object::new(ctx),
        value: merged_value,
    }
}

//=== Package Functions ===

public(package) fun new<Currency>(value: u64, ctx: &mut TxContext): Warrant<Currency> {
    Warrant {
        id: object::new(ctx),
        value,
    }
}

public(package) fun destroy<Currency>(cap: Warrant<Currency>): u64 {
    let Warrant { id, value } = cap;
    id.delete();
    value
}

//=== Public View Functions ===

public fun value<Currency>(cap: &Warrant<Currency>): u64 {
    cap.value
}
