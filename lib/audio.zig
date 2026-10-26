const std = @import("std");
const loom = @import("root.zig");

const rl = @import("raylib");

const assets = loom.assets;
const Sound = rl.Sound;

const Cached = struct {
    promise: *assets.sound.Promise,
    sound: ?*Sound = null,
    life: usize = 15,
    playing: bool = false,
    volume: f32 = 1,
    looping: bool = false,
    pitch: f32 = 1,
    pan: f32 = 1,
};

var audio_cache: std.StringHashMap(Cached) = undefined;
var is_alive = false;

pub fn init() void {
    if (is_alive) return;

    audio_cache = .init(loom.allocators.generic());
    is_alive = true;
}

pub fn deinit() void {
    if (!is_alive) return;

    var iter = audio_cache.iterator();
    while (iter.next()) |entry| {
        if (entry.value_ptr.sound) |sound| {
            assets.sound.releasePtr(sound);
        } else {
            assets.sound.releasePromise(entry.value_ptr.promise);
        }
    }

    is_alive = false;
    audio_cache.deinit();
}

pub fn update() void {
    if (!is_alive) return;

    var iter = audio_cache.iterator();

    while (iter.next()) |entry| {
        const path = entry.key_ptr.*;
        const value_ptr = entry.value_ptr;

        if (isPlaying(path)) continue;

        value_ptr.life -|= 1;
        if (value_ptr.life != 0) continue;

        unload(path);
    }
}

pub fn load(path: []const u8) !void {
    if (!is_alive) return;

    if (audio_cache.contains(path)) return;

    const promise = assets.sound.get(path, &.{}) orelse return;

    try audio_cache.put(path, Cached{
        .promise = promise,
        .sound = promise.sync() catch null,
        .playing = true,
    });
}

pub fn unload(path: []const u8) void {
    if (!is_alive) return;
    const entry = audio_cache.fetchRemove(path) orelse return;

    if (entry.value.sound) |sound| {
        assets.sound.releasePtr(sound);
    } else {
        assets.sound.releasePromise(entry.value.promise);
    }
}

pub fn play(path: []const u8) !void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse add: {
        try load(path);
        break :add audio_cache.getPtr(path) orelse return;
    };

    if (cached.sound == null) {
        cached.sound = cached.promise.sync() catch null;
    }
    const sound = cached.sound orelse return;

    rl.playSound(sound.*);
}

pub fn playAdvanced(
    path: []const u8,
    config: struct {
        volume: f32 = 1,
        pitch: f32 = 1,
        pan: f32 = 1,
    },
) !void {
    try load(path);

    setVolume(path, config.volume);
    setPitch(path, config.pitch);
    setPan(path, config.pan);

    try play(path);
}

pub fn stop(path: []const u8) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;
    const sound = cached.sound orelse return;

    rl.stopSound(sound.*);
    cached.playing = false;
}

pub fn proceed(path: []const u8) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;
    const sound = cached.sound orelse return;

    rl.resumeSound(sound.*);
    cached.playing = true;
}

pub fn pause(path: []const u8) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;
    const sound = cached.sound orelse return;

    rl.pauseSound(sound.*);
    cached.playing = false;
}

pub fn isPlaying(path: []const u8) bool {
    if (!is_alive) return false;

    const cached = audio_cache.getPtr(path) orelse return false;
    const sound = cached.sound orelse return false;
    cached.playing = rl.isSoundPlaying(sound.*);

    return cached.playing;
}

pub fn setVolume(path: []const u8, volume: f32) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;
    if (cached.sound) |sound| {
        rl.setSoundVolume(sound.*, volume);
    }
    cached.volume = volume;
}

pub fn getVolume(path: []const u8) f32 {
    if (!is_alive) return 0;

    const cached = audio_cache.getPtr(path) orelse return 0;
    return cached.volume;
}

pub fn setPitch(path: []const u8, pitch: f32) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;
    if (cached.sound) |sound| {
        rl.setSoundPitch(sound.*, pitch);
    }
    cached.pitch = pitch;
}

pub fn getPitch(path: []const u8) f32 {
    if (!is_alive) return 0;

    const cached = audio_cache.get(path) orelse return 0;

    return cached.pitch;
}

pub fn setPan(path: []const u8, pan: f32) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;
    if (cached.sound) |sound| {
        rl.setSoundPan(sound.*, pan);
    }
    cached.pan = pan;
}

pub fn getPan(path: []const u8) f32 {
    if (!is_alive) return 0;

    const cached = audio_cache.get(path) orelse return 0;

    return cached.pan;
}
