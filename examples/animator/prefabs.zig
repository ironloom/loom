const std = @import("std");
const lm = @import("loom");

const Move = @import("components/Move.zig");

pub fn MovingBox(comptime position: lm.Vector2) !lm.Prefab {
    return try lm.prefab("spawner", .{
        lm.Transform{
            .position = lm.vec2ToVec3(position),
        },
        lm.Renderer.init(.{
            .img_path = "example_1.png",
        }),
        lm.Animator.init(&.{
            lm.Animation.init("move", 5, lm.interpolation.lerp, &.{
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                    .sprite = "example_1.png",
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = -256,
                    .sprite = "example_2.png",
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = 256,
                    .sprite = "example_1.png",
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = 256,
                    .sprite = "example_2.png",
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                    .sprite = "example_1.png",
                },
            }),
            lm.Animation.init("move-ease-in", 5, lm.interpolation.ease_in, &.{
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                    .sprite = "example_1.png",
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = -256,
                    .sprite = "example_2.png",
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = 256,
                    .sprite = "example_1.png",
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = 256,
                    .sprite = "example_2.png",
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                    .sprite = "example_1.png",
                },
            }),
            lm.Animation.init("move-ease-out", 5, lm.interpolation.ease_out, &.{
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                    .sprite = "example_1.png",
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = -256,
                    .sprite = "example_2.png",
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = 256,
                    .sprite = "example_1.png",
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = 256,
                    .sprite = "example_2.png",
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                    .sprite = "example_1.png",
                },
            }),
            lm.Animation.init("move-ease-in-out", 5, lm.interpolation.ease_in_out, &.{
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                    .sprite = "example_1.png",
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = -256,
                    .sprite = "example_2.png",
                },
                lm.Keyframe{
                    .pos_y = 256,
                    .pos_x = 256,
                    .sprite = "example_1.png",
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = 256,
                    .sprite = "example_2.png",
                },
                lm.Keyframe{
                    .pos_y = -256,
                    .pos_x = -256,
                    .sprite = "example_1.png",
                },
            }),
        }),

        lm.CameraTarget.init("main", .{
            .max_distance = 1000000,
        }),

        Move{},
    });
}
