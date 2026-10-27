const std = @import("std");
const lm = @import("../root.zig");
const rl = lm.deps.rl;

pub const AssetCache = @import("asset_cache.zig").AssetCache;
pub const files = @import("files.zig");

pub fn deinit() void {
    inline for (@typeInfo(@This()).@"struct".decl_names) |decl_name| {
        const T = @field(@This(), decl_name);
        if (@typeInfo(@TypeOf(T)) == .type and @hasDecl(T, "deinit")) {
            T.deinit();
        }
    }
}

const caches = @import("caches/caches.zig");

pub const texture = AssetCache(rl.Texture, caches.TextureCache);
pub const font = AssetCache(rl.Font, caches.FontCache);
pub const sound = AssetCache(rl.Sound, caches.SoundCache);
pub const shader = AssetCache(rl.Shader, caches.ShaderCache);
pub const image = AssetCache(rl.Image, caches.ImageCache);
pub const music_stream = AssetCache(rl.Music, caches.MusicStreamCache);
pub const music = music_stream;

