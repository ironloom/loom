const std = @import("std");
const loom = @import("loom");

const AddRemove = @import("components/AddRemove.zig");

pub fn Dummy(comptime position: loom.Vector2) !loom.Prefab {
    return try loom.prefab("spawner", .{
        loom.Transform{
            .position = loom.vec2ToVec3(position),
        },
        AddRemove{},
    });
}
