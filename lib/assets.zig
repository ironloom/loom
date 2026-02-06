const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const loom = @import("./root.zig");
const rl = @import("raylib");

const builtin = @import("builtin");

const Image = rl.Image;
const Texture = rl.Texture;
const Wave = rl.Wave;
const Sound = rl.Sound;
const Font = rl.Font;
const Shader = rl.Shader;

pub const files = struct {
    pub const paths = struct {
        pub var debug: []const u8 = "src" ++ std.fs.path.sep_str ++ "assets";
        pub var release: []const u8 = "assets";

        pub fn use(config: struct {
            debug: ?[]const u8 = null,
            release: ?[]const u8 = null,
        }) void {
            if (config.debug) |d|
                debug = d;

            if (config.release) |r|
                release = r;
        }
    };

    pub fn getBase() ![]const u8 {
        const exepath = switch (builtin.mode) {
            .Debug => try std.fs.cwd().realpathAlloc(loom.allocators.generic(), "."),
            else => try std.fs.selfExeDirPathAlloc(loom.allocators.generic()),
        };
        defer loom.allocators.generic().free(exepath);

        const path = try std.fmt.allocPrint(loom.allocators.generic(), "{s}{s}{s}", .{
            exepath, std.fs.path.sep_str, switch (builtin.mode) {
                .Debug => paths.debug,
                else => paths.release,
            },
        });

        return path;
    }

    pub fn getFilePath(rel_path: []const u8) ![]const u8 {
        const basepath = try files.getBase();
        defer loom.allocators.generic().free(basepath);

        return try std.fmt.allocPrint(loom.allocators.generic(), "{s}{s}{s}", .{ basepath, std.fs.path.sep_str, rel_path });
    }

    pub fn getFileExt(rel_path: []const u8) ![]const u8 {
        const index = std.mem.lastIndexOf(u8, rel_path, ".") orelse 0;
        const buf = try loom.allocators.generic().alloc(u8, rel_path.len - index);
        std.mem.copyForwards(u8, buf, rel_path[index..]);

        return buf;
    }

    pub fn getData(pth: []const u8) ![]const u8 {
        const real_path = try getFilePath(pth);
        defer loom.allocators.generic().free(real_path);

        const reader = try std.fs.openFileAbsolute(real_path, .{});
        defer reader.close();

        return reader.readToEndAlloc(loom.allocators.generic(), 8 * 1024 * 1024 * 512);
    }
};

fn RefCounter(comptime T: type) type {
    return struct {
        value: *T,
        counter: usize,
        alloc: Allocator,

        pub fn init(allocator: Allocator, value: T) !RefCounter(T) {
            const allocated_value = try allocator.create(T);
            allocated_value.* = value;

            return RefCounter(T){
                .counter = 1,
                .value = allocated_value,
                .alloc = allocator,
            };
        }

        pub fn deinit(self: *RefCounter(T)) void {
            self.alloc.destroy(self.value);
            self.* = undefined;
        }

        pub fn get(self: *RefCounter(T)) *T {
            self.counter += 1;
            return self.value;
        }
    };
}

