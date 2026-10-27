const std = @import("std");
const loom = @import("root.zig");

const rl = @import("raylib");

const assets = loom.assets;
const Sound = rl.Sound;

const DEFAULT_SOUND_LIFE_TICKS: usize = 300;
const DEFAULT_TICKS_PER_SECOND: f32 = 20;

const Cached = struct {
    sound: *Sound,
    life: usize = DEFAULT_SOUND_LIFE_TICKS,
    playing: bool = false,
    volume: f32 = 1,
    looping: bool = false,
    pitch: f32 = 1,
    pan: f32 = 1,
};

var audio_cache: std.StringHashMap(Cached) = undefined;
var is_alive = false;
var last_tick_seconds: f32 = 0;

pub fn init() void {
    if (is_alive) return;

    audio_cache = .init(loom.allocators.generic());
    last_tick_seconds = 0;
    is_alive = true;
}

pub fn deinit() void {
    if (!is_alive) return;

    var cache_iterator = audio_cache.iterator();
    while (cache_iterator.next()) |entry| {
        assets.sound.releasePtr(entry.value_ptr.sound);
    }

    is_alive = false;
    audio_cache.deinit();
}

pub fn update() void {
    if (!is_alive) return;

    const current_time_seconds = loom.time.appTime();
    const ticks_per_second: f32 = if (loom.activeScene()) |scene|
        loom.tof32(scene.ticks_per_second)
    else
        DEFAULT_TICKS_PER_SECOND;

    if (last_tick_seconds + (1.0 / ticks_per_second) > current_time_seconds) return;
    last_tick_seconds = current_time_seconds;

    var expired_paths = loom.List([]const u8).init(loom.allocators.generic());
    defer expired_paths.deinit();

    var cache_iterator = audio_cache.iterator();
    while (cache_iterator.next()) |entry| {
        const path = entry.key_ptr.*;
        const cached_sound = entry.value_ptr;

        if (isPlaying(path)) {
            cached_sound.life = DEFAULT_SOUND_LIFE_TICKS;
            continue;
        }

        cached_sound.life -|= 1;
        if (cached_sound.life == 0) {
            expired_paths.append(path) catch continue;
        }
    }

    for (expired_paths.items()) |path| {
        unload(path);
    }
}

pub fn load(path: []const u8) !void {
    if (!is_alive) return;

    if (audio_cache.contains(path)) return;

    const sound = assets.sound.get(path, &.{}) orelse return;

    try audio_cache.put(path, Cached{
        .sound = sound,
        .playing = true,
    });
}

pub fn unload(path: []const u8) void {
    if (!is_alive) return;
    const entry = audio_cache.fetchRemove(path) orelse return;

    assets.sound.releasePtr(entry.value.sound);
}

pub fn play(path: []const u8) !void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse add: {
        try load(path);
        break :add audio_cache.getPtr(path) orelse return;
    };

    cached.life = DEFAULT_SOUND_LIFE_TICKS;
    cached.playing = true;
    rl.playSound(cached.sound.*);
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

    rl.stopSound(cached.sound.*);
    cached.playing = false;
}

pub fn proceed(path: []const u8) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;

    rl.resumeSound(cached.sound.*);
    cached.playing = true;
}

pub fn pause(path: []const u8) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;

    rl.pauseSound(cached.sound.*);
    cached.playing = false;
}

pub fn isPlaying(path: []const u8) bool {
    if (!is_alive) return false;

    const cached = audio_cache.getPtr(path) orelse return false;
    cached.playing = rl.isSoundPlaying(cached.sound.*);

    return cached.playing;
}

pub fn setVolume(path: []const u8, volume: f32) void {
    if (!is_alive) return;

    const cached = audio_cache.getPtr(path) orelse return;
    rl.setSoundVolume(cached.sound.*, volume);
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
    rl.setSoundPitch(cached.sound.*, pitch);
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
    rl.setSoundPan(cached.sound.*, pan);
    cached.pan = pan;
}

pub fn getPan(path: []const u8) f32 {
    if (!is_alive) return 0;

    const cached = audio_cache.get(path) orelse return 0;

    return cached.pan;
}

