const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const lm = @import("../root.zig");

const List = lm.types.List;

pub const Scene = @import("./Scene.zig");
pub const Error = error{
    SceneNotFound,
};

const Self = @This();

scenes: List(*Scene),
active_scene: ?*Scene = null,
open_scene: ?*Scene = null,
next_scene: ?*Scene = null,
alloc: Allocator = std.heap.smp_allocator,
unload_on_next_frame: bool = false,

pub fn init(allocator: Allocator) Self {
    return Self{
        .scenes = .init(allocator),
        .alloc = allocator,
    };
}

pub fn deinit(self: *Self) void {
    const scenes_len = self.scenes.len();
    for (1..scenes_len + 1) |j| {
        const index = scenes_len - j;
        const scene = self.scenes.items()[index];

        scene.deinit();
        self.alloc.destroy(scene);

        _ = self.scenes.swapRemove(index);
    }

    self.scenes.deinit();
    self.* = undefined;
}

pub fn addScene(self: *Self, scene: Scene) !void {
    const ptr = try self.alloc.create(Scene);
    ptr.* = scene;

    try self.scenes.append(ptr);
}

const AutoCloseContext = struct {
    var target_var: ?*?*Scene = null;

    pub fn callback(_: void) void {
        const target = target_var orelse return;
        target.* = null;
    }
};

pub fn addSceneOpen(self: *Self, scene: Scene) anyerror!*const fn (void) void {
    const ptr = try self.alloc.create(Scene);
    ptr.* = scene;

    try self.scenes.append(ptr);
    self.open_scene = ptr;

    AutoCloseContext.target_var = &(self.open_scene);

    return AutoCloseContext.callback;
}

/// Loads the selected scene on the next frame to avoid segmentation faults.
pub fn setActive(self: *Self, id: []const u8) !void {
    for (self.scenes.items()) |scene| {
        if (!std.mem.eql(u8, scene.id, id)) continue;

        self.next_scene = scene;
        return;
    }
    return Error.SceneNotFound;
}

pub fn execute(self: *Self) void {
    self.loadNext();

    const active_scene = self.active_scene orelse return;

    if (!active_scene.is_active) {
        active_scene.load() catch |err| {
            std.log.err("couldn't load \"{s}\" scene: {any}", .{ active_scene.id, err });
            return;
        };
    }

    active_scene.execute();
}

pub fn loadNext(self: *Self) void {
    const nscene = self.next_scene orelse return;
    if (self.active_scene) |ascene| ascene.unload();

    nscene.is_active = false;
    self.active_scene = nscene;

    _ = if (lm.allocators.AI_scene.interface) |*int| int.reset(.free_all);

    self.next_scene = null;
}
