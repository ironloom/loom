const std = @import("std");
const loom = @import("../root.zig");
const rl = loom.rl;

const Transform = @import("./Transform.zig");
const Vector2 = loom.Vector2;

pub const RectangleCollider = struct {
    const MinMax = struct {
        x_min: f32 = 0,
        x_max: f32 = 0,

        y_min: f32 = 0,
        y_max: f32 = 0,
    };

    /// ```
    /// A +---------+ B
    ///   |    * O  |
    /// D +---------+ C
    /// ```
    /// ABCD Rectangle, with O center. O is the position A;B;C;D are relative to.
    const Vertices = struct {
        A: Vector2, // top-left
        B: Vector2, // top-right
        C: Vector2, // bottom-right
        D: Vector2, // bottom-left

        pub fn init(scale: Vector2, sin_theta: f32, cos_theta: f32) Vertices {
            const half_width = scale.x / 2;
            const half_height = scale.y / 2;

            var A: Vector2 = .init(-1 * half_width, -1 * half_height);
            {
                A.x = A.x * cos_theta - A.y * sin_theta;
                A.y = A.x * sin_theta + A.y * cos_theta;
            }

            var B: Vector2 = .init(half_width, -1 * half_height);
            {
                B.x = B.x * cos_theta - B.y * sin_theta;
                B.y = B.x * sin_theta + B.y * cos_theta;
            }

            var C: Vector2 = .init(half_width, half_height);
            {
                C.x = C.x * cos_theta - C.y * sin_theta;
                C.y = C.x * sin_theta + C.y * cos_theta;
            }

            var D: Vector2 = .init(-1 * half_width, half_height);
            {
                D.x = D.x * cos_theta - D.y * sin_theta;
                D.y = D.x * sin_theta + D.y * cos_theta;
            }

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

        pub fn getMinMax(self: Vertices) MinMax {
            return MinMax{
                .x_min = @min(@min(self.A.x, self.B.x), @min(self.C.x, self.D.x)),
                .x_max = @max(@max(self.A.x, self.B.x), @max(self.C.x, self.D.x)),
                .y_min = @min(@min(self.A.y, self.B.y), @min(self.C.y, self.D.y)),
                .y_max = @max(@max(self.A.y, self.B.y), @max(self.C.y, self.D.y)),
            };
        }
    };

    const Self = @This();
    var collidables: ?std.ArrayList(*Self) = null;

    collider_transform: Transform,
    type: enum {
        static,
        dynamic,
        trigger,
        passtrough,
    } = .static,
    weight: f32 = 1,
    onCollision: ?*const fn (self: *loom.Entity, other: *loom.Entity) anyerror!void = null,

    entity: *loom.Entity = undefined,

    last_collider_transform: Transform = .{},
    transform: ?*Transform = null,
    last_transform: ?Transform = null,

    deltas: Vertices = .zero(),
    points: ?Vertices = null,
    minmax: ?MinMax = null,

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

    pub fn overlaps(self: *Self, other: *Self) bool {
        const self_minmax = self.minmax orelse return false;
        const other_minmax = other.minmax orelse return false;

        if ((self_minmax.x_max > other_minmax.x_min and self_minmax.x_min < other_minmax.x_max) and
            (self_minmax.y_max > other_minmax.y_min and self_minmax.y_min < other_minmax.y_max))
            return true;
        return false;
    }

    pub fn pushback(a: *Self, b: *Self, weight: f32) !void {
        const a_transform: *Transform = try loom.ensureComponent(a.transform);

        const a_minmax = a.minmax orelse return;
        const b_minmax = b.minmax orelse return;

        const overlap_x = @min(a_minmax.x_max - b_minmax.x_min, b_minmax.x_max - a_minmax.x_min);
        const overlap_y = @min(a_minmax.y_max - b_minmax.y_min, b_minmax.y_max - a_minmax.y_min);

        switch (overlap_x < overlap_y) {
            true => PushBack_X: {
                if (a_minmax.x_max > b_minmax.x_min and a_minmax.x_max < b_minmax.x_max) {
                    a_transform.position.x -= overlap_x * weight;
                    break :PushBack_X;
                }

                a_transform.position.x += overlap_x * weight;
                break :PushBack_X;
            },
            false => PushBack_Y: {
                if (a_minmax.y_max > b_minmax.y_min and a_minmax.y_max < b_minmax.y_max) {
                    a_transform.position.y -= overlap_y * weight;
                    break :PushBack_Y;
                }

                a_transform.position.y += overlap_y * weight;
                break :PushBack_Y;
            },
        }
    }

    pub fn Awake(self: *Self, entity: *loom.Entity) !void {
        self.entity = entity;
        self.last_collider_transform = self.collider_transform;

        if (collidables == null) {
            collidables = .init(loom.allocators.scene());
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

        if (self_last_transform.rotation != self_transform.rotation or self.collider_transform.rotation != self.last_collider_transform.rotation)
            try self.recalculateRotation();

        if (self.collider_transform.scale.equals(self.last_collider_transform.scale) == 0)
            self.recalculateDeltas();

        if (self_last_transform.position.equals(self_transform.position) == 0 or self.last_collider_transform.position.equals(self.collider_transform.position) == 0)
            try self.recalculatePoints();

        const self_points = self.points orelse return;
        self.minmax = self_points.getMinMax();

        for (colliders.items) |other| {
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

            if (other_last_transform.rotation != other_transform.rotation or other.collider_transform.rotation != other.last_collider_transform.rotation)
                try other.recalculateRotation();

            if (other.collider_transform.scale.equals(other.last_collider_transform.scale) == 0)
                other.recalculateDeltas();

            if (other_last_transform.position.equals(other_transform.position) == 0 or other.last_collider_transform.position.equals(other.collider_transform.position) == 0)
                try other.recalculatePoints();

            const other_points = other.points orelse continue;
            other.minmax = other_points.getMinMax();

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
        for (colliders.items, 0..) |item, index| {
            if (item != self) continue;
            _ = colliders.swapRemove(index);
            break;
        }

        if (colliders.items.len == 0) {
            colliders.deinit();
            collidables = null;
        }
    }
};
