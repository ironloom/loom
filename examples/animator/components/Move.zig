const std = @import("std");
const lm = @import("loom");

const Self = @This();

animator: ?*lm.Animator = null,

pub fn Start(self: *Self, entity: *lm.Entity) !void {
    self.animator = try entity.pullComponent(lm.Animator);
}

pub fn Update(self: *Self) !void {
    const animator: *lm.Animator = try lm.ensureComponent(self.animator);

    if (lm.keyboard.getKeyDown(.f)) {
        animator.stop("move");
        try animator.play("move");
    }

    lm.ui.new(.{
        .id = .ID("press-f"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = 36, .y = 36 },
        },
    })({
        lm.ui.text("Press F to reload...", .{
            .letter_spacing = 3,
        });
    });

    if (!animator.isPlaying("move"))
        try animator.play("move");
}
