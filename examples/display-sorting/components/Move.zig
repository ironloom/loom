const std = @import("std");
const loom = @import("loom");

const Self = @This();

transform: ?*loom.Transform = null,

pub fn Start(self: *Self, entity: *loom.Entity) !void {
    self.transform = try entity.pullComponent(loom.Transform);
}

pub fn Update(self: *Self) !void {
    const transform: *loom.Transform = try loom.ensureComponent(self.transform);

    if (loom.input.getKeyDown(.f)) {
        try loom.loadScene("default");
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

    transform.position.y += 100 * loom.time.deltaTime();
}
