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
                    loom.tof32(loom.random.intRangeAtMost(i32, -600, 600)),
                    loom.tof32(loom.random.intRangeAtMost(i32, -300, 300)),
                    0,
                )),
            });
        });
    });
}
