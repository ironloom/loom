const std = @import("std");
const lm = @import("loom");

const Behaviour = lm.ecs.Behaviour;

const TestType = struct {
    id: []const u8,
    uuid: u128,
    counter: usize = 0,

    pub fn init() TestType {
        return TestType{
            .id = "test",
            .uuid = 2,
        };
    }
};

test "init/fields" {
    const MyBehaviour = struct {
        myfield: usize = 0,
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expectEqualStrings(behaviour_instance.name, @typeName(MyBehaviour));
    try std.testing.expect(behaviour_instance.hash != 0);
}

test "init/attachEvents/empty" {
    const MyBehaviour = struct {
        myfield: usize = 0,

        pub fn Awake() void {}
        pub fn Start() void {}
        pub fn Update() void {}
        pub fn Tick() void {}
        pub fn End() void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "init/attachEvents/self_only" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(_: *Self) void {}
        pub fn Start(_: *Self) void {}
        pub fn Update(_: *Self) void {}
        pub fn Tick(_: *Self) void {}
        pub fn End(_: *Self) void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "init/attachEvents/target_only" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(_: *TestType) void {}
        pub fn Start(_: *TestType) void {}
        pub fn Update(_: *TestType) void {}
        pub fn Tick(_: *TestType) void {}
        pub fn End(_: *TestType) void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "init/attachEvents/self_target" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(_: *Self, _: *TestType) void {}
        pub fn Start(_: *Self, _: *TestType) void {}
        pub fn Update(_: *Self, _: *TestType) void {}
        pub fn Tick(_: *Self, _: *TestType) void {}
        pub fn End(_: *Self, _: *TestType) void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "init/attachEvents/target_self" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(_: *TestType, _: *Self) void {}
        pub fn Start(_: *TestType, _: *Self) void {}
        pub fn Update(_: *TestType, _: *Self) void {}
        pub fn Tick(_: *TestType, _: *Self) void {}
        pub fn End(_: *TestType, _: *Self) void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "init/attachEvents/empty_error" {
    const MyBehaviour = struct {
        myfield: usize = 0,

        pub fn Awake() !void {}
        pub fn Start() !void {}
        pub fn Update() !void {}
        pub fn Tick() !void {}
        pub fn End() !void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "init/attachEvents/self_only_error" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(_: *Self) !void {}
        pub fn Start(_: *Self) !void {}
        pub fn Update(_: *Self) !void {}
        pub fn Tick(_: *Self) !void {}
        pub fn End(_: *Self) !void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "init/attachEvents/target_only_error" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(_: *TestType) !void {}
        pub fn Start(_: *TestType) !void {}
        pub fn Update(_: *TestType) !void {}
        pub fn Tick(_: *TestType) !void {}
        pub fn End(_: *TestType) !void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "init/attachEvents/self_target_error" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(_: *Self, _: *TestType) !void {}
        pub fn Start(_: *Self, _: *TestType) !void {}
        pub fn Update(_: *Self, _: *TestType) !void {}
        pub fn Tick(_: *Self, _: *TestType) !void {}
        pub fn End(_: *Self, _: *TestType) !void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "init/attachEvents/target_self_error" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(_: *TestType, _: *Self) !void {}
        pub fn Start(_: *TestType, _: *Self) !void {}
        pub fn Update(_: *TestType, _: *Self) !void {}
        pub fn Tick(_: *TestType, _: *Self) !void {}
        pub fn End(_: *TestType, _: *Self) !void {}
    };

    const behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.awake != null);
    try std.testing.expect(behaviour_instance.start != null);
    try std.testing.expect(behaviour_instance.update != null);
    try std.testing.expect(behaviour_instance.tick != null);
    try std.testing.expect(behaviour_instance.end != null);
}

test "callSafe" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(target: *TestType) void {
            target.counter += 1;
        }

        pub fn Start(target: *TestType) void {
            target.counter += 2;
        }

        pub fn Update(target: *TestType) void {
            target.counter += 3;
        }

        pub fn Tick(target: *TestType) void {
            target.counter += 4;
        }

        pub fn End(target: *TestType) void {
            target.counter += 5;
        }
    };

    var target = TestType.init();
    var behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(target.counter == 0);

    behaviour_instance.callSafe(.awake, &target);
    try std.testing.expectEqual(@as(usize, 1), target.counter);

    behaviour_instance.callSafe(.start, &target);
    try std.testing.expectEqual(@as(usize, 1 + 2), target.counter);

    behaviour_instance.callSafe(.update, &target);
    try std.testing.expectEqual(@as(usize, 1 + 2 + 3), target.counter);

    behaviour_instance.callSafe(.tick, &target);
    try std.testing.expectEqual(@as(usize, 1 + 2 + 3 + 4), target.counter);

    behaviour_instance.callSafe(.end, &target);
    try std.testing.expectEqual(@as(usize, 1 + 2 + 3 + 4 + 5), target.counter);
}

test "callSafe - initalised" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(_: *TestType, _: *Self) !void {}
        pub fn Start(_: *TestType, _: *Self) !void {}
        pub fn Update(_: *TestType, _: *Self) !void {}
        pub fn Tick(_: *TestType, _: *Self) !void {}
        pub fn End(_: *TestType, _: *Self) !void {}
    };

    var target = TestType.init();
    var behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(!behaviour_instance.initalised);

    behaviour_instance.callSafe(.awake, &target);

    try std.testing.expect(behaviour_instance.initalised);
}

test "isType" {
    const MyBehaviour = struct {
        const Self = @This();

        myfield: usize = 0,

        pub fn Awake(target: *TestType) void {
            target.counter += 1;
        }

        pub fn Start(target: *TestType) void {
            target.counter += 2;
        }

        pub fn Update(target: *TestType) void {
            target.counter += 3;
        }

        pub fn Tick(target: *TestType) void {
            target.counter += 4;
        }

        pub fn End(target: *TestType) void {
            target.counter += 5;
        }
    };

    const NotMyBehaviour = struct {
        not_my_field: isize = 1,
    };

    var behaviour_instance = try Behaviour(TestType).init(MyBehaviour{});

    try std.testing.expect(behaviour_instance.isType(MyBehaviour));
    try std.testing.expect(!behaviour_instance.isType(NotMyBehaviour));
    try std.testing.expect(!behaviour_instance.isType(u32));
}

test "calculateHash" {
    const calculateHash = lm.ecs.calculateHash;

    const u32_hash = comptime calculateHash(u32);
    const u64_hash = comptime calculateHash(u64);
    const TestType_hash = comptime calculateHash(TestType);
    const BehaviourT_hash = comptime calculateHash(Behaviour(TestType));

    const a = enum { a, b };
    const b = enum { a, b };

    try std.testing.expect(u32_hash != u64_hash);
    try std.testing.expect(u32_hash != TestType_hash);
    try std.testing.expect(u64_hash != TestType_hash);
    try std.testing.expect(BehaviourT_hash != TestType_hash);
    try std.testing.expect(comptime calculateHash(a) != calculateHash(b));
}
