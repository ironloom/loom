const std = @import("std");
const lm = @import("../../root.zig");
const rl = lm.deps.rl;

const AssetPromise = @import("../asset_promise.zig").AssetPromise;

pub const FontData = struct {
    file_type: [:0]const u8,
    file_data: []const u8,
    font_chars: []i32,
    font_height_px: i32,
};

pub fn parse(
    data: []const u8,
    filetype: []const u8,
    path: []const u8,
    mod: []const i32,
) !FontData {
    _ = path;

    if (mod.len == 0) return error.InvalidModifiers;

    const font_height = lm.toi32(mod[0]);
    const fchars = if (mod.len >= 2) mod[1..] else &.{};

    const file_type = try lm.allocators.generic().dupeSentinel(u8, filetype, 0);
    errdefer lm.allocators.generic().free(file_type);

    const file_data = try lm.allocators.generic().dupe(u8, data);
    errdefer lm.allocators.generic().free(file_data);

    const font_chars_base = [_]i32{
        48, 49, 50, 51, 52, 53, 54, 55, 56, 57, // 0-9
        65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, // A-Z
        97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, // a-z
        33, 34, 35, 36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  58,  59,  60,  61,  62,  63,  64,  91,  92,  93,  94,
        95, 96, 123, 124, 125, 126, // !, ", #, $, %, &, ', (, ), *, +, ,, -, ., /, :, ;, <, =, >, ?, @, [, \, ], ^, _, `, {, |, }, ~
    };

    const font_chars: []i32 = try lm.allocators.generic().alloc(
        i32,
        if (fchars.len == 0)
            font_chars_base.len
        else
            fchars.len,
    );

    if (fchars.len == 0) {
        @memcpy(font_chars[0..], font_chars_base[0..font_chars.len]);
    } else {
        @memcpy(font_chars[0..], fchars[0..font_chars.len]);
    }

    return FontData{
        .file_data = file_data,
        .file_type = file_type,
        .font_chars = font_chars,
        .font_height_px = font_height,
    };
}

pub fn releaseRaw(raw: FontData) void {
    const allocator = lm.allocators.generic();

    allocator.free(raw.file_data);
    allocator.free(raw.file_type);
    allocator.free(raw.font_chars);
}

pub fn upload(raw: FontData) !rl.Font {
    return try rl.loadFontFromMemory(raw.file_type, raw.file_data, raw.font_height_px, raw.font_chars);
}

pub fn release(uploaded: rl.Font) void {
    rl.unloadFont(uploaded);
}
