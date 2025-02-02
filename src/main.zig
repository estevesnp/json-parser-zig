const std = @import("std");
const Parser = @import("Parser.zig");
const deserialize = @import("deserializer.zig");

const Foo = struct {
    bar: u32,
};

const Wrap = struct {
    foo: []Foo,
};

const Stringer = struct {
    foo: []const u8,
    bar: []u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    {
        const input =
            \\[{"bar": 22},{"bar": 12},{"bar": 2}]
        ;

        var res = try deserialize.deserialize([]Foo, allocator, input);
        defer res.deinit();

        std.debug.print("{any}\n", .{res.value});
    }

    {
        const input =
            \\[ true ]
        ;

        var res = try deserialize.deserialize([]bool, allocator, input);
        defer res.deinit();

        std.debug.print("{any}\n", .{res.value});
    }

    {
        const input =
            \\{ "foo": "um foo", "bar": "um bar" }
        ;

        var res = try deserialize.deserialize(Stringer, allocator, input);
        defer res.deinit();

        std.debug.print("{s} | {s} \n", .{ res.value.foo, res.value.bar });
    }
}
