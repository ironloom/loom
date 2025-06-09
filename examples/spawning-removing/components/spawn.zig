const std = @import("std");
const loom = @import("loom");

const Self = @This();

prefab: *const fn (position: loom.Vector2) anyerror!loom.Prefab,
amount: usize = 10,

pub fn Start(self: *Self) !void {
    for (0..self.amount) |_| {
        try loom.summon(&.{.{
            .prefab_auto_deinit = try self.prefab(loom.Vec2(
                loom.random.intRangeAtMost(isize, -640, 640),
                loom.random.intRangeAtMost(isize, -320, 320),
            )),
        }});
    }
}

pub fn Update() !void {
    if (loom.input.getKeyDown(.f)) {
        try loom.loadScene("default");
    }
}
