const std = @import("std");
const lm = @import("loom");

const Move = @import("components/Move.zig");

pub fn MovingBox(comptime position: lm.Vector2) !lm.Prefab {
    return try lm.prefab("moving", .{
        lm.Transform{
            .position = lm.vec2ToVec3(position),
        },
        lm.Renderer.init(.{
            .img_path = "./resources/loom_logo_43x16.png",
            .fill_color = .black,
        }),
        Move{},
    });
}

pub fn StillBox(comptime position: lm.Vector2) !lm.Prefab {
    return try lm.prefab("normal", .{
        lm.Transform{
            .position = lm.vec2ToVec3(position),
        },
        lm.Renderer.init(.{
            .img_path = "./resources/loom_logo_43x16.png",
            .fill_color = .lime,
        }),
    });
}

pub fn CameraAnchor(comptime position: lm.Vector2) !lm.Prefab {
    return try lm.prefab("camera_anchor", .{
        lm.Transform{
            .position = lm.vec2ToVec3(position),
        },
        lm.CameraTarget.init("main", .{}),
    });
}
