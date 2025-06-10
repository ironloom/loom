const std = @import("std");
const loom = @import("loom");

const Self = @This();

entity: *const fn (position: loom.Vector2) anyerror!*loom.Entity,
amount: usize = 100,

pub fn Update(self: *Self, scene: *loom.Scene) !void {
    if (loom.input.getKeyDown(.f)) {
        for (0..self.amount) |_| {
            try scene.addEntity(try self.entity(loom.Vec2(
                loom.random.intRangeAtMost(isize, -640, 640),
                loom.random.intRangeAtMost(isize, -320, 320),
            )));
        }
    }

    loom.ui.new(.{
        .id = .ID("press-f"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = 36, .y = 36 },
        },
    })({
        loom.ui.text("Press F to reload...", .{
            .letter_spacing = 3,
        });
    });
}
