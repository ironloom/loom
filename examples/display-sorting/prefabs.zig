const std = @import("std");
const loom = @import("loom");

const Move = @import("components/Move.zig");

pub fn MovingBox(comptime position: loom.Vector2) !loom.Prefab {
    return try loom.prefab("spawner", .{
        loom.Transform{
            .position = loom.vec2ToVec3(position),
        },
        loom.Renderer.init(.{
            .img_path = "./resources/loom_logo_43x16.png",
            .fill_color = .black,
        }),
        Move{},
    });
}

pub fn StillBox(comptime position: loom.Vector2) !loom.Prefab {
    return try loom.prefab("spawned", .{
        loom.Transform{
            .position = loom.vec2ToVec3(position),
        },
        loom.Renderer.init(.{
            .img_path = "./resources/loom_logo_43x16.png",
            .fill_color = .lime,
        }),
    });
}
