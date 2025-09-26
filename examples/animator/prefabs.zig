const std = @import("std");
const lm = @import("loom");

const Move = @import("components/Move.zig");

pub fn MovingBox(comptime position: lm.Vector2) !lm.Prefab {
    return try lm.prefab("spawner", .{
        lm.Transform{
            .position = lm.vec2ToVec3(position),
        },
        lm.Renderer.init(.{
            .img_path = "./resources/loom_logo_43x16.png",
            .fill_color = .black,
        }),
        lm.Animator.init(&.{
            lm.Animation.init("move", 5, lm.interpolation.lerp, &.{
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = -256,
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = 256,
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = 256,
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                },
            }),
        }),

        lm.CameraTarget.init("main", .{
            .max_distance = 1000000,
        }),

        Move{},
    });
}