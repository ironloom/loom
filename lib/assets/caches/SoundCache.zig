const std = @import("std");
const lm = @import("../../root.zig");
const rl = lm.deps.rl;

pub fn parse(
    data: []const u8,
    filetype: []const u8,
    path: []const u8,
    mod: []const i32,
) !rl.Sound {
    _ = path;
    _ = mod;

    const str: [:0]const u8 = try lm.allocators.generic().dupeSentinel(u8, filetype, 0);
    defer lm.allocators.generic().free(str);

    const wave = try rl.loadWaveFromMemory(str, data);
    defer rl.unloadWave(wave);

    return rl.loadSoundFromWave(wave);
}

pub fn release(uploaded: rl.Sound) void {
    rl.unloadSound(uploaded);
}

