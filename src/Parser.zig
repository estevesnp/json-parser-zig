const std = @import("std");
const Lexer = @import("Lexer.zig");

const Parser = @This();

lexer: Lexer,

const Value = union(enum) {
    object: std.StringHashMapUnmanaged(Value),
    array: std.ArrayListUnmanaged(Value),
    string: []const u8,
    number: f64,
    true: void,
    false: void,
    null: void,
};

pub fn init(input: []const u8) Parser {
    return .{ .lexer = Lexer.init(input) };
}

pub fn parse(self: *Parser) !?Value {
    const tok = try self.lexer.nextToken() orelse return null;

    return switch (tok) {
        .string => |s| Value{ .string = s },
        .number => |n| Value{ .number = n },
        .true => Value{ .true = {} },
        .false => Value{ .false = {} },
        .null => Value{ .null = {} },
        .l_brace => error.ToImplementObj,
        .l_brack => error.ToImplementArr,
        else => error.UnexpectedToken,
    };
}
