const std = @import("std");
const Parser = @import("Parser.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const input =
        \\{"foo": [42.24e-4, true, false, null, {"bar": "baz"}]}
    ;

    var parser = try Parser.init(gpa.allocator(), input);
    defer parser.deinit();

    const res = try parser.parse();
    try stdout.writer().print("{any}\n", .{res});
}
