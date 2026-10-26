const std = @import("std");
const lm = @import("../root.zig");
const rl = lm.deps.rl;

pub const AssetCache = @import("asset_cache.zig").AssetCache;
pub const AssetPromise = @import("asset_promise.zig").AssetPromise;
pub const files = @import("files.zig");

pub fn deinit() void {
    inline for (@typeInfo(@This()).@"struct".decls) |decl| {
        const T = @field(@This(), decl.name);
        if (@typeInfo(@TypeOf(T)) == .type and @hasDecl(T, "deinit")) {
            T.deinit();
        }
    }
}

const caches = @import("caches/caches.zig");

pub const texture = AssetCache(rl.Image, rl.Texture, caches.TextureCache);
pub const font = AssetCache(caches.FontCache.FontData, rl.Font, caches.FontCache);
pub const sound = AssetCache(rl.Wave, rl.Sound, caches.SoundCache);
pub const shader = AssetCache(caches.ShaderCache.ShaderData, rl.Shader, caches.ShaderCache);
pub const image = AssetCache(rl.Image, rl.Image, caches.ImageCache);
pub const music_stream = AssetCache(caches.MusicStreamCache.MusicStreamConfig, rl.Music, caches.MusicStreamCache);
pub const music = music_stream;
