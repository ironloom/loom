const std = @import("std");
const lm = @import("../../root.zig");
const rl = lm.deps.rl;

pub fn parse(
    data: []const u8,
    filetype: []const u8,
    path: []const u8,
    mod: []const i32,
) !rl.Music {
    _ = path;
    _ = mod;

    const file_type: [:0]const u8 = try lm.allocators.generic().dupeSentinel(u8, filetype, 0);
    defer lm.allocators.generic().free(file_type);

    return try rl.loadMusicStreamFromMemory(file_type, data);
}

pub fn release(uploaded: rl.Music) void {
    rl.unloadMusicStream(uploaded);
}

