const std = @import("std");
const lm = @import("loom");

const Movement = @import("components/Movement.zig");

pub fn Player(comptime position: lm.Vector2) !lm.Prefab {
    return try lm.prefab("spawner", .{
        lm.Transform{
            .position = lm.vec2ToVec3(position),
        },
        lm.Renderer.sprite("./resources/loom_logo_43x16.png"),
        lm.CameraTarget.init("main", .{
            .max_distance = 128,
            .follow_speed = 128,
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),

        Movement{},
    });
}

pub fn Dummy(comptime position: lm.Vector2, comptime string_id: []const u8) !lm.Prefab {
    return try lm.prefab("dummy" ++ string_id, .{
        lm.Transform{
            .position = lm.vec2ToVec3(position),
        },
        lm.Renderer.init(.{
            .fill_color = .purple,
            .img_path = "./resources/loom_logo_43x16.png",
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),
    });
}

pub fn CameraDummy(comptime position: lm.Vector2) !lm.Prefab {
    return try lm.prefab("camera-dummy", .{
        lm.Transform{
            .position = lm.vec2ToVec3(position),
        },
        lm.Renderer.init(.{
            .fill_color = .red,
            .img_path = "./resources/loom_logo_43x16.png",
        }),

        lm.CameraTarget.init("other", .{}),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),
    });
}
