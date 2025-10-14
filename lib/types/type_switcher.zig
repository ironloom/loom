const std = @import("std");

fn safeIntCast(comptime T: type, value2: anytype) T {
    if (std.math.maxInt(T) < value2) {
        return std.math.maxInt(T);
    }
    if (std.math.minInt(T) > value2) {
        return std.math.minInt(T);
    }

    return @intCast(value2);
}

pub inline fn coerceTo(comptime T: type, value: anytype) ?T {
    const K = @TypeOf(value);
    if (K == T) return value;

    const value_info = @typeInfo(K);

    return switch (@typeInfo(T)) {
        .int, .comptime_int => switch (value_info) {
            .int, .comptime_int => safeIntCast(T, value),
            .float, .comptime_float => @intFromFloat(
                @max(
                    @as(K, @floatFromInt(std.math.minInt(T))),
                    @min(@as(K, @floatFromInt(std.math.maxInt(T))), @round(value)),
                ),
            ),
            .bool => @as(T, @intFromBool(value)),
            .@"enum" => @as(T, @intFromEnum(value)),
            .pointer => safeIntCast(T, @as(usize, @intFromPtr(value))),
            else => null,
        },
        .float, .comptime_float => switch (value_info) {
            .int, .comptime_int => @as(T, @floatFromInt(value)),
            .float, .comptime_float => @as(T, @floatCast(value)),
            .bool => @as(T, @floatFromInt(@intFromBool(value))),
            .@"enum" => @as(T, @floatFromInt(@intFromEnum(value))),
            .pointer => @as(T, @floatFromInt(@as(usize, @intFromPtr(value)))),
            else => null,
        },
        .bool => switch (value_info) {
            .int, .comptime_int => value != 0,
            .float, .comptime_float => @as(isize, @intFromFloat(@round(value))) != 0,
            .bool => value,
            .@"enum" => @as(isize, @intFromEnum(value)) != 0,
            .pointer => @as(usize, @intFromPtr(value)) != 0,
            else => null,
        },
        .@"enum" => switch (value_info) {
            .int, .comptime_int => @enumFromInt(value),
            .float, .comptime_float => @enumFromInt(@as(isize, @intFromFloat(@round(value)))),
            .bool => @enumFromInt(@intFromBool(value)),
            .@"enum" => |enum_info| @enumFromInt(@as(enum_info.tag_type, @intFromEnum(value))),
            .pointer => @enumFromInt(@as(usize, @intFromPtr(value))),
            else => null,
        },
        .pointer => switch (value_info) {
            .int, .comptime_int => @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(value)))),
            .float, .comptime_float => @compileError("Cannot convert float to pointer address"),
            .bool => @compileError("Cannot convert bool to pointer address"),
            .@"enum" => @compileError("Cannot convert enum to pointer address"),
            .pointer => @ptrCast(@alignCast(value)),
            else => null,
        },
        else => Catch: {
            std.log.warn(
                "cannot change type of \"{any}\" to type \"{any}\"",
                .{ @TypeOf(value), T },
            );
            break :Catch null;
        },
    };
}

test "coerceTo type handling" {
    const expect = std.testing.expect;
    const x = enum(u8) { a = 0, b = 32 };

    try expect(coerceTo(f32, 0) != null);
    try expect(coerceTo(i32, 0) != null);
    try expect(coerceTo(x, 0) != null);
    try expect(coerceTo(bool, 0) != null);
    try expect(coerceTo(*anyopaque, 1) != null);
}

test "coerceTo return type" {
    const expect = std.testing.expect;
    const x = enum(u8) { a = 0, b = 32 };

    try expect(@TypeOf(coerceTo(f32, 0).?) == f32);
    try expect(@TypeOf(coerceTo(i32, 0).?) == i32);
    try expect(@TypeOf(coerceTo(x, 0).?) == x);
    try expect(@TypeOf(coerceTo(*anyopaque, 1).?) == *anyopaque);
}

test "coerceTo int conversions" {
    const expect = std.testing.expect;
    const x = enum(u8) { a = 0, b = 32 };

    var int: usize = 32;
    const int_address: usize = @intFromPtr(&int);
    const @"comptime_int": comptime_int = 32;

    try expect(coerceTo(usize, -1).? == @as(usize, 0));
    try expect(coerceTo(u8, std.math.maxInt(u128)).? == @as(u8, 255));
    try expect(coerceTo(isize, int).? == @as(isize, 32));
    try expect(coerceTo(f32, int).? == @as(f32, 32.0));
    try expect(coerceTo(x, int).? == @as(x, x.b));
    try expect(coerceTo(bool, int).? == @as(bool, true));
    try expect(coerceTo(*usize, int_address).? == &int);

    try expect(coerceTo(isize, @"comptime_int").? == @as(isize, 32));
    try expect(coerceTo(f32, @"comptime_int").? == @as(f32, 32.0));
    try expect(coerceTo(x, @"comptime_int").? == @as(x, x.b));
    try expect(coerceTo(bool, @"comptime_int").? == @as(bool, true));
}

test "coerceTo float conversions" {
    const expect = std.testing.expect;
    const x = enum(u8) { a = 0, b = 32 };

    const float: f64 = 32.34;
    const @"comptime_float": comptime_float = 32.34;

    try expect(coerceTo(isize, float).? == @as(isize, 32));
    try expect(coerceTo(u8, std.math.floatMax(f128)).? == @as(u8, 255));
    try expect(coerceTo(f32, float).? == @as(f32, 32.34));
    try expect(coerceTo(x, float).? == @as(x, x.b));
    try expect(coerceTo(bool, float).? == @as(bool, true));

    try expect(coerceTo(isize, @"comptime_float").? == @as(isize, 32));
    try expect(coerceTo(f32, @"comptime_float").? == @as(f32, 32.34));
    try expect(coerceTo(x, @"comptime_float").? == @as(x, x.b));
    try expect(coerceTo(bool, @"comptime_float").? == @as(bool, true));
}

test "coerceTo enum conversions" {
    const expect = std.testing.expect;
    const x = enum(u8) { a = 0, b = 32 };
    const @"enum": x = x.b;

    try expect(coerceTo(isize, @"enum").? == @as(isize, 32));
    try expect(coerceTo(f32, @"enum").? == @as(f32, 32.0));
    try expect(coerceTo(x, @"enum").? == @as(x, x.b));
    try expect(coerceTo(bool, @"enum").? == @as(bool, true));
}

test "coerceTo bool conversions" {
    const expect = std.testing.expect;
    const x = enum(u8) { a = 0, b = 32 };

    const boolean: bool = false;

    try expect(coerceTo(isize, boolean).? == @as(isize, 0));
    try expect(coerceTo(f32, boolean).? == @as(f32, 0.0));
    try expect(coerceTo(x, boolean).? == @as(x, x.a));
    try expect(coerceTo(bool, boolean).? == @as(bool, false));
}

test "coerceTo pointer conversions" {
    const expect = std.testing.expect;
    const x = enum(u8) { a = 0, b = 32 };
    const @"enum": x = x.b;

    var int: usize = 32;
    const int_address: usize = @intFromPtr(&int);
    const anyopaque_ptr_of_int: *anyopaque = @ptrCast(@alignCast(&int));

    try expect(coerceTo(usize, &int) == int_address);
    try expect(coerceTo(f64, &int) == @as(f64, @floatFromInt(int_address)));
    try expect(coerceTo(bool, &int) == (int_address != 0));
    try expect(coerceTo(x, @as(*anyopaque, @ptrFromInt(32))) == @"enum");
    try expect(coerceTo(*usize, anyopaque_ptr_of_int) == &int);
}
