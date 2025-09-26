const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const lm = @import("../../root.zig");

pub const shared = @import("./types.zig");

pub const Animation = shared.Animation;
pub const KeyFrame = shared.Keyframe;

const Self = @This();

alloc: Allocator,
alive: bool = false,

animations: lm.List(*Animation) = undefined,
base_animations: []const Animation,
playing: lm.List(*Animation) = undefined,

transform: ?*lm.Transform = null,
display: ?*lm.Renderer = null,

pub fn init(base_animations: []const Animation) Self {
    return Self{
        .alloc = std.heap.smp_allocator,
        .base_animations = base_animations,
        .alive = true,
    };
}

pub fn deinit(self: *Self) void {
    if (!self.alive) return;

    // std.log.debug("{d} - {d}", .{ self.animations.capacity(), self.animations.count() });

    for (self.animations.items()) |item| {
        item.deinit();
        self.alloc.destroy(item);
    }

    self.playing.deinit();
    self.animations.deinit();

    self.alive = false;
}

pub fn chain(self: *Self, anim: Animation) !void {
    if (!self.alive) return;

    const ptr = try self.alloc.create(Animation);
    ptr.* = anim;

    for (ptr.base_keyframes) |base_keyframe| {
        _ = ptr.append(base_keyframe);
    }
    ptr.close();

    if (ptr.uuid == 0) ptr.uuid = lm.UUIDv7();

    try self.animations.append(ptr);
}

pub fn isPlaying(self: *Self, name: []const u8) bool {
    if (!self.alive) return false;

    for (self.animations.items()) |item| {
        if (std.mem.eql(u8, item.name, name)) return item.playing;
    }

    return false;
}

pub fn play(self: *Self, name: []const u8) !void {
    if (!self.alive) return;

    for (self.animations.items()) |anim| {
        if (!std.mem.eql(u8, anim.name, name)) continue;

        if (anim.playing) return;
        try self.playing.append(anim);

        anim.playing = true;
        anim.current_percent = 0;
        anim.start_time = lm.time.gameTime();

        break;
    }
}

pub fn stop(self: *Self, name: []const u8) void {
    if (!self.alive) return;

    for (self.animations.items()) |anim| {
        if (!std.mem.eql(u8, anim.name, name)) continue;
        if (!anim.playing) return;

        for (self.playing.items(), 0..) |item, index| {
            if (item.uuid != anim.uuid) continue;

            _ = self.playing.swapRemove(index);
            break;
        }

        anim.playing = false;
        break;
    }
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.animations = lm.List(*Animation).init(std.heap.smp_allocator);
    self.playing = lm.List(*Animation).init(std.heap.smp_allocator);

    for (self.base_animations) |item| {
        try self.chain(item);
    }

    self.transform = entity.getComponent(lm.Transform) orelse return;
    self.display = entity.getComponent(lm.Renderer) orelse return;
}

pub fn Update(self: *Self, _: *lm.Entity) !void {
    const transform = self.transform orelse return;
    const display = self.display orelse return;

    for (self.playing.items()) |animation| {
        if (!animation.playing) {
            self.stop(animation.name);
            break;
        }

        const current = animation.current();
        const next = animation.next();

        const current_keyframe = current orelse continue;
        const next_keyframe = next orelse {
            current_keyframe.apply(transform, display);
            animation.playing = false;
            continue;
        };

        const interpolation_factor =
            @min(1, @max(0, (lm.time.gameTime() - lm.tof32(animation.start_time)) / lm.tof32(animation.length)));

        const anim_progress_percent = animation.timing_function(0, 1, interpolation_factor);
        const next_index_percent = animation.timing_function(0, 1, lm.tof32(animation.next_index) / 100);
        const current_index_percent = animation.timing_function(0, 1, lm.tof32(animation.current_index) / 100);

        const percent = @min(1, @max(0, (anim_progress_percent - current_index_percent) / (next_index_percent - current_index_percent)));

        current_keyframe
            .interpolate(next_keyframe, shared.interpolation.lerp, percent)
            .apply(transform, display);

        if (percent != 1) continue;

        animation.incrementCurrentPercent(lm.toi32(interpolation_factor * 100));
    }

    var clone = try self.playing.toArray();
    defer clone.deinit();

    for (clone.items) |item| {
        if (item.playing) continue;

        for (self.playing.items(), 0..) |anim, index| {
            if (anim.uuid != item.uuid) continue;

            _ = self.playing.swapRemove(index);
            break;
        }
    }
}

pub fn End(self: *Self) !void {
    self.deinit();
}
