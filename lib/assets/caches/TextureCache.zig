const std = @import("std");
const lm = @import("../../root.zig");
const rl = lm.deps.rl;
const AssetPromise = @import("../asset_promise.zig").AssetPromise;

const Image = lm.deps.rl.Image;
const Texture = lm.deps.rl.Texture;

const Promise = AssetPromise(Image, Texture);

pub fn parse(
    data: []const u8,
    filetype: []const u8,
    path: []const u8,
    mod: []const i32,
) !Image {
    _ = path;

    const str: [:0]const u8 = try lm.allocators.generic().dupeZ(u8, filetype);
    defer lm.allocators.generic().free(str);

    var img = try rl.loadImageFromMemory(str, data);

    if (mod.len >= 2) {
        const width = if (mod.len > 0) @max(1, mod[0]) else 1;
        const height = if (mod.len > 1) @max(1, mod[1]) else 1;

        rl.imageResizeNN(&img, width, height);
    }

    return img;
}

pub fn releaseRaw(raw: Image) void {
    rl.unloadImage(raw);
}

pub fn upload(raw: Image) !Texture {
    return try rl.loadTextureFromImage(raw);
}

pub fn release(uploaded: Texture) void {
    rl.unloadTexture(uploaded);
}
