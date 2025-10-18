const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const lm = @import("../root.zig");
const Entity = lm.Entity;
const GlobalBehaviour = lm.GlobalBehaviour;
const Camera = lm.Camera;

const Self = @This();
var active: ?*Self = null;

id: []const u8,
uuid: u128,
alloc: Allocator,

prefabs: lm.List(lm.Prefab),
entities: lm.List(*Entity),
new_entities: lm.List(*Entity),

behaviours: lm.List(*GlobalBehaviour),
default_behaviours: lm.List(*GlobalBehaviour),

cameras: lm.List(*lm.Camera),
default_cameras: lm.List(lm.CameraConfig),

is_active: bool = false,

last_tick_at: f64 = 0,
ticks_per_second: u8 = 20,

pub fn init(allocator: Allocator, id: []const u8) Self {
    return Self{
        .id = id,
        .uuid = lm.UUIDv7(),
        .alloc = allocator,

        .prefabs = .init(allocator),

        .entities = .init(allocator),
        .new_entities = .init(allocator),

        .behaviours = .init(allocator),
        .default_behaviours = .init(allocator),

        .cameras = .init(allocator),
        .default_cameras = .init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.unload();

    self.prefabs.deinit();
    self.behaviours.deinit();

    const default_behaviours_len = self.default_behaviours.len();
    for (1..default_behaviours_len + 1) |j| {
        const index = default_behaviours_len - j;
        const item = self.default_behaviours.items()[index];

        item.deinit();
        self.alloc.destroy(item);

        _ = self.default_behaviours.swapRemove(index);
    }

    self.default_behaviours.deinit();

    for (self.cameras.items()) |camera| {
        camera.deinit();
        lm.allocators.generic().destroy(camera);
    }

    self.cameras.deinit();
    self.default_cameras.deinit();

    self.* = undefined;
}

pub fn load(self: *Self) !void {
    for (self.default_cameras.items()) |camera_config| {
        _ = try self.addCamera(camera_config.id, camera_config.options);
    }

    if (self.cameras.len() == 0) {
        _ = try self.addCamera("main", .{
            .display = .fullscreen,
            .draw_mode = .world,
        });
    }

    for (self.prefabs.items()) |prefabs| {
        const entity = try prefabs.makeInstance();
        try self.entities.append(entity);

        try entity.addPreparedComponents(false);
    }

    if (self.default_behaviours.len() != 0) {
        for (self.behaviours.items()) |behaviour| {
            behaviour.callSafe(.end, self);
        }

        const behaviour_len = self.behaviours.len();
        for (1..behaviour_len + 1) |j| {
            const index = behaviour_len - j;
            const item = self.behaviours.items()[index];

            item.deinit();
            _ = self.behaviours.swapRemove(index);
        }

        if (self.default_behaviours.len() <= self.behaviours.capacity()) {
            self.behaviours.clearRetainingCapacity();
        } else {
            self.behaviours.clearAndFree();
        }

        for (self.default_behaviours.items()) |behaviour| {
            const ptr = try self.alloc.create(lm.GlobalBehaviour);
            ptr.* = try behaviour.duplicate();

            try self.behaviours.append(ptr);
        }
    }

    for (self.behaviours.items()) |behaviour| {
        behaviour.callSafe(.awake, self);
    }

    for (self.behaviours.items()) |behaviour| {
        behaviour.callSafe(.start, self);
    }

    for (self.entities.items()) |entity| {
        entity.dispatchEvent(.awake);
    }

    for (self.entities.items()) |entity| {
        entity.dispatchEvent(.start);
    }

    self.is_active = true;
}

pub fn unload(self: *Self) void {
    for (self.entities.items()) |item| {
        item.remove_next_frame = true;
        item.dispatchEvent(.end);
    }

    for (self.behaviours.items()) |behaviour| {
        behaviour.callSafe(.end, self);
    }

    const behaviour_len = self.behaviours.len();
    for (1..behaviour_len + 1) |j| {
        const index = behaviour_len - j;
        const item = self.behaviours.items()[index];

        item.deinit();
        self.alloc.destroy(item);

        _ = self.behaviours.swapRemove(index);
    }

    const entities_len = self.entities.len();
    for (1..entities_len + 1) |j| {
        const index = entities_len - j;
        const item = self.entities.items()[index];

        item.destroy();
        _ = self.entities.swapRemove(index);
    }

    const new_entities_len = self.new_entities.len();
    for (1..new_entities_len + 1) |j| {
        const index = new_entities_len - j;
        const item = self.new_entities.items()[index];

        item.destroy();
        _ = self.new_entities.swapRemove(index);
    }

    self.entities.clearAndFree();
    self.new_entities.clearAndFree();
    self.is_active = false;

    for (self.cameras.items()) |camera| {
        camera.deinit();
        lm.allocators.generic().destroy(camera);
    }

    self.cameras.clearAndFree();
}

pub fn execute(self: *Self) void {
    const is_tick = self.last_tick_at + 1.0 / lm.tof64(self.ticks_per_second) <= lm.time.appTime();

    for (self.behaviours.items()) |behaviour| {
        behaviour.callSafe(.update, self);

        if (is_tick) behaviour.callSafe(.tick, self);
    }

    for (self.new_entities.items()) |entity| {
        if (entity.remove_next_frame) continue;
        self.entities.append(entity) catch |err| {
            std.log.err("failed to add entity, error: {any}", .{err});
            continue;
        };

        entity.addPreparedComponents(true) catch |err| {
            std.log.err("failed to add components to entity, error: {any}", .{err});
            continue;
        };
    }
    self.new_entities.clearAndFree();

    const len = self.entities.len();
    for (1..len + 1) |b| {
        const index = len - b;
        const entity: *Entity = self.entities.items()[index];

        if (!entity.remove_next_frame) continue;

        entity.dispatchEvent(.end);

        entity.destroy();
        _ = self.entities.swapRemove(index);
    }

    for (self.entities.items()) |entity| {
        entity.addPreparedComponents(true) catch {};
        entity.dispatchEvent(.update);

        if (is_tick) {
            entity.dispatchEvent(.tick);
            self.last_tick_at = lm.time.gameTime();
        }
    }
}

pub fn addPrefab(self: *Self, prefab: lm.Prefab) !void {
    try self.prefabs.append(prefab);
}

pub fn addPrefabs(self: *Self, prefabs: []const lm.Prefab) !void {
    for (prefabs) |prefab| {
        try self.addPrefab(prefab);
    }
}

pub fn newEntity(self: *Self, id: []const u8, component_tuple: anytype) !void {
    const entity = try lm.Entity.create(self.alloc, id);
    try entity.addComponents(component_tuple);

    try self.addEntity(entity);
}

pub fn addEntity(self: *Self, entity: *lm.Entity) !void {
    try self.new_entities.append(entity);
}

pub fn getEntity(self: *Self, value: anytype, eqls: *const fn (@TypeOf(value), *Entity) bool) ?*Entity {
    for (self.entities.items()) |entity| {
        if (eqls(value, entity)) return entity;
    }
    return null;
}

/// Removed the entity by the next frame, preventing use-after-free bugs in the same update cycle.
/// This will invalidate the entity's pointer on the next frame.
pub fn removeEntity(self: *Self, value: anytype, eqls: *const fn (@TypeOf(value), *Entity) bool) void {
    for (self.entities.items()) |entity| {
        if (!eqls(value, entity)) continue;

        entity.remove_next_frame = true;
        break;
    }
}

pub fn isEntityAlive(self: *Self, value: anytype, eqls: *const fn (@TypeOf(value), *Entity) bool) bool {
    for (self.entities.items()) |entity| {
        if (eqls(value, entity)) return true;
    }

    return false;
}

fn ptrEqls(comptime T: type) fn (ptr: *T, compareAgainst: *T) bool {
    return struct {
        pub fn callback(ptr: *T, entity: *T) bool {
            return @intFromPtr(ptr) == @intFromPtr(entity);
        }
    }.callback;
}
fn idEqls(comptime T: type) fn (string: []const u8, compareAgains: *T) bool {
    return struct {
        pub fn callback(string: []const u8, compareAgains: *T) bool {
            if (!@hasField(T, "id")) @compileError("invalid type for uuid check");

            return std.mem.eql(u8, string, @field(compareAgains, "id"));
        }
    }.callback;
}

fn uuidEqls(comptime T: type) fn (uuid: u128, compareAgains: *T) bool {
    return struct {
        pub fn callback(uuid: u128, compareAgains: *T) bool {
            if (!@hasField(T, "uuid")) @compileError("invalid type for uuid check");

            return uuid == @field(compareAgains, "uuid");
        }
    }.callback;
}

/// Removed the entity by the next frame, preventing use-after-free bugs in the same update cycle.
/// This will invalidate the entity's pointer on the next frame.
pub fn removeEntityByPtr(self: *Self, entity: *Entity) void {
    removeEntity(self, entity, ptrEqls(Entity));
}

/// Removed the entity by the next frame, preventing use-after-free bugs in the same update cycle.
/// This will invalidate the entity's pointer on the next frame.
pub fn removeEntityById(self: *Self, id: []const u8) void {
    removeEntity(self, id, idEqls(Entity));
}

/// Removed the entity by the next frame, preventing use-after-free bugs in the same update cycle.
/// This will invalidate the entity's pointer on the next frame.
pub fn removeEntityByUuid(self: *Self, uuid: u128) void {
    removeEntity(self, uuid, uuidEqls(Entity));
}

pub fn getEntityById(self: *Self, id: []const u8) ?*Entity {
    return getEntity(self, id, idEqls(Entity));
}

pub fn getEntityByUuid(self: *Self, uuid: u128) ?*Entity {
    return getEntity(self, uuid, uuidEqls(Entity));
}

pub fn isEntityAliveId(self: *Self, id: []const u8) bool {
    return isEntityAlive(self, id, idEqls(Entity));
}

pub fn isEntityAliveUuid(self: *Self, uuid: u128) bool {
    return isEntityAlive(self, uuid, uuidEqls(Entity));
}

pub fn isEntityAlivePtr(self: *Self, ptr: *Entity) bool {
    return isEntityAlive(self, ptr, ptrEqls(Entity));
}

pub fn useGlobalBehaviours(self: *Self, behaviour_tuple: anytype) !void {
    if (self.is_active) return error.SceneActive;

    const behaviour_len = self.default_behaviours.len();
    for (1..behaviour_len + 1) |j| {
        const index = behaviour_len - j;
        const item = self.default_behaviours.items()[index];

        item.deinit();
        _ = self.default_behaviours.swapRemove(index);
    }

    self.default_behaviours.clearAndFree();

    inline for (behaviour_tuple) |component| {
        const ptr = try self.alloc.create(GlobalBehaviour);
        ptr.* = try GlobalBehaviour.init(component);

        try self.default_behaviours.append(ptr);
    }
}

pub fn useDefaultCameras(self: *Self, config: []const lm.CameraConfig) !void {
    if (config.len <= self.default_cameras.capacity()) {
        self.default_cameras.clearRetainingCapacity();
    } else {
        self.default_behaviours.clearAndFree();
    }

    try self.default_cameras.appendSlice(config);
}

pub fn addCamera(self: *Self, id: []const u8, options: Camera.Options) !*Camera {
    const ptr = try lm.allocators.generic().create(Camera);
    ptr.* = try .init(id, options);

    try self.cameras.append(ptr);

    return ptr;
}

pub fn getCamera(self: *Self, value: anytype, byCriteria: fn (@TypeOf(value), *Camera) bool) ?*Camera {
    for (self.cameras.items()) |camera| {
        if (byCriteria(value, camera)) return camera;
    }
    return null;
}

pub fn getCameraById(self: *Self, id: []const u8) ?*Camera {
    return self.getCamera(id, idEqls(Camera));
}

pub fn getCameraByUuid(self: *Self, uuid: u128) ?*Camera {
    return self.getCamera(uuid, uuidEqls(Camera));
}

pub fn removeCamera(self: *Self, value: anytype, byCriteria: fn (Camera, @TypeOf(value)) bool) void {
    for (self.cameras.items(), 0..) |camera, index| {
        if (!byCriteria(camera, value)) continue;

        self.cameras.orderedRemove(index);
        camera.deinit();
        lm.allocators.generic().destroy(camera);
        return;
    }
}

pub fn removeCameraById(self: *Self, id: []const u8) void {
    self.removeCamera(id, struct {
        pub fn callback(camera: Camera, identifier: []const u8) !void {
            return std.mem.eql(u8, camera.id, identifier);
        }
    }.callback);
}

pub fn removeCameraByUuid(self: *Self, uuid_: u128) void {
    self.removeCamera(uuid_, struct {
        pub fn callback(camera: Camera, uuid__: []const u8) !void {
            return camera.uuid == uuid__;
        }
    }.callback);
}
