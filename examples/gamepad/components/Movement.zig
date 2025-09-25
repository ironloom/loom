const std = @import("std");
const lm = @import("loom");

const Self = @This();

const SPEED: comptime_float = 330;

transform: ?*lm.Transform = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Update(self: *Self) !void {
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);

    if (!lm.gamepad.isAvailable(0)) {
        lm.ui.new(.{
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
            lm.ui.text("No Controller detected", .{
                .letter_spacing = 3,
                .font_size = 30,
            });
            lm.ui.text("Connect a Controller to play...", .{
                .letter_spacing = 3,
            });
        });
        return;
    }

    lm.ui.new(.{
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
        lm.ui.text("Press B to reload...", .{
            .letter_spacing = 3,
        });
        lm.ui.text("Move with the Left Analog Stick", .{
            .letter_spacing = 3,
        });
    });

    const movement_vector = lm.input.gamepad.getStickVector(0, .left, 0.1);

    transform.position = transform.position.add(lm.vec2ToVec3(
        movement_vector
            .multiply(lm.time.deltaTimeVector2())
            .multiply(.init(SPEED, SPEED)),
    ));

    if (lm.gamepad.getButtonDown(0, .right_face_right)) {
        try lm.loadScene("default");
    }
}
