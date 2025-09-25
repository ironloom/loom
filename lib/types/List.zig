const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Array = @import("Array.zig").Array;

pub fn List(comptime T: type) type {
    return struct {
        const Self = @This();

        arrlist: std.ArrayList(T),
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .arrlist = .empty,
                .allocator = allocator,
            };
        }

        pub fn fromArray(array: Array(T)) Self {
            return Self{
                .arrlist = try array.toArrayList(),
                .allocator = array.alloc,
            };
        }

        pub fn deinit(self: *Self) void {
            self.arrlist.deinit(self.allocator);
        }

        pub inline fn items(self: Self) []T {
            return self.arrlist.items;
        }

        pub inline fn len(self: Self) usize {
            return self.arrlist.items.len;
        }

        pub fn append(self: *Self, item: T) !void {
            try self.arrlist.append(self.allocator, item);
        }

        pub fn clearAndFree(self: *Self) void {
            self.arrlist.clearAndFree(self.allocator);
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.arrlist.clearRetainingCapacity();
        }

        pub fn clone(self: *Self) !Self {
            return Self{
                .allocator = self.allocator,
                .arrlist = try self.arrlist.clone(self.allocator),
            };
        }

        pub fn getLast(self: Self) T {
            return self.arrlist.getLast();
        }

        pub fn getLastOrNull(self: Self) ?T {
            return self.arrlist.getLastOrNull();
        }

        pub fn getFirst(self: Self) T {
            return self.items()[0];
        }

        pub fn getFirstOrNull(self: Self) ?T {
            return if (self.len() > 0) self.items()[0] else null;
        }

        pub fn orderedRemove(self: *Self, index: usize) T {
            return self.arrlist.orderedRemove(index);
        }

        pub fn orderedRemoveMany(self: *Self, indexes: []const usize) void {
            self.arrlist.orderedRemoveMany(indexes);
        }

        pub fn swapRemove(self: *Self, index: usize) T {
            return self.arrlist.swapRemove(index);
        }

        pub fn pop(self: *Self) ?T {
            return self.arrlist.pop();
        }

        pub fn resize(self: *Self, new_len: usize) !void {
            try self.resize(self.allocator, new_len);
        }

        pub fn shrinkAndFree(self: *Self, new_len: usize) void {
            self.arrlist.shrinkAndFree(self.allocator, new_len);
        }

        pub fn toOwnedSlice(self: *Self) ![]T {
            return try self.arrlist.toOwnedSlice(self.allocator);
        }

        pub fn cloneToOwnedSlice(self: *Self) ![]T {
            var cloned = try self.clone();
            return try cloned.toOwnedSlice();
        }

        pub fn toArray(self: *Self) !Array(T) {
            return try .fromArrayList(self.allocator, self.arrlist);
        }
    };
}
