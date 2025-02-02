const std = @import("std");
const assert = std.debug.assert;

const json = @import("json.zig");

const Foo = struct {
    bar: Bar,
    baz: [][]const u8,
};

const Bar = struct {
    foobar: f32,
    foobaz: bool,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const input =
        \\  {
        \\    "bar": {
        \\      "foobar": 42.27,
        \\      "foobaz": false
        \\    },
        \\    "baz": [
        \\      "foo",
        \\      "bar",
        \\      "baz"
        \\    ]
        \\  }
    ;

    var res = try json.deserialize(Foo, allocator, input);
    defer res.deinit();

    assert(std.meta.eql(res.value.bar, .{ .foobar = 42.27, .foobaz = false }));
    assert(std.mem.eql(u8, res.value.baz[0], "foo"));
    assert(std.mem.eql(u8, res.value.baz[1], "bar"));
    assert(std.mem.eql(u8, res.value.baz[2], "baz"));

    const serialized = try json.serialize(allocator, res.value);
    defer allocator.free(serialized);

    assert(std.mem.eql(u8, serialized,
        \\{"bar":{"foobar":42.27,"foobaz":false},"baz":["foo","bar","baz"]}
    ));
}
