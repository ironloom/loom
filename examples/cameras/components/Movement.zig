const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Self = @This();

const SPEED: comptime_float = 330;

transform: ?*lm.Transform = null,
camera: ?*lm.Camera = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.camera = lm.activeScene().?.getCamera("main");
}

pub fn Update(self: *Self) !void {
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);

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
        if (lm.gamepad.isAvailable(0)) {
            lm.ui.text("Press B to reload...", .{
                .letter_spacing = 3,
            });
            lm.ui.text("Move with the Left Analog Stick", .{
                .letter_spacing = 3,
            });
        } else {
            lm.ui.text("Move around with WASD", .{
                .letter_spacing = 3,
            });
        }
    });

    const ui_pos = camera.worldToScreenPos(lm.vec3ToVec2(transform.position)).subtract(.init(48, 48));

    lm.ui.new(.{
        .id = .ID("player-tag"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = ui_pos.x, .y = ui_pos.y },
        },
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = 36,
            .sizing = .{
                .w = .fixed(96),
                .h = .fixed(16),
            },
            .child_alignment = .center,
        },
    })({
        lm.ui.text("Player", .{
            .letter_spacing = 3,
            .alignment = .center,
        });
    });

    var movement_vector = lm.input.gamepad.getStickVector(0, .left, 0.1);

    if (lm.keyboard.getKey(.w)) {
        movement_vector.y = -1;
    }
    if (lm.keyboard.getKey(.s)) {
        movement_vector.y = 1;
    }
    if (lm.keyboard.getKey(.a)) {
        movement_vector.x = -1;
    }
    if (lm.keyboard.getKey(.d)) {
        movement_vector.x = 1;
    }

    transform.position = transform.position.add(lm.vec2ToVec3(
        movement_vector
            .normalize()
            .multiply(lm.time.deltaTimeVector2())
            .multiply(.init(SPEED, SPEED)),
    ));

    if (lm.gamepad.getButtonDown(0, .right_face_right) or
        lm.keyboard.getKeyDown(.f))
    {
        try lm.loadScene("default");
    }
}
