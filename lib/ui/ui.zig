const std = @import("std");
const lm = @import("../root.zig");

const Allocator = @import("std").mem.Allocator;
const clay = @import("zclay");

const rl = @import("raylib");
const rg = @import("raygui");

const renderer = @import("clay_rl_backend.zig");

/// Opens a new clay element with the given config.
pub fn new(config: clay.ElementDeclaration) *const fn (void) void {
    clay.cdefs.Clay__OpenElement();
    clay.cdefs.Clay__ConfigureOpenElement(config);

    return struct {
        pub fn callback(_: void) void {
            clay.cdefs.Clay__CloseElement();
        }
    }.callback;
}

pub const text = clay.text;

var memory: []u8 = undefined;

const TextureCache = struct {
    name: []const u8,

    texture: *rl.Texture2D,
    size: lm.Vector2,
    refs: usize,
};

const FontEntry = struct {
    const Self = @This();

    name: []const u8,
    id: u16,

    pub fn init(name: []const u8, id: anytype) Self {
        return .{
            .name = name,
            .id = lm.coerceTo(u16, id) orelse 0,
        };
    }
};

var textures: lm.List(TextureCache) = undefined;
var fonts: lm.List(FontEntry) = undefined;
var fonts_cache: lm.List(FontEntry) = undefined;
var font_index: usize = 1;
var alloc: std.mem.Allocator = undefined;
var last_window_size: lm.Vector2 = .init(0, 0);

pub fn init(allocator: Allocator) !void {
    fonts = .init(allocator);
    fonts_cache = .init(allocator);
    textures = .init(allocator);
    alloc = allocator;

    const min_memory_size: usize = lm.coerceTo(usize, clay.minMemorySize()).?;
    memory = try alloc.alloc(u8, min_memory_size);

    const arena: clay.Arena = clay.createArenaWithCapacityAndMemory(memory);

    _ = clay.initialize(arena, .{ .h = 1280, .w = 720 }, .{});
    clay.setMeasureTextFunction(void, {}, renderer.measureText);

    renderer.raylib_fonts[0] = try rl.getFontDefault();
}

pub fn update(commands: *clay.ClayArray(clay.RenderCommand)) !void {
    const win_size = lm.window.size.get();
    if (last_window_size.equals(win_size) != 0) {
        last_window_size = win_size;

        clay.setLayoutDimensions(.{
            .w = win_size.x,
            .h = win_size.y,
        });
    }

    try renderer.clayRaylibRender(commands, lm.allocators.generic());

    const cache_len = fonts_cache.len();
    for (1..cache_len + 1) |j| {
        const index = cache_len - j;
        const cached = fonts_cache.items()[index];

        lm.assets.font.release(cached.name, &.{});
        _ = fonts_cache.swapRemove(index);
    }

    fonts_cache.deinit();
    fonts_cache = try fonts.clone();

    fonts.clearAndFree();

    for (textures.items()) |*texture| {
        if (texture.refs == 0) lm.assets.texture.release(texture.name, &.{ 1, 1 });
        texture.refs = 0;
    }
}

pub fn deinit() void {
    const fonts_len = fonts.len();
    for (1..fonts_len + 1) |j| {
        const index = fonts_len - j;
        const current = fonts.items()[index];

        lm.assets.font.release(current.name, &.{});
        _ = fonts.swapRemove(index);
    }

    const cache_len = fonts_cache.len();
    for (1..cache_len + 1) |j| {
        const index = cache_len - j;
        const cached = fonts_cache.items()[index];

        lm.assets.font.release(cached.name, &.{});
        _ = fonts_cache.swapRemove(index);
    }

    const textures_len = textures.len();
    for (1..textures_len + 1) |j| {
        const index = textures_len - j;
        const texture = textures.items()[index];

        lm.assets.texture.release(texture.name, &.{});
        _ = textures.swapRemove(index);
    }

    fonts_cache.deinit();
    fonts.deinit();
    textures.deinit();

    alloc.free(memory);
}

