const std = @import("std");
const loom = @import("loom");

const Spawn = @import("components/spawn.zig");
const SpawnedComponent = @import("components/spawned.zig");

pub fn Spawner(position: loom.Vector3) !loom.Prefab {
    return try loom.prefab("spawner", .{
        loom.Transform{
            .position = position,
        },
        loom.Renderer.init("./resources/loom_logo_43x16.png"),
        loom.RectangleCollider.init(.{}),
        Spawn{
            .prefab = Spawned,
        },
    });
}

pub fn Spawned(position: loom.Vector2) !loom.Prefab {
    return try loom.prefab("spawned", .{
        loom.Transform{
            .position = loom.vec2ToVec3(position),
        },
        loom.Renderer.init("./resources/loom_logo_43x16.png"),
        loom.RectangleCollider.init(.{}),
        SpawnedComponent{},
    });
}
