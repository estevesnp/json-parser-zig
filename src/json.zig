const std = @import("std");
const Parser = @import("Parser.zig");

const string_fmt = "\"{s}\"";

pub fn Result(T: type) type {
    return struct {
        value: T,
        arena: std.heap.ArenaAllocator,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
        }
    };
}

pub fn serialize(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var buf_list = std.ArrayList(u8).init(allocator);

    const writer = buf_list.writer();

    try serializeValue(writer, value);

    return buf_list.toOwnedSlice();
}

fn serializeValue(writer: anytype, value: anytype) !void {
    const val_type = @TypeOf(value);
    switch (@typeInfo(val_type)) {
        .Bool => try writer.print("{}", .{value}),

        .Int,
        .Float,
        .ComptimeInt,
        .ComptimeFloat,
        => try writer.print("{d}", .{value}), // TODO - check if we can skip {d}

        .Type => try writer.print(string_fmt, .{@typeName(val_type)}),
        .Enum => try writer.print(string_fmt, .{@tagName(value)}),

        .Null => try writer.writeAll("null"),

        .Struct => |s| {
            if (s.is_tuple) {
                try serializeTuple(writer, value);
            } else {
                try serializeObject(writer, value);
            }
        },
        .Pointer => |p| switch (p.size) {
            .Slice => switch (p.child) {
                u8 => try writer.print(string_fmt, .{value}),
                else => try serializeArray(writer, value),
            },
            .One => switch (@typeInfo(p.child)) {
                .Array => |a| try serializeValue(writer, @as([]const a.child, value)),
                else => try serializeValue(writer, value.*),
            },
            else => return error.UnsupportedType,
        },
        else => return error.UnsupportedType,
        //else => @compileError("can't compile type " ++ @typeName(@TypeOf(value))),
    }
}

fn serializeObject(writer: anytype, obj: anytype) !void {
    const fields = @typeInfo(@TypeOf(obj)).Struct.fields;

    try writer.writeByte('{');

    inline for (fields, 0..) |field, idx| {
        try writer.print(string_fmt ++ ":", .{field.name});
        try serializeValue(writer, @field(obj, field.name));
        if (idx < fields.len - 1) try writer.writeByte(',');
    }

    try writer.writeByte('}');
}
fn serializeArray(writer: anytype, arr: anytype) !void {
    try writer.writeByte('[');

    for (arr, 0..) |elem, idx| {
        try serializeValue(writer, elem);
        if (idx < arr.len - 1) try writer.writeByte(',');
    }

    try writer.writeByte(']');
}

fn serializeTuple(writer: anytype, tuple: anytype) !void {
    try writer.writeByte('[');

    inline for (tuple, 0..) |elem, idx| {
        try serializeValue(writer, elem);
        if (idx < tuple.len - 1) try writer.writeByte(',');
    }
    try writer.writeByte(']');
}

pub fn deserialize(T: type, allocator: std.mem.Allocator, input: []const u8) !Result(T) {
    var parser = try Parser.init(allocator, input);
    defer parser.deinit();

    const val = try parser.parse() orelse return error.NoInput;

    var arena = std.heap.ArenaAllocator.init(allocator);

    const res = try deserializeValue(T, arena.allocator(), val);
    return .{
        .value = res,
        .arena = arena,
    };
}

fn deserializeValue(T: type, allocator: std.mem.Allocator, value: Parser.Value) !T {
    switch (@typeInfo(T)) {
        .Bool => {
            return switch (value) {
                .true => true,
                .false => false,
                else => error.TypeMismatch,
            };
        },
        .Int => {
            return switch (value) {
                .number => |n| @as(T, @intFromFloat(n)),
                else => error.TypeMismatch,
            };
        },
        .Float => {
            return switch (value) {
                .number => |n| @as(T, @floatCast(n)),
                else => error.TypeMismatch,
            };
        },
        .Struct => {
            return switch (value) {
                .object => |o| deserializeObject(T, allocator, o),
                else => error.TypeMismatch,
            };
        },
        .Pointer => |p| {
            return switch (p.size) {
                .Slice => switch (value) {
                    .array => |a| try deserializeArray(T, allocator, a),
                    .string => |s| switch (p.child) {
                        u8 => try allocator.dupe(u8, s),
                        else => error.TypeMismatch,
                    },
                    else => error.TypeMismatch,
                },
                else => error.UnsupportedType,
            };
        },
        else => return error.UnsupportedType,
    }
}

fn deserializeObject(T: type, allocator: std.mem.Allocator, obj: Parser.Object) !T {
    const info = @typeInfo(T).Struct;

    var res: T = undefined;

    inline for (info.fields) |field| {
        const v = obj.get(field.name) orelse return error.MissingProperty;
        @field(res, field.name) = try deserializeValue(field.type, allocator, v);
    }

    return res;
}

fn deserializeArray(T: type, allocator: std.mem.Allocator, arr: Parser.Array) !T {
    const Child = @typeInfo(T).Pointer.child;

    var list = std.ArrayList(Child).init(allocator);

    for (arr.items) |elem| {
        const v = try deserializeValue(Child, allocator, elem);
        try list.append(v);
    }

    return list.items;
}
