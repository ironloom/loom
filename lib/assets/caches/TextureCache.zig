const std = @import("std");
const lm = @import("../../root.zig");
const rl = lm.deps.rl;

const Texture = lm.deps.rl.Texture;

pub fn parse(
    data: []const u8,
    filetype: []const u8,
    path: []const u8,
    mod: []const i32,
) !Texture {
    _ = path;

    const str: [:0]const u8 = try lm.allocators.generic().dupeSentinel(u8, filetype, 0);
    defer lm.allocators.generic().free(str);

    var img = try rl.loadImageFromMemory(str, data);
    defer rl.unloadImage(img);

    if (mod.len >= 2) {
        const width = if (mod.len > 0) @max(1, mod[0]) else 1;
        const height = if (mod.len > 1) @max(1, mod[1]) else 1;

        rl.imageResizeNN(&img, width, height);
    }

    return try rl.loadTextureFromImage(img);
}

pub fn release(uploaded: Texture) void {
    rl.unloadTexture(uploaded);
}

