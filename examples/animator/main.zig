const std = @import("std");
const loom = @import("loom");

const prefabs = @import("prefabs.zig");

pub fn main() !void {
    loom.project(.{
        .window = .{
            .resizable = true,
        },
        .asset_paths = .{ .debug = "./" },
    })({
        loom.scene("default")({
            loom.useMainCamera();
            loom.prefabs(&.{
                try prefabs.MovingBox(.{ .x = 0, .y = -300 }),
            });
        });
    });
}
