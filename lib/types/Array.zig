const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const List = @import("List.zig").List;
const iterator_functions = @import("iterator_functions.zig");

const coerceTo = @import("type_switcher.zig").coerceTo;

pub fn cloneArrayListToOwnedSlice(comptime T: type, allocator: std.mem.Allocator, list: std.ArrayList(T)) ![]T {
    var cloned = try list.clone(allocator);
    return try cloned.toOwnedSlice(allocator);
}

pub const ArrayOptions = struct {
    allocator: Allocator = std.heap.page_allocator,

    try_type_change: bool = true,
    on_type_change_fail: enum {
        ignore,
        err,
        panic,
    } = .err,
};

pub fn Array(comptime T: type) type {
    return struct {
        const Self = @This();
        const Error = error{
            IncorrectElementType,
            TypeChangeFailiure,
        };

        alloc: Allocator = std.heap.page_allocator,
        slice: []T,

        pub fn init(allocator: std.mem.Allocator, initial_items: []const T) !Self {
            const allocated = try allocator.alloc(T, initial_items.len);
            std.mem.copyForwards(T, allocated, initial_items);

            return Self{
                .alloc = allocator,
                .slice = allocated,
            };
        }

        pub fn fromArrayList(allocator: Allocator, arr: std.ArrayList(T)) !Self {
            return Self{
                .slice = try cloneArrayListToOwnedSlice(T, allocator, arr),
                .alloc = allocator,
            };
        }

        pub fn fromList(list: List(T)) !Self {
            return try Self.fromArrayList(list.allocator, list.arrlist);
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.slice);
            self.* = undefined;
        }

        pub inline fn items(self: Self) []T {
            return self.slice;
        }

        pub inline fn len(self: Self) usize {
            return self.slice.len;
        }

        fn getSafeIndex(self: Self, index: anytype) ?usize {
            var _index = coerceTo(isize, index) orelse return null;

            if (_index < 0) _index = @as(isize, @intCast(self.len())) + _index;

            if (self.len() == 0 or _index > self.len() - 1 or _index < 0)
                return null;

            return @intCast(@max(0, _index));
        }

        pub inline fn at(self: Self, index: anytype) ?T {
            return self.slice[self.getSafeIndex(index) orelse return null];
        }

        pub fn clone(self: Self) !Self {
            const new = try self.alloc.alloc(T, self.slice.len);
            std.mem.copyForwards(T, new, self.slice);

            return Self{
                .slice = new,
                .alloc = self.alloc,
            };
        }

        pub fn eql(self: Self, other: Self) bool {
            if (self.len() != other.len()) return false;

            for (0..self.len()) |index| {
                if (!std.meta.eql(self.at(index), other.at(index)))
                    return false;
            }

            return true;
        }

        pub fn set(self: *Self, index: anytype, value: T) void {
            self.slice[self.getSafeIndex(index) orelse return] = value;
        }

        pub inline fn getFirst(self: Self) T {
            return self.slice[0];
        }

        pub inline fn getLast(self: Self) T {
            return self.slice[self.len() - 1];
        }

        pub inline fn getFirstOrNull(self: Self) ?T {
            return self.at(0);
        }

        pub inline fn getLastOrNull(self: Self) ?T {
            return self.at(-1);
        }

        pub fn clearAndFree(self: *Self) void {
            self.alloc.free(self.slice);
            self.slice.len = 0;
        }

        /// Caller owns the returned memory. Does empty the array. Makes `deinit` safe, but unnecessary to call.
        pub fn toOwnedSlice(self: *Self) ![]T {
            const new_slice = try self.alloc.alloc(T, self.len());
            @memcpy(new_slice, self.slice);
            self.clearAndFree();

            return new_slice;
        }

        pub fn cloneToOwnedSlice(self: Self) ![]T {
            const new_slice = try self.alloc.alloc(T, self.len());
            @memcpy(new_slice, self.slice);

            return new_slice;
        }

        pub fn toArrayList(self: Self) !std.ArrayList(T) {
            var list = try std.ArrayList(T).initCapacity(self.alloc, self.len());
            try list.appendSlice(self.alloc, self.items());

            return list;
        }

        pub inline fn toList(self: Self) !List(T) {
            return .fromArray(self);
        }

        pub inline fn map(self: Self, R: type, mapping_function: iterator_functions.MappingFn(T, R)) !Array(R) {
            return Array(R){
                .alloc = self.alloc,
                .slice = try iterator_functions.map(
                    T,
                    R,
                    self.alloc,
                    self.items(),
                    mapping_function,
                ),
            };
        }

        pub inline fn reduce(self: Self, R: type, initial: R, reduce_function: iterator_functions.ReduceFn(T, R)) R {
            return iterator_functions.reduce(T, R, self.items(), initial, reduce_function);
        }

        pub inline fn filter(self: Self, criteria: iterator_functions.FilterCriteriaFn(T)) !Self {
            return Self{
                .alloc = self.alloc,
                .slice = try iterator_functions.filter(
                    T,
                    self.alloc,
                    self.items(),
                    criteria,
                ),
            };
        }

        pub inline fn forEach(self: Self, foreach_function: iterator_functions.ForEachFn(T)) !void {
            try iterator_functions.forEach(T, self.items(), foreach_function);
        }
    };
}

