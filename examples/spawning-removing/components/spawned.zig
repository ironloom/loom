const std = @import("std");
const loom = @import("loom");

const Self = @This();

pub var alive: u32 = 0;

timeout: f32 = 3,
start_time: f32 = 0,

pub fn Awake(self: *Self) void {
    self.start_time = loom.time.appTime();
    self.timeout = loom.tof32(loom.random.intRangeAtMost(usize, 1, 4));

    alive += 1;
}

pub fn Update(self: *Self, entity: *loom.Entity) !void {
    if (self.timeout + self.start_time > loom.time.appTime()) return;

    loom.removeEntity(.byPtr(entity));
    alive -= 1;
}
