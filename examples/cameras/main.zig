const std = @import("std");
const loom = @import("loom");

const prefabs = @import("prefabs.zig");

pub fn main() !void {
    loom.project(.{
        .window = .{
            .title = "loom - gamepad demo",
            .resizable = true,
        },
        .asset_paths = .{ .debug = "./" },
    })({
        loom.scene("default")({
            loom.prefabs(&.{
                try prefabs.Player(.init(0, 0)),

                try prefabs.CameraDummy(.init(128, 0)),
                try prefabs.Dummy(.init(-128, 0), "1"),
                try prefabs.Dummy(.init(0, 128), "2"),
                try prefabs.Dummy(.init(0, -128), "3"),
            });

            loom.cameras(&.{
                .{ .id = "main", .options = .{
                    .display = .fullscreen,
                    .draw_mode = .world,
                } },
                .{ .id = "other", .options = .{
                    .display = .partial(.init(0, 0, 400, 300)),
                    .draw_mode = .world,
                    .shader = "./resources/shaders/scanlines.fs",
                    .clear_color = .purple,
                } },
            });
        });
    });
}