pub fn array(comptime T: type, items: []const T) Array(T) {
    return Array(T).init(std.heap.smp_allocator, items) catch unreachable;
}

pub fn arrayAdvanced(
    comptime T: type,
    allocator: Allocator,
    tuple: []const T,
) Array(T) {
    return Array(T).init(
        allocator,
        tuple,
    ) catch unreachable;
}

test "init" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, my_array.items());
}

test "fromArrayList" {
    var array_list: std.ArrayList(u8) = .empty;
    defer array_list.deinit(std.testing.allocator);

    for (0..10) |item| {
        try array_list.append(std.testing.allocator, @intCast(item));
    }

    var my_array = try Array(u8).fromArrayList(std.testing.allocator, array_list);
    defer my_array.deinit();

    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, my_array.items());
}

test "fromList" {
    var list: List(u8) = try .initWithItems(std.testing.allocator, &.{ 1, 2, 3 });
    defer list.deinit();

    var my_array: Array(u8) = try .fromList(list);
    defer my_array.deinit();

    try std.testing.expectEqualSlices(u8, list.items(), my_array.items());
}

test "items" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expectEqualSlices(u8, my_array.slice, my_array.items());
}

test "len" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expect(my_array.len() == 3);
    try std.testing.expect(my_array.len() == my_array.slice.len);
}

test "at" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expectEqual(my_array.at(1), @as(u8, 2));
    try std.testing.expectEqual(my_array.at(1), my_array.slice[1]);

    try std.testing.expectEqual(my_array.at(-1), @as(u8, 3));
    try std.testing.expectEqual(my_array.at(-1), my_array.slice[my_array.len() - 1]);

    try std.testing.expect(my_array.at(-4) == null);
    try std.testing.expect(my_array.at(4) == null);
}

test "clone" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    var cloned = try my_array.clone();
    defer cloned.deinit();

    try std.testing.expectEqualSlices(u8, my_array.items(), cloned.items());
}

test "eql" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    var different_len_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3, 4 });
    defer different_len_array.deinit();

    var not_equal_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 4 });
    defer not_equal_array.deinit();

    var equal = try my_array.clone();
    defer equal.deinit();

    try std.testing.expect(!my_array.eql(different_len_array));
    try std.testing.expect(!my_array.eql(not_equal_array));
    try std.testing.expect(my_array.eql(equal));
}

test "set" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, my_array.items());

    my_array.set(0, 0);
    my_array.set(-1, 0);

    my_array.set(-4, 0);
    my_array.set(4, 0);

    try std.testing.expectEqualSlices(u8, &.{ 0, 2, 0 }, my_array.items());
}

test "getFirst" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expectEqual(@as(u8, 1), my_array.getFirst());
}

