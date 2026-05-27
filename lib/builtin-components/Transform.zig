const std = @import("std");
const loom = @import("../root.zig");

const Self = @This();

position: loom.Vector3 = loom.Vec3(0, 0, 0),
rotation: f32 = 0,
scale: loom.Vector2 = loom.Vec2(64, 64),

pub const zero: Self = .{
    .position = .init(0, 0, 0),
    .rotation = 0,
    .scale = .init(0, 0),
};

pub fn eql(self: Self, other: Self) bool {
    if (self.position.equals(other.position) == 0) return false;
    return eqlSkipPosition(self, other);
}

pub fn eqlSkipPosition(self: Self, other: Self) bool {
    return self.rotation == other.rotation and self.scale.equals(other.scale);
}

pub fn distance(self: Self, other: Self) f32 {
    return @sqrt(std.math.pow(f32, (self.position.x - other.position.x), 2) +
        std.math.pow(f32, (self.position.y - other.position.y), 2) +
        std.math.pow(f32, (self.position.z - other.position.z), 2));
}

pub fn distance2D(self: Self, other: Self) f32 {
    return std.math.hypot(self.position.x - other.position.x, self.position.y - other.position.y);
}
