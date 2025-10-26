const std = @import("std");
const lm = @import("loom");

const prefabs = @import("prefabs.zig");

pub fn main() !void {
    lm.project(.{
        .window = .{
            .title = "loom example: spawning / removing",
            .resizable = true,
        },
        .asset_paths = .{ .debug = "./" },
    })({
        lm.scene("default")({
            lm.useMainCamera();

            lm.prefabs(&.{
                try prefabs.Spawner(.init(
                    640,
                    360,
                    0,
                )),
            });
        });
    });
}
