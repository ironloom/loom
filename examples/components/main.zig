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
            loom.prefabs(&.{
                try prefabs.Dummy(.init(0, 0)),
            });
        });
    });
}
