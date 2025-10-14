const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub inline fn MappingFn(T: type, R: type) type {
    return fn (T) ?R;
}

pub inline fn ReduceFn(T: type, R: type) type {
    return fn (accumulator: R, current: T) R;
}

pub inline fn FilterCriteriaFn(T: type) type {
    return fn (item: T) bool;
}

pub inline fn ForEachFn(T: type) type {
    return fn (item: T) anyerror!void;
}

pub fn map(T: type, R: type, allocator: Allocator, array: []T, mapping_function: MappingFn(T, R)) ![]R {
    var list: std.ArrayList(R) = .empty;

    for (array) |item| {
        if (mapping_function(item)) |mapped| try list.append(allocator, mapped);
    }

    return list.toOwnedSlice(allocator);
}

pub fn reduce(T: type, R: type, array: []T, initial: R, reduce_function: ReduceFn(T, R)) R {
    var accumulator: R = initial;
    for (array) |item| {
        accumulator = reduce_function(accumulator, item);
    }

    return accumulator;
}

pub fn filter(T: type, allocator: Allocator, array: []T, criteria: FilterCriteriaFn(T)) ![]T {
    var list: std.ArrayList(T) = .empty;

    for (array) |item| {
        if (criteria(item)) try list.append(allocator, item);
    }

    return try list.toOwnedSlice(allocator);
}

pub inline fn forEach(T: type, array: []T, foreach_function: ForEachFn(T)) !void {
    for (array) |item| {
        try foreach_function(item);
    }
}

test map {
    const mapFunc = struct {
        pub fn mapFunc(mappable: usize) ?u8 {
            return @as(u8, @intCast(@min(255, mappable)));
        }
    }.mapFunc;

    const mapOrNullFunc = struct {
        pub fn mapOrNullFunc(mappable: usize) ?u8 {
            if (mappable > 255) return null;
            return @intCast(mappable);
        }
    }.mapOrNullFunc;

    var array = [_]usize{ 1, 2, 3, 256, 255 };

    const mapped = try map(usize, u8, std.testing.allocator, &array, mapFunc);
    defer std.testing.allocator.free(mapped);

    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 255, 255 }, mapped);

    const mapped_or_ignored = try map(usize, u8, std.testing.allocator, &array, mapOrNullFunc);
    defer std.testing.allocator.free(mapped_or_ignored);

    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 255 }, mapped_or_ignored);
}

test reduce {
    const sum = struct {
        pub fn sum(accumulator: usize, mappable: usize) usize {
            return accumulator + mappable;
        }
    }.sum;

    var array = [_]usize{ 1, 2, 3 };

    const summed = reduce(usize, usize, &array, 0, sum);
    try std.testing.expectEqual(@as(usize, 6), summed);
}

test filter {
    const largerThan10 = struct {
        pub fn largerThan10(item: usize) bool {
            return item > 10;
        }
    }.largerThan10;

    var array = [_]usize{ 1, 12, 3, 14 };

    const filtered = try filter(usize, std.testing.allocator, &array, largerThan10);
    defer std.testing.allocator.free(filtered);

    try std.testing.expectEqualSlices(usize, &.{ 12, 14 }, filtered);
}

test forEach {
    const s = struct {
        pub var counter: usize = 0;

        pub fn forEachFn(item: usize) !void {
            counter += item;
        }
    };

    var array = [_]usize{ 1, 2, 3 };

    try forEach(usize, &array, s.forEachFn);

    try std.testing.expectEqual(@as(usize, 6), s.counter);
}
