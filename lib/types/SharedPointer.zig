const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub fn SharedPointer(comptime T: type) type {
    return struct {
        const Error = error{
            NonZeroReferenceCount,
        };
        const Self = @This();

        alloc: Allocator,
        value: ?T = null,
        ref_count: usize = 0,

        pub fn create(allocator: Allocator, val: T) !*Self {
            const ptr = try allocator.create(Self);
            ptr.* = Self{
                .value = val,
                .alloc = allocator,
            };

            return ptr;
        }

        pub fn destroy(self: *Self) !void {
            if (self.ref_count > 0) return Error.NonZeroReferenceCount;

            const alloc = self.alloc;
            self.* = undefined;

            alloc.destroy(self);
        }

        pub fn getRef(self: *Self) ?*T {
            self.ref_count += 1;
            return &(self.value orelse return null);
        }

        pub fn removeRef(self: *Self) void {
            if (self.ref_count == 0) return;
            self.ref_count -= 1;

            if (self.ref_count == 0) self.value = null;
        }
    };
}
