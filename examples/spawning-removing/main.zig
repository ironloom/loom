const std = @import("std");
const loom = @import("loom");

const prefabs = @import("prefabs.zig");

pub fn main() !void {
    loom.project({
        loom.window.size.set(.{ .x = 1280, .y = 720 });
        loom.window.clear_color = .white;
        loom.window.resizing.enable();

        loom.useAssetPaths(.{
            .debug = "./",
        });
    })({
        loom.scene("default")({
            loom.prefabs(.{
                try prefabs.Spawner(.init(
                    0,
                    0,
                    0,
                )),
            });
        });
    });
}