test "getLast" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expectEqual(@as(u8, 3), my_array.getLast());
    try std.testing.expectEqual(my_array.at(-1), my_array.getLast());
    try std.testing.expectEqual(my_array.items()[my_array.len() - 1], my_array.getLast());
}

test "getFirstOrNull" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expectEqual(@as(u8, 1), my_array.getFirstOrNull());

    var empty = try Array(u8).init(std.testing.allocator, &.{});
    defer empty.deinit();

    try std.testing.expect(empty.getFirstOrNull() == null);
}

test "getLastOrNull" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expectEqual(@as(u8, 3), my_array.getLastOrNull());

    var empty = try Array(u8).init(std.testing.allocator, &.{});
    defer empty.deinit();

    try std.testing.expect(empty.getLastOrNull() == null);
}

test "clearAndFree" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    try std.testing.expect(my_array.len() == 3);

    my_array.clearAndFree();

    try std.testing.expect(my_array.len() == 0);
}

test "toOwnedSlice" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    const owned_slice = try my_array.toOwnedSlice();
    defer my_array.alloc.free(owned_slice);

    try std.testing.expect(my_array.len() == 0);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, owned_slice);
}

test "cloneToOwnedSlice" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    const owned_slice = try my_array.cloneToOwnedSlice();
    defer std.testing.allocator.free(owned_slice);

    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, my_array.items());
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, owned_slice);
}

test "toArrayList" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    var my_array_list = try my_array.toArrayList();
    defer my_array_list.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u8, my_array.items(), my_array_list.items);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, my_array_list.items);
}

test "toList" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3 });
    defer my_array.deinit();

    var my_list = try my_array.toList();
    defer my_list.deinit();

    try std.testing.expectEqualSlices(u8, my_array.items(), my_list.items());
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, my_list.items());
}

test "map" {
    var my_array = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3, 4, 5 });
    defer my_array.deinit();

    var squared = try my_array.map(usize, struct {
        pub fn callback(item: u8) ?usize {
            return std.math.pow(usize, @intCast(item), 2);
        }
    }.callback);
    defer squared.deinit();

    try std.testing.expectEqualSlices(usize, &.{ 1, 4, 9, 16, 25 }, squared.items());

    var squared_odds = try my_array.map(usize, struct {
        pub fn callback(item: u8) ?usize {
            if (@rem(item, 2) == 0) return null;

            return std.math.pow(usize, @intCast(item), 2);
        }
    }.callback);
    defer squared_odds.deinit();

    try std.testing.expectEqualSlices(usize, &.{ 1, 9, 25 }, squared_odds.items());
}

test "reduce" {
    const sum = struct {
        pub fn sum(accumulator: u8, mappable: u8) u8 {
            return accumulator + mappable;
        }
    }.sum;

    var test_list = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3, 4, 5 });
    defer test_list.deinit();

    const summed = test_list.reduce(u8, 0, sum);

    try std.testing.expectEqual(summed, @as(u8, 1 + 2 + 3 + 4 + 5));
}

test "filter" {
    const onlyEven = struct {
        pub fn callback(item: u8) bool {
            return @rem(item, 2) == 0;
        }
    }.callback;

    var test_list = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3, 4, 5 });
    defer test_list.deinit();

    var only_even = try test_list.filter(onlyEven);
    defer only_even.deinit();

    try std.testing.expectEqualSlices(u8, &.{ 2, 4 }, only_even.items());
}

test "forEach" {
    const s = struct {
        pub var counter: u8 = 0;

        pub fn forEachFn(item: u8) !void {
            counter += item;
        }

        pub fn errorForeach(_: u8) !void {
            return error.MyError;
        }
    };

    var test_list = try Array(u8).init(std.testing.allocator, &.{ 1, 2, 3, 4, 5 });
    defer test_list.deinit();

    try test_list.forEach(s.forEachFn);

    try std.testing.expectError(error.MyError, test_list.forEach(s.errorForeach));
    try std.testing.expectEqual(@as(usize, 15), s.counter);
}
