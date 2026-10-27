const std = @import("std");
const Allocator = std.mem.Allocator;

const lm = @import("../../root.zig");
const rl = lm.deps.rl;

pub const shared = @import("./types.zig");

pub const Animation = shared.Animation;
pub const KeyFrame = shared.Keyframe;

const Self = @This();

alloc: Allocator,
alive: bool = false,

animations: lm.List(*Animation) = undefined,
base_animations: []const Animation,
playing: lm.List(*Animation) = undefined,
sprite_cache: std.AutoHashMap(u128, lm.List(*rl.Texture)) = undefined,

transform: ?*lm.Transform = null,
display: ?*lm.Renderer = null,

// Behaviour Methods
// --------------------------------------------------------------------------------------------------------------

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.animations = lm.List(*Animation).init(self.alloc);
    self.playing = lm.List(*Animation).init(self.alloc);
    self.sprite_cache = std.AutoHashMap(u128, lm.List(*rl.Texture)).init(self.alloc);

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
            self.releaseAnimationSprites(animation.uuid);
            continue;
        };

        const interpolation_factor =
            @min(1, @max(0, (lm.time.gameTime() - lm.tof32(animation.start_time)) / lm.tof32(animation.length)));

        const anim_progress_percent = animation.timing_function(0, 1, interpolation_factor);
        const next_index_percent = animation.timing_function(0, 1, lm.tof32(animation.next_index) / 100);
        const current_index_percent = animation.timing_function(0, 1, lm.tof32(animation.current_index) / 100);

        const percent = @min(1, @max(0, (anim_progress_percent - current_index_percent) / (next_index_percent - current_index_percent)));

        const interpolated_keyframe = current_keyframe
            .interpolate(next_keyframe, shared.interpolation.lerp, percent);

        interpolated_keyframe.apply(transform, display);

        if (interpolated_keyframe.sprite) |sprite_path| {
            const tile_size = display.tile_size orelse transform.scale;
            self.cacheSprite(animation.uuid, sprite_path, &.{ lm.toi32(tile_size.x), lm.toi32(tile_size.y) });
        }

        if (percent != 1) continue;

        animation.incrementCurrentPercent(lm.toi32(interpolation_factor * 100));
    }

    const playing_len = self.playing.len();
    for (1..playing_len + 1) |j| {
        const index = playing_len - j;
        const item = self.playing.items()[index];

        if (item.playing) continue;
        self.releaseAnimationSprites(item.uuid);
        _ = self.playing.swapRemove(index);
    }
}

pub fn End(self: *Self) !void {
    self.deinit();
}

// Custom / Helper Methods
// --------------------------------------------------------------------------------------------------------------

pub fn init(base_animations: []const Animation) Self {
    return Self{
        .alloc = std.heap.smp_allocator,
        .base_animations = base_animations,
        .alive = true,
    };
}

pub fn deinit(self: *Self) void {
    if (!self.alive) return;

    self.clearAllSpriteCaches();
    self.sprite_cache.deinit();

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

        self.cacheAnimationSprites(anim);

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
        self.releaseAnimationSprites(anim.uuid);
        break;
    }
}

fn cacheSprite(self: *Self, anim_uuid: u128, path: []const u8, modifiers: []const i32) void {
    const tex = lm.assets.texture.get(path, modifiers) orelse return;

    const list = if (self.sprite_cache.getPtr(anim_uuid)) |existing_list|
        existing_list
    else Blk: {
        const new_list = lm.List(*rl.Texture).init(self.alloc);
        self.sprite_cache.put(anim_uuid, new_list) catch {
            lm.assets.texture.releasePtr(tex);
            return;
        };
        break :Blk self.sprite_cache.getPtr(anim_uuid).?;
    };

    for (list.items()) |cached_tex| {
        if (cached_tex == tex) {
            lm.assets.texture.releasePtr(tex);
            return;
        }
    }

    list.append(tex) catch {
        lm.assets.texture.releasePtr(tex);
    };
}

fn cacheAnimationSprites(self: *Self, anim: *Animation) void {
    const display = self.display orelse return;
    const transform = self.transform orelse return;
    const tile_size = display.tile_size orelse transform.scale;
    const modifiers = [_]i32{ lm.toi32(tile_size.x), lm.toi32(tile_size.y) };

    if (anim.keyframes) |*kfs| {
        var iter = kfs.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.sprite) |path| {
                self.cacheSprite(anim.uuid, path, &modifiers);
            }
        }
    } else {
        for (anim.base_keyframes) |kf| {
            if (kf.sprite) |path| {
                self.cacheSprite(anim.uuid, path, &modifiers);
            }
        }
    }
}

fn releaseAnimationSprites(self: *Self, anim_uuid: u128) void {
    if (self.sprite_cache.fetchRemove(anim_uuid)) |kv| {
        var list = kv.value;
        for (list.items()) |tex| {
            lm.assets.texture.releasePtr(tex);
        }
        list.deinit();
    }
}

fn clearAllSpriteCaches(self: *Self) void {
    var iter = self.sprite_cache.iterator();
    while (iter.next()) |entry| {
        for (entry.value_ptr.items()) |tex| {
            lm.assets.texture.releasePtr(tex);
        }
        entry.value_ptr.deinit();
    }
    self.sprite_cache.clearAndFree();
}
