const std = @import("std");
const lm = @import("loom");

const Self = @This();

const animations: []const []const u8 = &.{ "move", "move-ease-in", "move-ease-out", "move-ease-in-out" };

animator: ?*lm.Animator = null,
current_animation: []const u8 = "move",

pub fn Start(self: *Self, entity: *lm.Entity) !void {
    self.animator = try entity.pullComponent(lm.Animator);
}

pub fn Update(self: *Self) !void {
    const animator: *lm.Animator = try lm.ensureComponent(self.animator);

    if (lm.keyboard.getKeyDown(.f)) {
        animator.stop(self.current_animation);
        try self.playNewAnimation();
    }

    lm.ui.new(.{
        .id = .ID("press-f"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = 36, .y = 36 },
        },
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = 10,
        },
    })({
        lm.ui.text("Press F to reload...", .{
            .letter_spacing = 3,
        });
        lm.ui.textFmt("Playing: {s}", .{self.current_animation}, .{ .letter_spacing = 3 });
    });

    if (!animator.isPlaying(self.current_animation))
        try self.playNewAnimation();
}

fn playNewAnimation(self: *Self) !void {
    const animator: *lm.Animator = try lm.ensureComponent(self.animator);
    const anim = animations[lm.random.intRangeAtMost(usize, 0, animations.len - 1)];
    self.current_animation = anim;

    try animator.play(anim);
}
