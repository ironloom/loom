const std = @import("std");
const lm = @import("loom");

const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;
const expectEqualStrings = testing.expectEqualStrings;
const allocator = testing.allocator;

const Scene = lm.eventloop.Scene;

test "init / deinit" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    try expectEqualStrings("my_scene", my_scene.id);
    try expect(0 != my_scene.uuid);

    try expectEqual(0, my_scene.prefabs.len());

    try expectEqual(0, my_scene.entities.len());
    try expectEqual(0, my_scene.new_entities.len());

    try expectEqual(0, my_scene.behaviours.len());

    try expectEqual(0, my_scene.cameras.len());
    try expectEqual(0, my_scene.default_cameras.len());
}

test "addPrefab" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    try expectEqual(0, my_scene.prefabs.len());

    const my_prefab = try lm.Prefab.init("my_prefab", .{});
    try my_scene.addPrefab(my_prefab);

    try expectEqual(1, my_scene.prefabs.len());
}

test "addPrefabs" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    try expectEqual(0, my_scene.prefabs.len());

    const my_prefab = try lm.Prefab.init("my_prefab", .{});
    const my_other_prefab = try lm.Prefab.init("my_other_prefab", .{});

    try my_scene.addPrefabs(&.{ my_prefab, my_other_prefab });

    try expectEqual(2, my_scene.prefabs.len());
}

test "newEntity" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    try expectEqual(0, my_scene.entities.len());
    try expectEqual(0, my_scene.new_entities.len());

    try my_scene.newEntity("my_entity", .{});

    try expectEqual(0, my_scene.entities.len());
    try expectEqual(1, my_scene.new_entities.len());

    my_scene.execute();

    try expectEqual(1, my_scene.entities.len());
    try expectEqual(0, my_scene.new_entities.len());
}

test "addEntity" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    try expectEqual(0, my_scene.entities.len());
    try expectEqual(0, my_scene.new_entities.len());

    const my_entity = try lm.Entity.create(my_scene.alloc, "my_entity");
    try my_scene.addEntity(my_entity);

    try expectEqual(0, my_scene.entities.len());
    try expectEqual(1, my_scene.new_entities.len());

    my_scene.execute();

    try expectEqual(1, my_scene.entities.len());
    try expectEqual(0, my_scene.new_entities.len());
}

test "getEntity" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    const my_entity = try lm.Entity.create(my_scene.alloc, "my_entity");
    try my_scene.addEntity(my_entity);

    my_scene.execute();

    const result_id = my_scene.getEntityById("my_entity");
    const result_uuid = my_scene.getEntityByUuid(my_entity.uuid);

    try expect(result_id != null);
    try expect(result_uuid != null);

    try expectEqual(result_id, result_uuid);
    try expectEqualStrings("my_entity", result_id.?.id);
    try expectEqualStrings("my_entity", result_uuid.?.id);
}

test "removeEntity" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    {
        const my_entity = try lm.Entity.create(my_scene.alloc, "my_entity");
        try my_scene.addEntity(my_entity);

        my_scene.execute();

        try expectEqual(1, my_scene.entities.len());

        my_scene.removeEntityById("my_entity");

        try expectEqual(1, my_scene.entities.len());

        my_scene.execute();

        try expectEqual(0, my_scene.entities.len());
    }
    {
        const my_entity = try lm.Entity.create(my_scene.alloc, "my_entity");
        try my_scene.addEntity(my_entity);

        my_scene.execute();

        try expectEqual(1, my_scene.entities.len());

        my_scene.removeEntityByUuid(my_entity.uuid);

        try expectEqual(1, my_scene.entities.len());

        my_scene.execute();

        try expectEqual(0, my_scene.entities.len());
    }
    {
        const my_entity = try lm.Entity.create(my_scene.alloc, "my_entity");
        try my_scene.addEntity(my_entity);

        my_scene.execute();

        try expectEqual(1, my_scene.entities.len());

        my_scene.removeEntityByPtr(my_entity);

        try expectEqual(1, my_scene.entities.len());

        my_scene.execute();

        try expectEqual(0, my_scene.entities.len());
    }
}

test "isEntityAlive" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    {
        const my_entity = try lm.Entity.create(my_scene.alloc, "my_entity");
        try my_scene.addEntity(my_entity);

        try expect(!my_scene.isEntityAliveId("my_entity"));

        my_scene.execute();

        try expect(my_scene.isEntityAliveId("my_entity"));

        my_scene.removeEntityById("my_entity");

        try expect(my_scene.isEntityAliveId("my_entity"));

        my_scene.execute();

        try expect(!my_scene.isEntityAliveId("my_entity"));
    }
    {
        const my_entity = try lm.Entity.create(my_scene.alloc, "my_entity");
        try my_scene.addEntity(my_entity);

        const uuid = my_entity.uuid;

        try expect(!my_scene.isEntityAliveUuid(uuid));

        my_scene.execute();

        try expect(my_scene.isEntityAliveUuid(uuid));

        my_scene.removeEntityById("my_entity");

        try expect(my_scene.isEntityAliveUuid(uuid));

        my_scene.execute();

        try expect(!my_scene.isEntityAliveUuid(uuid));
    }
    {
        const my_entity = try lm.Entity.create(my_scene.alloc, "my_entity");
        try my_scene.addEntity(my_entity);

        try expect(!my_scene.isEntityAlivePtr(my_entity));

        my_scene.execute();

        try expect(my_scene.isEntityAlivePtr(my_entity));

        my_scene.removeEntityById("my_entity");

        try expect(my_scene.isEntityAlivePtr(my_entity));

        my_scene.execute();

        try expect(!my_scene.isEntityAlivePtr(my_entity));
    }
}

test "useGlobalBehaviours" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    my_scene.is_active = true;

    try expectError(error.SceneActive, my_scene.useGlobalBehaviours(.{}));

    my_scene.is_active = false;
    var u8_behaviour = try lm.GlobalBehaviour.init(@as(u8, 47));

    try my_scene.default_behaviours.append(&u8_behaviour);
    try expectEqual(1, my_scene.default_behaviours.len());

    try my_scene.useGlobalBehaviours(.{});

    try expectEqual(0, my_scene.default_behaviours.len());

    try my_scene.useGlobalBehaviours(.{
        @as(u8, 47),
        @as(u32, 69),
    });

    try expectEqual(2, my_scene.default_behaviours.len());
}

test "useDefaultCameras" {
    var my_scene: Scene = .init(allocator, "my_scene");
    defer my_scene.deinit();

    try expectEqual(0, my_scene.default_cameras.len());

    try my_scene.useDefaultCameras(&.{
        lm.CameraConfig{
            .id = "my_camera",
            .options = .{
                .display = .fullscreen,
                .draw_mode = .world,
            },
        },
    });

    try expectEqual(1, my_scene.default_cameras.len());

    try my_scene.useDefaultCameras(&.{});

    try expectEqual(0, my_scene.default_cameras.len());
}
