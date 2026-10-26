const std = @import("std");
const lm = @import("../../root.zig");
const rl = lm.deps.rl;

pub fn parse(
    data: []const u8,
    filetype: []const u8,
    path: []const u8,
    mod: []const i32,
) !rl.Image {
    _ = path;

    const str: [:0]const u8 = try lm.allocators.generic().dupeSentinel(u8, filetype, 0);
    defer lm.allocators.generic().free(str);

    var img = try rl.loadImageFromMemory(str, data);

    if (mod.len >= 2) {
        const width = @max(1, mod[0]);
        const height = @max(1, mod[1]);
        rl.imageResizeNN(&img, width, height);
    }

    return img;
}

pub fn upload(raw: rl.Image) !rl.Image {
    return raw;
}

pub fn release(uploaded: rl.Image) void {
    rl.unloadImage(uploaded);
}
