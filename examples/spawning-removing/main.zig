const std = @import("std");
const loom = @import("loom");

const prefabs = @import("prefabs.zig");

pub fn main() !void {
    loom.project(.{
        .window = .{
            .title = "loom example: spawning / removing",
            .resizable = true,
        },
        .asset_paths = .{ .debug = "./" },
    })({
        loom.scene("default")({
            loom.prefabs(&.{
                try prefabs.Spawner(.init(
                    640,
                    360,
                    0,
                )),
            });
        });
    });
}