fn AssetCache(
    comptime T: type,
    comptime parsefn: *const fn (data: []const u8, filetype: []const u8, path: []const u8, mod: []const i32) anyerror!T,
    comptime releasefn: *const fn (data: T) void,
) type {
    return struct {
        const HashMapType = std.AutoHashMap(u64, RefCounter(T));
        var hash_map: ?HashMapType = null;

        fn hashMap() *HashMapType {
            return &(hash_map orelse Blk: {
                hash_map = HashMapType.init(loom.allocators.generic());
                break :Blk hash_map.?;
            });
        }

        pub fn deinit() void {
            const hmap = hashMap();
            var iter = hmap.iterator();

            while (iter.next()) |entry| {
                var ref_counter = entry.value_ptr.*;

                releasefn(ref_counter.value.*);
                ref_counter.counter = 0;

                _ = hmap.remove(entry.key_ptr.*);
                ref_counter.deinit();
            }

            hmap.deinit();
        }

        fn hash(str: []const u8, mod: u64) u64 {
            const RANDOM_PRIME: comptime_int = 37;
            const MAX: comptime_int = std.math.maxInt(u63);
            const POWER_MAX: comptime_int = std.math.maxInt(u32);
            var power: u64 = 1;

            const STRING_SUM: u64 = Blk: {
                var hash_value: u64 = 0;

                for (str) |char| {
                    hash_value = (hash_value + (char - @min(char, '0') + 1) * power) % MAX;
                    power = (RANDOM_PRIME * power) % POWER_MAX;
                }

                break :Blk hash_value;
            };

            return STRING_SUM + mod * RANDOM_PRIME;
        }

        fn parseModifierHashAndGetCompleteHash(rel_path: []const u8, modifiers: []const i32) u64 {
            var modifier_hash: u64 = 0;
            for (modifiers, 0..) |modifier, index| {
                const non_negaitve_modifier = (if (modifier < 0) @as(i32, -1) else @as(i32, 1)) * modifier;

                modifier_hash +%= @as(u64, @intCast(non_negaitve_modifier)) * (index + 1);
            }

            return hash(rel_path, loom.coerceTo(u64, modifier_hash) orelse 0);
        }

        pub fn store(rel_path: []const u8, modifiers: []const i32) !void {
            const hmap = hashMap();
            const HASH = parseModifierHashAndGetCompleteHash(rel_path, modifiers);
            if (hmap.contains(HASH)) return;

            const data = try files.getData(rel_path);
            defer loom.allocators.generic().free(data);

            const filetype = try files.getFileExt(rel_path);
            defer loom.allocators.generic().free(filetype);

            const parsed: T = try parsefn(data, filetype, rel_path, modifiers);

            try hmap.put(HASH, try .init(loom.allocators.generic(), parsed));
        }

        pub fn release(rel_path: []const u8, modifiers: []const i32) void {
            const path_hash = parseModifierHashAndGetCompleteHash(rel_path, modifiers);
            const hmap = hashMap();

            var ref_counter = hmap.getPtr(path_hash) orelse return;

            ref_counter.counter -= 1;

            if (ref_counter.counter > 0)
                return;

            releasefn(ref_counter.value.*);
            ref_counter.deinit();
            _ = hmap.remove(path_hash);
        }

        pub fn releasePtr(ptr: *T) void {
            const hmap = hashMap();

            const entry: HashMapType.Entry = Blk: {
                var iter = hmap.iterator();
                while (iter.next()) |entry| {
                    const value_ptr = entry.value_ptr.*.value;

                    if (loom.coerceTo(usize, value_ptr) != loom.coerceTo(usize, ptr)) continue;
                    break :Blk entry;
                }
                break :Blk null;
            } orelse return;

            const ref_counter = entry.value_ptr;
            const entry_hash = entry.key_ptr.*;

            ref_counter.counter -= 1;

            if (ref_counter.counter > 0)
                return;

            releasefn(ref_counter.value.*);
            ref_counter.deinit();

            _ = hmap.remove(entry_hash);
        }

        pub fn get(rel_path: []const u8, modifiers: []const i32) ?*T {
            const HASH = parseModifierHashAndGetCompleteHash(rel_path, modifiers);

            const hmap = hashMap();

            const res1 = hmap.getPtr(HASH);
            if (res1) |r1| return r1.get();

            store(rel_path, modifiers) catch return null;
            return if (hmap.getPtr(HASH)) |r| r.get() else null;
        }
    };
}

pub const image = AssetCache(
    Image,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, _: []const u8, modifiers: []const i32) !Image {
            const str: [:0]const u8 = loom.allocators.generic().dupeZ(u8, filetype) catch ".png";
            defer loom.allocators.generic().free(str);

            const width = if (modifiers.len > 0) @max(1, modifiers[0]) else 1;
            const height = if (modifiers.len > 1) @max(1, modifiers[1]) else 1;

            var img = try rl.loadImageFromMemory(str, data);
            rl.imageResizeNN(&img, width, height);

            return img;
        }
    }.callback,
    struct {
        pub fn callback(data: Image) void {
            rl.unloadImage(data);
        }
    }.callback,
);

