const std = @import("std");
const Lexer = @This();

pub const Token = union(enum) {
    l_brace,
    r_brace,
    l_brack,
    r_brack,
    comma,
    colon,

    string: []const u8,
    number: f64,
    true,
    false,
    null,
};

pub const Error = error{
    UnexpectedCharacter,
    ExpectedQuoteMark,
    InvalidControl,
    BareControl,
    InvalidKeyword,
} || NumberParseError;

pub const NumberParseError = error{
    BadFraction,
    RepeatedFraction,
    RepeatedExponent,
    RepeatedExponentSign,
} || std.fmt.ParseFloatError;

input: []const u8,
pos: usize = 0,
read_pos: usize = 0,
ch: u8 = 0,

pub fn init(input: []const u8) Lexer {
    var l: Lexer = .{ .input = input };
    l.readChar();
    return l;
}

fn readChar(self: *Lexer) void {
    if (self.read_pos >= self.input.len) {
        self.ch = 0;
        return;
    }

    self.ch = self.input[self.read_pos];
    self.pos = self.read_pos;
    self.read_pos += 1;
}

fn peekChar(self: *Lexer) ?u8 {
    if (self.read_pos >= self.input.len) {
        return null;
    }
    return self.input[self.read_pos];
}

fn skipWhitespaces(self: *Lexer) void {
    while (self.ch == ' ' or self.ch == '\n' or self.ch == '\r' or self.ch == '\t') {
        self.readChar();
    }
}

pub fn nextToken(self: *Lexer) Error!?Token {
    self.skipWhitespaces();
    defer self.readChar();

    return switch (self.ch) {
        '{' => .l_brace,
        '}' => .r_brace,
        '[' => .l_brack,
        ']' => .r_brack,
        ',' => .comma,
        ':' => .colon,

        '"' => .{ .string = try self.parseString() },
        '-', '0'...'9' => .{ .number = try self.parseNumber() },
        't' => try self.parseTrue(),
        'f' => try self.parseFalse(),
        'n' => try self.parseNull(),

        0 => null,

        else => Error.UnexpectedCharacter,
    };
}

fn parseString(self: *Lexer) Error![]const u8 {
    if (self.pos >= self.input.len - 1) return Error.ExpectedQuoteMark;

    self.readChar();

    const start_pos = self.pos;

    blk: while (true) : (self.readChar()) {
        switch (self.ch) {
            '"' => break :blk,
            '\\' => {
                self.readChar();
                // TODO - deal with /u1234
                switch (self.ch) {
                    '"',
                    '\\',
                    '/',
                    'b',
                    'f',
                    'n',
                    'r',
                    't',
                    => {},
                    else => return Error.InvalidControl,
                }
            },
            else => if (std.ascii.isControl(self.ch)) return Error.BareControl,
        }
    }

    const end_pos = if (self.ch == 0) self.input.len else self.pos;

    return self.input[start_pos..end_pos];
}

fn parseNumber(self: *Lexer) NumberParseError!f64 {
    const start_pos = self.pos;
    if (self.ch == '-') self.readChar();

    var in_fraction = false;
    var in_exponent = false;
    var signed_exponent = false;

    blk: while (self.peekChar()) |ch| : (self.readChar()) {
        switch (ch) {
            '0'...'9' => {},
            '.' => {
                if (!in_fraction) {
                    if (in_exponent) return NumberParseError.BadFraction;
                    in_fraction = true;
                } else {
                    return NumberParseError.RepeatedFraction;
                }
            },
            'e', 'E' => {
                if (!in_exponent) {
                    in_exponent = true;
                } else {
                    return NumberParseError.RepeatedExponent;
                }
            },
            '+', '-' => {
                if (!signed_exponent) {
                    signed_exponent = true;
                } else {
                    return NumberParseError.RepeatedExponentSign;
                }
            },
            else => break :blk,
        }
    }

    const end_pos = if (self.ch == 0) self.input.len else self.read_pos;
    return try std.fmt.parseFloat(f64, self.input[start_pos..end_pos]);
}

fn parseTrue(self: *Lexer) Error!Token {
    try self.parseKeyword("true");
    return .true;
}

fn parseFalse(self: *Lexer) Error!Token {
    try self.parseKeyword("false");
    return .false;
}

fn parseNull(self: *Lexer) Error!Token {
    try self.parseKeyword("null");
    return .null;
}

fn parseKeyword(self: *Lexer, word: []const u8) Error!void {
    if (self.input.len - self.pos < word.len) {
        return Error.InvalidKeyword;
    }

    const start_pos = self.pos;

    for (0..word.len - 1) |_| self.readChar();

    if (!std.mem.eql(u8, self.input[start_pos..][0..word.len], word)) {
        return Error.InvalidKeyword;
    }

    if (self.peekChar()) |ch| {
        if (std.ascii.isAlphabetic(ch)) return Error.InvalidKeyword;
    }
}

