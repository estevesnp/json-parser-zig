const std = @import("std");
const Parser = @import("Parser.zig");

pub fn main() !void {
    const input =
        \\"foo"
    ;

    var parser = Parser.init(input);

    const res = try parser.parse();
    std.debug.print("{any}\n", .{res});
}