pub const texture = AssetCache(
    Texture,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, _: []const u8, modifiers: []const i32) !Texture {
            const str: [:0]const u8 = loom.allocators.generic().dupeZ(u8, filetype) catch ".png";
            defer loom.allocators.generic().free(str);

            var img = try rl.loadImageFromMemory(str, data);
            defer rl.unloadImage(img);

            const width = if (modifiers.len > 0) @max(1, modifiers[0]) else 1;
            const height = if (modifiers.len > 1) @max(1, modifiers[1]) else 1;

            rl.imageResizeNN(&img, width, height);

            const txtr = try rl.loadTextureFromImage(img);
            return txtr;
        }
    }.callback,
    struct {
        pub fn callback(data: Texture) void {
            rl.unloadTexture(data);
        }
    }.callback,
);

pub const font = AssetCache(
    Font,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, _: []const u8, fchars: []const i32) !Font {
            const str: [:0]const u8 = loom.allocators.generic().dupeZ(u8, filetype) catch ".png";
            defer loom.allocators.generic().free(str);

            var font_chars_base = [_]i32{
                48, 49, 50, 51, 52, 53, 54, 55, 56, 57, // 0-9
                65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, // A-Z
                97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, // a-z
                33, 34, 35, 36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  58,  59,  60,  61,  62,  63,  64,  91,  92,  93,  94,
                95, 96, 123, 124, 125, 126, // !, ", #, $, %, &, ', (, ), *, +, ,, -, ., /, :, ;, <, =, >, ?, @, [, \, ], ^, _, `, {, |, }, ~
            };

            const font_chars: []const i32 = if (fchars.len == 0) &font_chars_base else fchars;

            const fnt = try rl.loadFontFromMemory(str, data, loom.toi32(font_chars.len), font_chars);
            return fnt;
        }
    }.callback,
    struct {
        pub fn callback(data: Font) void {
            rl.unloadFont(data);
        }
    }.callback,
);

pub const sound = AssetCache(
    Sound,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, _: []const u8, _: []const i32) !Sound {
            const str: [:0]const u8 = try loom.allocators.generic().dupeZ(u8, filetype);
            defer loom.allocators.generic().free(str);

            const wave = try rl.loadWaveFromMemory(str, data);
            defer rl.unloadWave(wave);

            return rl.loadSoundFromWave(wave);
        }
    }.callback,
    struct {
        pub fn callback(data: Sound) void {
            rl.unloadSound(data);
        }
    }.callback,
);

pub const shader = AssetCache(
    Shader,
    struct {
        pub fn callback(data: []const u8, filetype: []const u8, filename: []const u8, _: []const i32) !Shader {
            var fragment_shader_c_data: ?[:0]const u8 = null;
            defer if (fragment_shader_c_data) |fscd| loom.allocators.generic().free(fscd);

            var vertex_shader_c_data: ?[:0]const u8 = null;
            defer if (vertex_shader_c_data) |vscd| loom.allocators.generic().free(vscd);

            const other_shader_filename = try std.mem.concat(loom.allocators.generic(), u8, &.{
                filename[0 .. filename.len - 2],
                if (std.mem.eql(u8, filetype, ".fs")) "vs" else "fs",
            });
            defer loom.allocators.generic().free(other_shader_filename);

            if (std.mem.eql(u8, filetype, ".fs")) {
                const vertex_shader_data: ?[]const u8 = files.getData(other_shader_filename) catch null;
                defer if (vertex_shader_data) |vsd| loom.allocators.generic().free(vsd);

                vertex_shader_c_data = if (vertex_shader_data) |vs|
                    try loom.allocators.generic().dupeZ(u8, vs)
                else
                    null;

                fragment_shader_c_data = try loom.allocators.generic().dupeZ(u8, data);
            } else {
                const fragment_shader_data: ?[]const u8 = files.getData(other_shader_filename) catch null;
                defer if (fragment_shader_data) |fsd| loom.allocators.generic().free(fsd);

                fragment_shader_c_data = if (fragment_shader_data) |vs|
                    try loom.allocators.generic().dupeZ(u8, vs)
                else
                    null;

                vertex_shader_c_data = try loom.allocators.generic().dupeZ(u8, data);
            }

            return try rl.loadShaderFromMemory(vertex_shader_c_data, fragment_shader_c_data);
        }
    }.callback,
    struct {
        pub fn callback(data: Shader) void {
            rl.unloadShader(data);
        }
    }.callback,
);

pub fn deinit() void {
    texture.deinit();
    image.deinit();
    font.deinit();
    sound.deinit();
    shader.deinit();
}
