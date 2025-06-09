const std = @import("std");
const loom = @import("../root.zig");
const Allocator = @import("std").mem.Allocator;

const Entity = @import("./Entity.zig");

pub const PrefabFn = *const fn (Allocator) anyerror!*Entity;
const Self = @This();

id: []const u8,
components: *anyopaque,

addComponents: *const fn (entity: *Entity, ptr: *anyopaque) anyerror!void,

pub fn init(id: []const u8, components: anytype) !Self {
    const cptr = try loom.allocators.c.create(@TypeOf(components));
    cptr.* = components;

    return Self{
        .id = id,
        .components = cptr,
        .addComponents = struct {
            pub fn callback(entity: *Entity, ptr: *anyopaque) !void {
                const component_ptr: *@TypeOf(components) = @ptrCast(@alignCast(ptr));

                try entity.addComponents(component_ptr.*);
            }
        }.callback,
    };
}

pub fn makeInstance(self: Self) !*Entity {
    const ptr = try Entity.create(loom.allocators.scene(), self.id);
    try self.addComponents(ptr, self.components);

    return ptr;
}

pub fn deinit(self: Self) void {
    loom.allocators.c.free(self.components);
}