fn loadFont(rel_path: []const u8) !void {
    renderer.raylib_fonts[font_index] = (lm.assets.font.get(rel_path, &.{}) orelse return error.FontNotFound).*;
    rl.setTextureFilter(renderer.raylib_fonts[font_index].?.texture, .bilinear);
}

/// Get the corresponding font id for a file path
pub fn fontID(rel_path: []const u8) u16 {
    for (fonts.items()) |font_entry| {
        if (!std.mem.eql(u8, font_entry.name, rel_path)) continue;
        if (renderer.raylib_fonts[font_entry.id] == null) continue;
        return font_entry.id;
    }

    for (fonts_cache.items()) |font_entry| {
        if (!std.mem.eql(u8, font_entry.name, rel_path)) continue;
        if (renderer.raylib_fonts[font_entry.id] == null) continue;

        fonts.append(font_entry) catch return 0;
        return font_entry.id;
    }

    font_index += 1;
    if (font_index >= 10) {
        font_index = 1;
    }

    const font_entry: FontEntry = .init(rel_path, font_index);
    loadFont(rel_path) catch return 0;
    fonts.append(font_entry) catch return 0;

    return font_entry.id;
}

pub inline fn color(r: u8, g: u8, b: u8, a: u8) clay.Color {
    return rgba(r, g, b, a);
}

pub inline fn rgba(r: u8, g: u8, b: u8, a: u8) clay.Color {
    return Color.finalise(.{
        .red = lm.tof32(r),
        .green = lm.tof32(g),
        .blue = lm.tof32(b),
        .alpha = lm.tof32(a),
    });
}

pub inline fn rgb(r: u8, g: u8, b: u8) clay.Color {
    return Color.finalise(.{
        .red = lm.tof32(r),
        .green = lm.tof32(g),
        .blue = lm.tof32(b),
    });
}

pub fn opacity(colour: clay.Color, target: f32) clay.Color {
    return .{ colour[0], colour[1], colour[2], target };
}

pub fn dim(colour: clay.Color, by: f32) clay.Color {
    return .{ @max(0, colour[0] - by), @max(0, colour[1] - by), @max(0, colour[2] - by), colour[3] };
}

/// Parses a hex color code (0xRRGGBBAA) into 4 f32 components (0-255).
///
/// Args:
///   hex_color: The 32-bit unsigned integer representing the hex color.
///              Expected format is 0xRRGGBBAA.
///
/// Returns:
///   A struct containing the red, green, blue, and alpha components as f32.
///   Each component will be in the range of 0.0 to 255.0.
pub fn hex(hex_colour: u32) [4]f32 {

    // RR GG BB AA

    const r = lm.tof32((hex_colour >> 24) & 0xFF);
    const g = lm.tof32((hex_colour >> 16) & 0xFF);
    const b = lm.tof32((hex_colour >> 8) & 0xFF);
    const a = lm.tof32(hex_colour & 0xFF);

    return .{ r, g, b, a };
}

pub const Color = struct {
    red: f32 = 0,
    green: f32 = 0,
    blue: f32 = 0,
    alpha: f32 = 255,

    pub fn finalise(self: Color) [4]f32 {
        return [4]f32{ self.red, self.green, self.blue, self.alpha };
    }

    pub const white: clay.Color = finalise(.{ .red = 255, .green = 255, .blue = 255 });
    pub const black: clay.Color = finalise(.{});
};

pub fn image(path: []const u8, size: lm.Vector2) !clay.ImageElementConfig {
    for (textures.items()) |*texture| {
        if (!std.mem.eql(u8, path, texture.name)) continue;

        texture.refs += 1;
        return clay.ImageElementConfig{
            .image_data = texture.texture,
        };
    }

    const entry: TextureCache = .{
        .name = path,
        .refs = 1,
        .size = size,
        .texture = lm.assets.texture.get(path, &.{ lm.toi32(size.x), lm.toi32(size.y) }) orelse return error.NoImageFound,
    };

    try textures.append(entry);

    return clay.ImageElementConfig{
        .image_data = entry.texture,
    };
}
