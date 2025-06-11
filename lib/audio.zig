const std = @import("std");
const loom = @import("root.zig");

const assets = loom.assets;
const Sound = loom.rl.Sound;

const Cached = struct {
    sound: *Sound,
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
    audio_cache = .init(loom.allocators.generic());
    is_alive = true;
}

pub fn deinit() void {
    if (!is_alive) return;

    audio_cache.deinit();
}

pub fn update() void {
    if (!is_alive) return;

    var iter = audio_cache.iterator();

    while (iter.next()) |entry| {
        const path = entry.key_ptr.*;
        const value_ptr = entry.value_ptr;

        if (isPlaying(path)) continue;

        value_ptr.life -= 1;
        if (value_ptr.life != 0) continue;

        unload(path);
    }
}

pub fn load(path: []const u8) !void {
    if (!is_alive) return;

    const cached = assets.sound.get(path, .{}) orelse return;

    try audio_cache.put(path, Cached{
        .sound = cached,
        .playing = true,
    });
}

pub fn unload(path: []const u8) void {
    if (!is_alive) return;
    if (!audio_cache.remove(path)) return;

    assets.sound.release(path, .{});
}

pub fn play(path: []const u8) !void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse add: {
        try load(path);
        break :add audio_cache.getPtr(path) orelse return;
    };

    loom.rl.playSound(cached.sound.*);
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

    loom.rl.stopSound(cached.sound.*);
    cached.playing = false;
}

pub fn proceed(path: []const u8) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;

    loom.rl.resumeSound(cached.sound.*);
    cached.playing = true;
}

pub fn pause(path: []const u8) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;

    loom.rl.pauseSound(cached.sound.*);
    cached.playing = false;
}

pub fn isPlaying(path: []const u8) bool {
    if (!is_alive) return false;

    const cached = audio_cache.getPtr(path) orelse return false;
    cached.playing = loom.rl.isSoundPlaying(cached.sound.*);

    return cached.playing;
}

pub fn setVolume(path: []const u8, volume: f32) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;
    loom.rl.setSoundVolume(cached.sound.*, volume);
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

    loom.rl.setSoundPitch(cached.sound.*, pitch);
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

    loom.rl.setSoundPan(cached.sound.*, pan);
    cached.pan = pan;
}

pub fn getPan(path: []const u8) f32 {
    if (!is_alive) return 0;

    const cached = audio_cache.get(path) orelse return 0;

    return cached.pan;
}
