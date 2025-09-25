const std = @import("std");
const loom = @import("../root.zig");
const rl = loom.rl;

const Transform = @import("./Transform.zig");

const Self = @This();

transform: ?*Transform = null,
max_distance: f32 = 0,
min_distance: f32 = 0,
follow_speed: f32 = 1,
camera: ?*loom.Camera = null,
camera_id: []const u8,

pub fn init(camera_id: []const u8, config: struct {
    max_distance: f32 = 0,
    min_distance: f32 = 0,
    follow_speed: f32 = 1,
}) Self {
    return Self{
        .camera_id = camera_id,
        .max_distance = config.max_distance,
        .min_distance = config.min_distance,
        .follow_speed = config.follow_speed,
    };
}

pub fn Awake(self: *Self, entity: *loom.Entity) !void {
    const transform = entity.getComponent(Transform) orelse Blk: {
        try entity.addComponent(Transform{});
        break :Blk entity.getComponent(Transform).?;
    };

    self.transform = transform;
}

pub fn Start(self: *Self) !void {
    self.camera = try loom.ensureComponent(loom.activeScene().?.getCamera(self.camera_id));
}

pub fn Update(self: *Self, _: *loom.Entity) !void {
    const transform = self.transform orelse return;
    const camera: *loom.Camera = try loom.ensureComponent(self.camera);

    camera.offset = loom.Vec2(
        camera.render_texture.texture.width,
        camera.render_texture.texture.height,
    ).divide(.init(2, 2));

    const delta = loom.vec3ToVec2(transform.position).subtract(camera.target);
    if (delta.length() < self.min_distance) return;

    const max_distance_position = loom.vec3ToVec2(transform.position).add(
        delta
            .negate()
            .normalize()
            .multiply(loom.Vec2(self.max_distance, self.max_distance)),
    );

    const movement = delta
        .normalize()
        .multiply(loom.Vec2(self.follow_speed, self.follow_speed))
        .multiply(loom.time.deltaTimeVector2());

    if (movement.length() > delta.length()) {
        camera.target = camera.target.add(delta);
        return;
    }

    if (delta.length() > self.max_distance) {
        camera.target = max_distance_position;
        return;
    }

    camera.target = camera.target.add(movement);
}
