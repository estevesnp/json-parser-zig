const std = @import("std");
const Parser = @import("Parser.zig");

pub fn Result(T: type) type {
    return struct {
        value: T,
        arena: std.heap.ArenaAllocator,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
        }
    };
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
