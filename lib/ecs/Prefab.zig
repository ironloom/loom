const std = @import("std");
const loom = @import("../root.zig");
const Allocator = @import("std").mem.Allocator;

const Entity = @import("./Entity.zig");

pub const PrefabFn = *const fn (Allocator) anyerror!*Entity;
const Self = @This();

make_fn: *const fn () anyerror!*Entity,

pub fn init(comptime id: []const u8, comptime components: anytype) !Self {
    return Self{
        .make_fn = struct {
            pub fn callback() !*Entity {
                const ptr = try loom.allocators.scene().create(Entity);
                ptr.* = .init(loom.allocators.scene(), id);

                try ptr.addComponents(components);

                return ptr;
            }
        }.callback,
    };
}

pub fn makeInstance(self: Self) !*Entity {
    return try self.make_fn();
}
