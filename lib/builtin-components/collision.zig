const std = @import("std");
const loom = @import("../root.zig");
const rl = loom.rl;

const Transform = @import("./Transform.zig");
const Vector2 = loom.Vector2;

pub const RectangleCollider = struct {
    /// ```
    /// A +---------+ B
    ///   |    * O  |
    /// D +---------+ C
    /// ```
    /// ABCD Rectangle, with O center. O is the position A;B;C;D are relative to.
    const Vertices = struct {
        A: Vector2,
        B: Vector2,
        C: Vector2,
        D: Vector2,

        pub fn init(scale: Vector2, sin_theta: f32, cos_theta: f32) Vertices {
            const half_width = scale.x / 2;
            const half_height = scale.y / 2;

            var A: Vector2 = .init(
                (-1 * half_width) * cos_theta - (-1 * half_height) * sin_theta,
                (-1 * half_width) * sin_theta + (-1 * half_height) * cos_theta,
            );

            var B: Vector2 = .init(
                half_width * cos_theta - (-1 * half_height) * sin_theta,
                half_width * sin_theta + (-1 * half_height) * cos_theta,
            );

            const C: Vector2 = A.negate();
            const D: Vector2 = B.negate();

            return Vertices{
                .A = A,
                .B = B,
                .C = C,
                .D = D,
            };
        }

        pub fn zero() Vertices {
            return Vertices{
                .A = .init(0, 0),
                .B = .init(0, 0),
                .C = .init(0, 0),
                .D = .init(0, 0),
            };
        }

        pub fn getAxes(self: Vertices) [4]Vector2 {
            const AB = self.B.subtract(self.A);
            const BC = self.C.subtract(self.B);

            return [4]Vector2{
                AB.normalize(),
                BC.normalize(),
                AB.normalize().negate(),
                BC.normalize().negate(),
            };
        }
    };

    const ColliderType = enum {
        static,
        dynamic,
        trigger,
        passtrough,
    };

    const Self = @This();
    var collidables: ?loom.List(*Self) = null;

    collider_transform: Transform,
    type: ColliderType = .static,
    weight: f32 = 1,
    onCollision: ?*const fn (self: *loom.Entity, other: *loom.Entity) anyerror!void = null,

    entity: *loom.Entity = undefined,

    last_collider_transform: Transform = .{},
    transform: ?*Transform = null,
    last_transform: ?Transform = null,

    deltas: Vertices = .zero(),
    points: ?Vertices = null,

    sin_theta: f32 = 0,
    cos_theta: f32 = 0,

    pub fn R(self: *Self) f32 {
        return std.math.hypot(self.collider_transform.scale.x / 2, self.collider_transform.scale.y / 2);
    }

    pub fn center(self: *Self) !Vector2 {
        const transform: *Transform = try loom.ensureComponent(self.transform);

        return loom.vec3ToVec2(transform.position.add(self.collider_transform.position));
    }

    pub fn init(collider_transform: Transform) Self {
        return Self{
            .collider_transform = collider_transform,
            .last_collider_transform = collider_transform,
        };
    }

    pub fn initConfig(config: struct {
        transform: Transform = .{},
        type: ColliderType = .static,
        weight: f32 = 1,
        onCollidion: ?*const fn (self: *loom.Entity, other: *loom.Entity) anyerror!void = null,
    }) Self {
        return Self{
            .collider_transform = config.transform,
            .last_collider_transform = config.transform,
            .type = config.type,
            .weight = config.weight,
            .onCollision = config.onCollidion,
        };
    }

    pub fn recalculateRotation(self: *Self) !void {
        const transform: *Transform = try loom.ensureComponent(self.transform);
        const theta = transform.rotation + self.collider_transform.rotation;

        self.sin_theta = @sin(std.math.degreesToRadians(theta));
        self.cos_theta = @cos(std.math.degreesToRadians(theta));
    }

    pub fn recalculateDeltas(self: *Self) void {
        self.deltas = .init(self.collider_transform.scale, self.sin_theta, self.cos_theta);
    }

    pub fn recalculatePoints(self: *Self) !void {
        const transform: *Transform = try loom.ensureComponent(self.transform);

        self.points = Vertices{
            .A = self.deltas.A.add(loom.vec3ToVec2(transform.position)).add(loom.vec3ToVec2(self.collider_transform.position)),
            .B = self.deltas.B.add(loom.vec3ToVec2(transform.position)).add(loom.vec3ToVec2(self.collider_transform.position)),
            .C = self.deltas.C.add(loom.vec3ToVec2(transform.position)).add(loom.vec3ToVec2(self.collider_transform.position)),
            .D = self.deltas.D.add(loom.vec3ToVec2(transform.position)).add(loom.vec3ToVec2(self.collider_transform.position)),
        };
    }

    fn checkOverlapOnAxis(rect1_points: Vertices, rect2_points: Vertices, axis: Vector2) bool {
        var min1: f32 = std.math.floatMax(f32);
        var max1: f32 = std.math.floatMin(f32);
        var min2: f32 = std.math.floatMax(f32);
        var max2: f32 = std.math.floatMin(f32);

        const points1 = [4]Vector2{ rect1_points.A, rect1_points.B, rect1_points.C, rect1_points.D };
        for (points1) |point| {
            const projection = point.dotProduct(axis);
            if (projection < min1) min1 = projection;
            if (projection > max1) max1 = projection;
        }

        const points2 = [4]Vector2{ rect2_points.A, rect2_points.B, rect2_points.C, rect2_points.D };
        for (points2) |point| {
            const projection = point.dotProduct(axis);
            if (projection < min2) min2 = projection;
            if (projection > max2) max2 = projection;
        }

        return (max1 >= min2 and max2 >= min1);
    }

    pub fn getOverlap(self: *Self, other: *Self) ?Vector2 {
        const self_points = self.points orelse return null;
        const other_points = other.points orelse return null;

        const axes1 = self_points.getAxes();
        const axes2 = other_points.getAxes();

        var min_overlap: f32 = std.math.floatMax(f32);
        var minimum_translation_vector: Vector2 = .init(0, 0);

        const all_axes = [8]Vector2{
            axes1[0], axes1[1], axes1[2], axes1[3],
            axes2[0], axes2[1], axes2[2], axes2[3],
        };

        for (all_axes) |axis| {
            var min1: f32 = std.math.floatMax(f32);
            var max1: f32 = std.math.floatMin(f32);
            var min2: f32 = std.math.floatMax(f32);
            var max2: f32 = std.math.floatMin(f32);

            const points1 = [4]Vector2{ self_points.A, self_points.B, self_points.C, self_points.D };
            for (points1) |point| {
                const projection = point.dotProduct(axis);
                if (projection < min1) min1 = projection;
                if (projection > max1) max1 = projection;
            }

            const points2 = [4]Vector2{ other_points.A, other_points.B, other_points.C, other_points.D };
            for (points2) |point| {
                const projection = point.dotProduct(axis);
                if (projection < min2) min2 = projection;
                if (projection > max2) max2 = projection;
            }

            if (!(max1 >= min2 and max2 >= min1)) {
                return null;
            }

            const overlap = @min(max1, max2) - @max(min1, min2);
            if (overlap < min_overlap) {
                min_overlap = overlap;
                minimum_translation_vector = axis.multiply(loom.Vec2(overlap, overlap));
            }
        }

        const self_center = self.center() catch return null;
        const other_center = other.center() catch return null;
        const center_diff = self_center.subtract(other_center);
        if (minimum_translation_vector.dotProduct(center_diff) < 0) {
            minimum_translation_vector = minimum_translation_vector.negate();
        }

        return minimum_translation_vector;
    }

    pub fn overlaps(self: *Self, other: *Self) bool {
        const self_points = self.points orelse return false;
        const other_points = other.points orelse return false;

        const axes1 = self_points.getAxes();
        const axes2 = other_points.getAxes();

        for (axes1) |axis| {
            if (!RectangleCollider.checkOverlapOnAxis(self_points, other_points, axis)) {
                return false;
            }
        }

        for (axes2) |axis| {
            if (!RectangleCollider.checkOverlapOnAxis(self_points, other_points, axis)) {
                return false;
            }
        }

        return true;
    }

    pub fn pushback(a: *Self, b: *Self, weight: f32) !void {
        const a_transform: *Transform = try loom.ensureComponent(a.transform);

        const overlap_vector = a.getOverlap(b) orelse return;

        a_transform.position.x += overlap_vector.x * weight;
        a_transform.position.y += overlap_vector.y * weight;
    }

    pub fn Awake(self: *Self, entity: *loom.Entity) !void {
        self.entity = entity;
        self.last_collider_transform = self.collider_transform;

        if (collidables == null) {
            collidables = .init(loom.allocators.generic());
        }
        try collidables.?.append(self);
    }

    pub fn Start(self: *Self, entity: *loom.Entity) !void {
        self.transform = try entity.pullComponent(Transform);
        self.last_transform = self.transform.?.*;

        try self.recalculateRotation();
        self.recalculateDeltas();
        try self.recalculatePoints();
    }

    pub fn Update(self: *Self, entity: *loom.Entity) !void {
        const colliders = collidables orelse return error.CollidablesWasNotInitalised;

        if (self.type != .dynamic and self.type != .trigger) return;

        const self_transform: *Transform = try loom.ensureComponent(self.transform);
        const self_last_transform = self.last_transform orelse blk: {
            self.last_transform = self_transform.*;
            break :blk self.last_transform.?;
        };
        const self_center = try self.center();

        defer {
            self.last_transform = self_transform.*;
            self.last_collider_transform = self.collider_transform;
        }

        if (self_last_transform.rotation != self_transform.rotation or self.collider_transform.rotation != self.last_collider_transform.rotation) {
            try self.recalculateRotation();
            self.recalculateDeltas();
            try self.recalculatePoints();
        } else if (self.collider_transform.scale.equals(self.last_collider_transform.scale) == 0) {
            self.recalculateDeltas();
            try self.recalculatePoints();
        } else if (self_last_transform.position.equals(self_transform.position) == 0 or self.last_collider_transform.position.equals(self.collider_transform.position) == 0)
            try self.recalculatePoints();

        for (colliders.items()) |other| {
            if (other.entity.uuid == self.entity.uuid) continue;
            if (other.type == .trigger) continue;
            if (other.type == .passtrough and self.type != .trigger) continue;

            const other_transform: *Transform = try loom.ensureComponent(other.transform);
            const other_last_transform = other.last_transform orelse blk: {
                other.last_transform = other_transform.*;
                break :blk other.last_transform.?;
            };

            const other_center = try other.center();

            if (self.R() + other.R() < std.math.hypot(self_center.x - other_center.x, self_center.y - other_center.y)) continue;

            if (other_last_transform.rotation != other_transform.rotation or other.collider_transform.rotation != other.last_collider_transform.rotation) {
                try other.recalculateRotation();
                other.recalculateDeltas();
                try other.recalculatePoints();
            } else if (other.collider_transform.scale.equals(other.last_collider_transform.scale) == 0) {
                other.recalculateDeltas();
                try other.recalculatePoints();
            } else if (other_last_transform.position.equals(other_transform.position) == 0 or other.last_collider_transform.position.equals(other.collider_transform.position) == 0)
                try other.recalculatePoints();

            if (!self.overlaps(other)) continue;

            if (self.onCollision) |onCollision|
                onCollision(entity, other.entity) catch |err| {
                    std.log.err("onCollidion returned an error on entity: {s}@{x} when colliding with {s}@{x}", .{ entity.id, entity.uuid, other.entity.id, other.entity.uuid });
                    std.log.err("{any}", .{err});
                };

            if (self.type == .trigger) continue;
            if (other.type != .dynamic) {
                try self.pushback(other, 1);
                continue;
            }

            const combined_weight = self.weight + other.weight;
            const self_mult = 1 - self.weight / combined_weight;
            const other_mult = 1 - self_mult;

            try self.pushback(other, self_mult);
            try other.pushback(self, other_mult);
        }
    }

    pub fn End(self: *Self) !void {
        const colliders = &(collidables orelse return);
        for (colliders.items(), 0..) |item, index| {
            if (item != self) continue;
            _ = colliders.swapRemove(index);
            break;
        }

        if (colliders.len() == 0) {
            colliders.deinit();
            collidables = null;
        }
    }
};
