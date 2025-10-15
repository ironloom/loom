const std = @import("std");
const lm = @import("loom");

const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;
const expectEqualStrings = testing.expectEqualStrings;
const allocator = testing.allocator;

const Entity = lm.ecs.Entity;

test "init / deinit" {
    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try expectEqualStrings("my_entity", my_entity.id);
    try expect(my_entity.uuid != 0);

    try expectEqual(0, my_entity.prepared_components.len());
    try expectEqual(0, my_entity.components.len());
}

test "deinit - multiple components referencing each other at deinit" {
    const s = struct {
        const Component1 = struct {
            my_var: usize = 1,

            other: ?*Component2 = null,

            pub fn Start(self: *Component1, entity: *Entity) void {
                self.other = entity.getComponent(Component2);
            }

            pub fn End(self: *Component1) !void {
                const other: *Component2 = try lm.ensureComponent(self.other);
                other.my_var -= 1;

                try expect(other.my_var == 0);
            }
        };

        const Component2 = struct {
            my_var: usize = 1,

            other: ?*Component1 = null,

            pub fn Start(self: *Component2, entity: *Entity) void {
                self.other = entity.getComponent(Component1);
            }

            pub fn End(self: *Component2) !void {
                const other: *Component1 = try lm.ensureComponent(self.other);
                other.my_var -= 1;

                try expect(other.my_var == 0);
            }
        };
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try my_entity.addComponents(.{
        s.Component1{},
        s.Component2{},
    });

    try my_entity.addPreparedComponents(true);
}

test "create / destroy" {
    var my_entity = try Entity.create(allocator, "allocated");
    defer my_entity.destroy();

    try expectEqualStrings(my_entity.id, "allocated");
    try expect(my_entity.uuid != 0);
}

test "addPreparedComponents" {
    const TestComponent = struct {
        my_var: usize = 1,
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try expectEqual(0, my_entity.components.len());
    try expectEqual(0, my_entity.prepared_components.len());

    try my_entity.addComponent(TestComponent{});
    try expect(!my_entity.prepared_components.items()[0].initalised);

    try expectEqual(1, my_entity.prepared_components.len());

    try my_entity.addPreparedComponents(true);

    try expectEqual(1, my_entity.components.len());
    try expectEqual(0, my_entity.prepared_components.len());

    try expect(my_entity.components.items()[0].initalised);
}

test "addComponent" {
    const TestComponent = struct {
        my_var: usize = 1,
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try expectEqual(0, my_entity.prepared_components.len());

    try my_entity.addComponent(TestComponent{});

    try expectEqual(1, my_entity.prepared_components.len());
    try expectEqual(comptime lm.ecs.calculateHash(TestComponent), my_entity.prepared_components.items()[0].hash);
}

test "addComponents" {
    const Component1 = struct {
        my_var: usize = 1,
    };
    const Component2 = struct {
        my_var: usize = 2,
    };
    const Component3 = struct {
        my_var: usize = 3,
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try expectEqual(0, my_entity.prepared_components.len());

    try my_entity.addComponents(.{
        Component1{},
        Component2{},
        Component3{},
    });

    try expectEqual(3, my_entity.prepared_components.len());
    try expectEqual(comptime lm.ecs.calculateHash(Component1), my_entity.prepared_components.items()[0].hash);
    try expectEqual(comptime lm.ecs.calculateHash(Component2), my_entity.prepared_components.items()[1].hash);
    try expectEqual(comptime lm.ecs.calculateHash(Component3), my_entity.prepared_components.items()[2].hash);
}

test "getComponent" {
    const TestComponent = struct {
        my_var: usize = 1,
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try expect(my_entity.getComponent(TestComponent) == null);

    try my_entity.addComponent(TestComponent{});

    try expect(my_entity.getComponent(TestComponent) == null);

    try my_entity.addPreparedComponents(true);

    try expect(my_entity.getComponent(TestComponent) != null);
}

test "getComponentUnsafe" {
    const TestComponent = struct {
        my_var: usize = 1,
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try expectError(error.ComponentNotFound, my_entity.getComponentUnsafe(TestComponent).unwrap());

    try my_entity.addComponent(TestComponent{});

    try expect(my_entity.getComponentUnsafe(TestComponent).result != null);

    try my_entity.addPreparedComponents(true);

    try expect(my_entity.getComponentUnsafe(TestComponent).result != null);
}

test "pullComponent" {
    const TestComponent = struct {
        my_var: usize = 1,
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try expectError(error.ComponentNotFound, my_entity.pullComponent(TestComponent));

    try my_entity.addComponent(TestComponent{});

    try expectError(error.ComponentNotFound, my_entity.pullComponent(TestComponent));

    try my_entity.addPreparedComponents(true);

    const component = try my_entity.pullComponent(TestComponent);
    try expect(@TypeOf(component) == *TestComponent);
}

test "getComponents" {
    const TestComponent = struct {
        my_var: usize = 1,
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try my_entity.addComponents(.{
        TestComponent{ .my_var = 0 },
        TestComponent{ .my_var = 1 },
        TestComponent{ .my_var = 2 },
    });

    try my_entity.addPreparedComponents(true);

    var components = try my_entity.getComponents(TestComponent);
    defer components.deinit();

    try expectEqual(3, components.len());
}

test "removeComponent" {
    const TestComponent = struct {
        my_var: usize = 1,
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try my_entity.addComponent(TestComponent{ .my_var = 0 });

    try my_entity.addPreparedComponents(true);
    try expectEqual(1, my_entity.components.len());

    my_entity.removeComponent(TestComponent);
    try expectEqual(1, my_entity.components.len());

    my_entity.dispatchEvent(.update);
    try expectEqual(0, my_entity.components.len());
}

test "removeComponents" {
    const TestComponent = struct {
        my_var: usize = 1,
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try my_entity.addComponents(.{
        TestComponent{ .my_var = 0 },
        TestComponent{ .my_var = 1 },
        TestComponent{ .my_var = 2 },
    });

    try my_entity.addPreparedComponents(true);
    try expectEqual(3, my_entity.components.len());

    my_entity.removeComponents(TestComponent);
    try expectEqual(3, my_entity.components.len());

    my_entity.dispatchEvent(.update);
    try expectEqual(0, my_entity.components.len());
}

test "dispatchEvent" {
    const TestComponent = struct {
        const Self = @This();

        my_var: usize = 0,

        pub fn Awake(self: *Self) void {
            self.my_var += 1;
        }

        pub fn Start(self: *Self) void {
            self.my_var += 1;
        }

        pub fn Update(self: *Self) void {
            self.my_var += 1;
        }

        pub fn Tick(self: *Self) void {
            self.my_var += 1;
        }

        pub fn End(self: *Self) void {
            self.my_var += 1;
        }
    };

    var my_entity = Entity.init(allocator, "my_entity");
    defer my_entity.deinit();

    try my_entity.addComponents(.{
        TestComponent{ .my_var = 0 },
    });

    try my_entity.addPreparedComponents(false);

    const component = try my_entity.getComponentUnsafe(TestComponent).unwrap();
    try expectEqual(0, component.my_var);

    my_entity.dispatchEvent(.awake);
    try expectEqual(1, component.my_var);

    my_entity.dispatchEvent(.start);
    try expectEqual(2, component.my_var);
    
    my_entity.dispatchEvent(.update);
    try expectEqual(3, component.my_var);
    
    my_entity.dispatchEvent(.tick);
    try expectEqual(4, component.my_var);
    
    my_entity.dispatchEvent(.end);
    try expectEqual(5, component.my_var);
}
