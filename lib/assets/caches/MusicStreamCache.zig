const std = @import("std");
const lm = @import("../../root.zig");
const rl = lm.deps.rl;
const files = @import("../files.zig");

pub const MusicStreamConfig = struct {
    file_data: []const u8,
    file_type: [:0]const u8,
};

pub fn parse(
    data: []const u8,
    filetype: []const u8,
    path: []const u8,
    mod: []const i32,
) !MusicStreamConfig {
    _ = path;
    _ = mod;

    const allocator = lm.allocators.generic();

    const file_data: []const u8 = try allocator.dupe(u8, data);
    errdefer allocator.free(file_data);

    const file_type: [:0]const u8 = try allocator.dupeZ(u8, filetype);
    errdefer allocator.free(file_type);

    return MusicStreamConfig{
        .file_data = file_data,
        .file_type = file_type,
    };
}

pub fn releaseRaw(raw: MusicStreamConfig) void {
    const allocator = lm.allocators.generic();

    allocator.free(raw.file_data);
    allocator.free(raw.file_type);
}

pub fn upload(raw: MusicStreamConfig) !rl.Music {
    return try rl.loadMusicStreamFromMemory(raw.file_type, raw.file_data);
}

pub fn release(uploaded: rl.Music) void {
    rl.unloadMusicStream(uploaded);
}
