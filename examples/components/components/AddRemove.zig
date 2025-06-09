const std = @import("std");
const loom = @import("loom");

const Self = @This();

pub fn Update(entity: *loom.Entity) !void {
    if (loom.input.getKeyDown(.f)) {
        try loom.loadScene("default");
    }

    loom.ui.new(.{
        .id = .ID("press-f"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = 36, .y = 36 },
        },
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = 36,
        },
    })({
        loom.ui.text("Press F to reload...", .{
            .letter_spacing = 3,
        });
        loom.ui.text("Press W to add Renderer", .{
            .letter_spacing = 3,
        });
        loom.ui.text("Press S to remove Renderer", .{
            .letter_spacing = 3,
        });
    });

    if (loom.input.getKeyDown(.w)) {
        try entity.addComponent(loom.Renderer.sprite("./resources/loom_logo_43x16.png"));
    }

    if (loom.input.getKeyDown(.s)) {
        entity.removeComponent(loom.Renderer);
    }
}
