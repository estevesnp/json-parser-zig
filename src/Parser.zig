const std = @import("std");
const Lexer = @import("Lexer.zig");
const Token = Lexer.Token;

const Parser = @This();

const Object = std.StringHashMapUnmanaged(Value);
const Array = std.ArrayListUnmanaged(Value);

lexer: Lexer,
cur_token: ?Token = null,
next_token: ?Token = null,
arena: std.heap.ArenaAllocator,

const Value = union(enum) {
    object: Object,
    array: Array,
    string: []const u8,
    number: f64,
    true: void,
    false: void,
    null: void,

    pub fn format(
        self: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .object => |o| {
                try writer.writeAll("{");
                var iter = o.iterator();
                const entries = o.count();

                var idx: usize = 0;
                while (iter.next()) |entry| : (idx += 1) {
                    try writer.print("\"{s}\":{s}", .{ entry.key_ptr.*, entry.value_ptr.* });
                    if (idx < entries - 1) try writer.writeAll(",");
                }

                try writer.writeAll("}");
            },
            .array => |a| {
                try writer.writeAll("[");

                for (a.items, 0..) |val, idx| {
                    try writer.print("{s}", .{val});
                    if (idx < a.items.len - 1) try writer.writeAll(",");
                }

                try writer.writeAll("]");
            },
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .number => |n| try writer.print("\"{d}\"", .{n}),
            else => try writer.writeAll(@tagName(self)),
        }
    }
};

pub fn init(parent_allocator: std.mem.Allocator, input: []const u8) !Parser {
    var p: Parser = .{
        .lexer = Lexer.init(input),
        .arena = std.heap.ArenaAllocator.init(parent_allocator),
    };

    try p.readToken();
    try p.readToken();

    return p;
}

pub fn deinit(self: *Parser) void {
    self.arena.deinit();
}

fn readToken(self: *Parser) !void {
    self.cur_token = self.next_token;
    self.next_token = try self.lexer.nextToken();
}

fn expectToken(self: *Parser, tok_type: std.meta.Tag(Token)) !void {
    try self.readToken();
    if (self.cur_token) |tok| {
        if (tok != tok_type) return error.IncorrectToken;
    } else {
        return error.NoToken;
    }
}

pub fn parse(self: *Parser) !?Value {
    const res = try self.parseValue();

    if (self.next_token != null) return error.ExpectedEOF;

    return res;
}

fn parseValue(self: *Parser) !?Value {
    const tok = self.cur_token orelse return null;

    return switch (tok) {
        .string => |s| Value{ .string = s },
        .number => |n| Value{ .number = n },
        .true => Value{ .true = {} },
        .false => Value{ .false = {} },
        .null => Value{ .null = {} },
        .l_brace => Value{ .object = try self.parseObject() },
        .l_brack => Value{ .array = try self.parseArray() },
        else => return error.UnexpectedToken,
    };
}

fn parseObject(self: *Parser) anyerror!Object {
    const allocator = self.arena.allocator();
    var obj: Object = .{};

    try self.readToken();

    while (true) {
        const tok = self.cur_token orelse return error.UnclosedBrace;

        if (tok == .r_brace) break;
        if (tok != .string) return error.UnclosedBrace;

        const key = tok.string;

        try self.expectToken(.colon);
        try self.readToken();

        const value = try self.parseValue() orelse return error.UnclosedBrace;

        const gop = try obj.getOrPut(allocator, key);
        if (gop.found_existing) {
            return error.RepeatedKeys;
        }
        gop.value_ptr.* = value;

        const next_tok = self.next_token orelse return error.UnclosedBrace;

        if (next_tok == .comma) {
            try self.readToken();
            try self.expectToken(.string);
            continue;
        }

        try self.expectToken(.r_brace);
        break;
    }

    return obj;
}

fn parseArray(self: *Parser) anyerror!Array {
    const allocator = self.arena.allocator();
    var arr: Array = .{};

    try self.readToken();
    const tok = self.cur_token orelse return error.UnclosedBrace;
    if (tok == .r_brack) return arr;

    while (true) {
        const value = try self.parseValue() orelse return error.UnclosedBrace;
        try arr.append(allocator, value);
        const next_tok = self.next_token orelse return error.UnclosedBrace;

        if (next_tok == .comma) {
            try self.readToken();
            if (self.next_token) |next| {
                if (next == .r_brack) return error.TrailingComma;
            } else {
                return error.NoToken;
            }

            try self.readToken();
            continue;
        }
        try self.expectToken(.r_brack);
        break;
    }

    return arr;
}
