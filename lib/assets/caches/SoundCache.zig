const std = @import("std");
const lm = @import("../../root.zig");
const rl = lm.deps.rl;

pub fn parse(
    data: []const u8,
    filetype: []const u8,
    path: []const u8,
    mod: []const i32,
) !rl.Wave {
    _ = path;
    _ = mod;

    const str: [:0]const u8 = try lm.allocators.generic().dupeSentinel(u8, filetype, 0);
    defer lm.allocators.generic().free(str);

    return try rl.loadWaveFromMemory(str, data);
}

pub fn releaseRaw(raw: rl.Wave) void {
    rl.unloadWave(raw);
}

pub fn upload(raw: rl.Wave) !rl.Sound {
    return rl.loadSoundFromWave(raw);
}

pub fn release(uploaded: rl.Sound) void {
    rl.unloadSound(uploaded);
}
