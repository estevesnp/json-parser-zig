const json = @import("json.zig");

pub const deserialize = json.deserialize;
pub const serialize = json.serialize;

test "reference declarations" {
    @import("std").testing.refAllDeclsRecursive(@This());
}
