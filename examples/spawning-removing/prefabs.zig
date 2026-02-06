const std = @import("std");
const loom = @import("loom");

const Spawn = @import("components/spawn.zig");
const Spawned = @import("components/spawned.zig");

pub fn Spawner(comptime position: loom.Vector3) !loom.Prefab {
    return try loom.prefab("spawner", .{
        loom.Transform{
            .position = position,
            .rotation = 45,
        },
        loom.Renderer.sprite("./resources/loom_logo_43x16.png"),
        loom.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),
        Spawn{
            .entityFactory = SpawnTarget,
        },
    });
}

pub fn SpawnTarget(position: loom.Vector2) !*loom.Entity {
    return try loom.makeEntityI("spawned", Spawned.alive, .{
        loom.Transform{
            .position = loom.vec2ToVec3(position),
            // .rotation = 45,
        },
        loom.Renderer.sprite("./resources/loom_logo_43x16.png"),
        loom.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{
                .rotation = 90,
            },
        }),
        Spawned{},
    });
}
