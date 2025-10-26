const std = @import("std");
const lm = @import("loom");

const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;
const expectEqualStrings = testing.expectEqualStrings;
const allocator = testing.allocator;

const SceneController = lm.eventloop.SceneController;
const Scene = lm.eventloop.Scene;

test "init / deinit" {
    var my_controller = SceneController.init(allocator);
    defer my_controller.deinit();

    try expectEqual(0, my_controller.scenes.len());
}

test "addScene" {
    var my_controller = SceneController.init(allocator);
    defer my_controller.deinit();

    try expectEqual(0, my_controller.scenes.len());

    const my_scene = Scene.init(allocator, "my_scene");

    try my_controller.addScene(my_scene);

    try expectEqual(1, my_controller.scenes.len());
}

test "addSceneOpen" {
    var my_controller = SceneController.init(allocator);
    defer my_controller.deinit();

    try expectEqual(0, my_controller.scenes.len());

    const my_scene = Scene.init(allocator, "my_scene");

    (try my_controller.addSceneOpen(my_scene))({
        try expect(my_controller.open_scene != null);
    });
    try expect(my_controller.open_scene == null);

    try expectEqual(1, my_controller.scenes.len());
}

test "setActive" {
    var my_controller = SceneController.init(allocator);
    defer my_controller.deinit();

    const my_scene = Scene.init(allocator, "my_scene");

    try my_controller.addScene(my_scene);

    try expect(my_controller.active_scene == null);
    try expect(my_controller.next_scene == null);

    try expectError(
        SceneController.Error.SceneNotFound,
        my_controller.setActive("non_existent_scene"),
    );
    try my_controller.setActive("my_scene");

    try expect(my_controller.active_scene == null);
    try expect(my_controller.next_scene != null);

    my_controller.execute();

    try expect(my_controller.active_scene != null);
    try expect(my_controller.next_scene == null);
}

test "execute" {
    const Counter = struct {
        const Self = @This();

        pub var counter: usize = 0;

        pub fn Awake() void {
            counter += 1;
        }
        pub fn Start() void {
            counter += 1;
        }
        pub fn Update() void {
            counter += 1;
        }
        pub fn End() void {
            counter += 1;
        }
    };

    var my_controller = SceneController.init(allocator);
    defer my_controller.deinit();

    const other_scene = Scene.init(allocator, "other_scene");
    const my_scene = Scene.init(allocator, "my_scene");

    try my_controller.addScene(other_scene);
    (try my_controller.addSceneOpen(my_scene))({
        const scene = my_controller.open_scene orelse unreachable;

        try scene.useGlobalBehaviours(.{
            Counter{},
        });
    });

    try expectEqual(0, Counter.counter);

    try my_controller.setActive("my_scene");
    my_controller.execute();

    try expectEqual(3, Counter.counter);

    try my_controller.setActive("other_scene");
    my_controller.execute();

    try expectEqual(4, Counter.counter);
}

test "loadNext" {
    var my_controller = SceneController.init(allocator);
    defer my_controller.deinit();

    const other_scene = Scene.init(allocator, "other_scene");
    const my_scene = Scene.init(allocator, "my_scene");

    try my_controller.addScene(other_scene);

    try my_controller.addScene(my_scene);

    try expect(my_controller.active_scene == null);
    try expect(my_controller.next_scene == null);

    try my_controller.setActive("my_scene");

    try expect(my_controller.active_scene == null);
    try expect(my_controller.next_scene != null);

    my_controller.loadNext();

    try expect(my_controller.active_scene != null);
    try expect(my_controller.next_scene == null);
}