test "read and peek char" {
    var l = Lexer.init("abc");

    try std.testing.expectEqual('a', l.ch);
    try std.testing.expectEqual('b', l.peekChar());

    l.readChar();
    try std.testing.expectEqual('b', l.ch);
    try std.testing.expectEqual('c', l.peekChar());

    l.readChar();
    try std.testing.expectEqual('c', l.ch);
    try std.testing.expectEqual(null, l.peekChar());

    l.readChar();
    try std.testing.expectEqual(0, l.ch);
}

test "skipWhitespaces" {
    var l = Lexer.init(" a\nb\rc\td");

    l.skipWhitespaces();
    try std.testing.expectEqual('a', l.ch);

    l.readChar();
    l.skipWhitespaces();
    try std.testing.expectEqual('b', l.ch);

    l.readChar();
    l.skipWhitespaces();
    try std.testing.expectEqual('c', l.ch);

    l.readChar();
    l.skipWhitespaces();
    try std.testing.expectEqual('d', l.ch);
}

test "parseString" {
    var l = Lexer.init("\"string\"");
    try std.testing.expectEqualStrings("string", try l.parseString());
}

test "parseFloat" {
    var l = Lexer.init("1.2e10");
    try std.testing.expectEqual(1.2e10, l.parseNumber());
}

test "parseTrue" {
    var l = Lexer.init("true");
    try std.testing.expectEqual(.true, l.parseTrue());
}

test "parseFalse" {
    var l = Lexer.init("false");
    try std.testing.expectEqual(.false, l.parseFalse());
}

test "parseNull" {
    var l = Lexer.init("null");
    try std.testing.expectEqual(.null, l.parseNull());
}

test "nextToken" {
    try testToken(
        \\{
        \\  "foo": true,
        \\  "bar": 42.5 
        \\}
    , &.{
        .l_brace,
        .{ .string = "foo" },
        .colon,
        .true,
        .comma,
        .{ .string = "bar" },
        .colon,
        .{ .number = 42.5 },
        .r_brace,
    });

    try testToken(
        \\["hello",true,null,-42.24e-22,false,{"true":"false"}]
    , &.{
        .l_brack,
        .{ .string = "hello" },
        .comma,
        .true,
        .comma,
        .null,
        .comma,
        .{ .number = -42.24e-22 },
        .comma,
        .false,
        .comma,
        .l_brace,
        .{ .string = "true" },
        .colon,
        .{ .string = "false" },
        .r_brace,
        .r_brack,
    });

    try testToken("true", &.{.true});
    try testToken("true ", &.{.true});
    try testToken("22.4e22", &.{.{ .number = 22.4e22 }});
    try testToken("22.4e22 ", &.{.{ .number = 22.4e22 }});
    try testToken("\"foo\"", &.{.{ .string = "foo" }});
    try testToken("\"foo\" ", &.{.{ .string = "foo" }});
}

fn testToken(input: []const u8, tokens: []const Token) !void {
    var l = Lexer.init(input);

    for (tokens, 0..) |expected_token, idx| {
        switch (expected_token) {
            .string => |expected_str| {
                const tok = try l.nextToken() orelse {
                    std.debug.print("expected token with str '{s}' at idx {d}, found null\n", .{ expected_str, idx });
                    return error.NoToken;
                };
                if (tok != .string) {
                    std.debug.print("expected string token with value '{s}' at idx {d}, got '{s}'\n", .{ expected_str, idx, @tagName(tok) });
                    return error.WrongTokenType;
                }
                if (!std.mem.eql(u8, expected_str, tok.string)) {
                    std.debug.print("expected str '{s}' at idx {d}, got '{s}'\n", .{ expected_str, idx, tok.string });
                    return error.WrongValue;
                }
            },
            else => {
                const tok = try l.nextToken() orelse {
                    std.debug.print("expected token '{any}' at idx {d}, found null\n", .{ expected_token, idx });
                    return error.NoToken;
                };
                if (@as(std.meta.Tag(Token), expected_token) != @as(std.meta.Tag(Token), tok)) {
                    std.debug.print("expected token of type '{s}' at idx {d}, got '{s}'\n", .{ @tagName(expected_token), idx, @tagName(tok) });
                    return error.WrongTokenType;
                }
                if (!std.meta.eql(expected_token, tok)) {
                    std.debug.print("expected token '{any}' at idx {d}, got '{any}'\n", .{ expected_token, idx, tok });
                    return error.WrongValue;
                }
            },
        }
    }
}
