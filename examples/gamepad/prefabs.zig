const std = @import("std");
const loom = @import("loom");

const Movement = @import("components/Movement.zig");

pub fn Dummy(comptime position: loom.Vector2) !loom.Prefab {
    return try loom.prefab("spawner", .{
        loom.Transform{
            .position = loom.vec2ToVec3(position),
        },
        loom.Renderer.sprite("./resources/loom_logo_43x16.png"),
        Movement{},
    });
}
