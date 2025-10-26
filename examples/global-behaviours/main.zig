const std = @import("std");
const loom = @import("loom");

const prefabs = @import("prefabs.zig");

const Organiser = @import("./globals/organiser.zig");

pub fn main() !void {
    loom.project(.{
        .window = .{
            .title = "loom example: spawning / removing",
            .resizable = true,
        },
        .asset_paths = .{ .debug = "./" },
    })({
        loom.scene("default")({
            loom.useMainCamera();

            loom.globalBehaviours(.{
                Organiser{ .entity = prefabs.SpawnTarget },
            });
        });
    });
}
