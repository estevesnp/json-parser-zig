const std = @import("std");
const assert = std.debug.assert;

const Parser = @import("Parser.zig");
const deserialize = @import("deserializer.zig");

const Foo = struct {
    bar: Bar,
    baz: []const bool,
};

const Bar = struct {
    foobar: u32,
    foobaz: f32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const input =
        \\  {
        \\    "bar": {
        \\      "foobar": 42,
        \\      "foobaz": 22.7
        \\    },
        \\    "baz": [
        \\      true,
        \\      false,
        \\      false
        \\    ]
        \\  }
    ;

    var res = try deserialize.deserialize(Foo, gpa.allocator(), input);
    defer res.deinit();

    assert(std.meta.eql(res.value.bar, .{ .foobar = 42, .foobaz = 22.7 }));
    assert(std.mem.eql(bool, res.value.baz, &.{ true, false, false }));
}
