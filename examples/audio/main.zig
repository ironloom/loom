const std = @import("std");
const loom = @import("loom");

const Organiser = @import("./globals/organiser.zig");

pub fn main() !void {
    loom.project(.{
        .window = .{
            .title = "loom example: spawning / removing",
            .resizable = true,
            .restore_state = true,
        },
        .asset_paths = .{ .debug = "./resources/" },
    })({
        loom.scene("default")({
            loom.useMainCamera();

            loom.globalBehaviours(.{
                Organiser{},
            });
        });
    });
}
