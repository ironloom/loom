const std = @import("std");
const loom = @import("../root.zig");
const builtin = @import("builtin");

const files = @import("files.zig");

const Allocator = std.mem.Allocator;

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

pub fn AssetCache(comptime T: type, comptime Definitions: type) type {
    return struct {
        pub const Value = T;
        const HashMapType = std.AutoHashMap(u64, RefCounter(T));

        var hash_map: ?HashMapType = null;

        const has_parse = @hasDecl(Definitions, "parse");
        const has_upload = @hasDecl(Definitions, "upload");
        const has_release = @hasDecl(Definitions, "release");
        const has_release_raw = @hasDecl(Definitions, "releaseRaw");

        comptime {
            if (!has_parse and !has_upload) {
                @compileError("Definitions struct must have a parse() or upload() declaration.");
            }
        }

        fn hashMap() *HashMapType {
            return &(hash_map orelse Blk: {
                hash_map = HashMapType.init(loom.allocators.generic());
                break :Blk hash_map.?;
            });
        }

        pub fn deinit() void {
            const hmap = hashMap();
            var hmap_iter = hmap.iterator();

            while (hmap_iter.next()) |entry| {
                var ref_counter = entry.value_ptr.*;

                if (has_release) {
                    @call(.auto, Definitions.release, .{ref_counter.value.*});
                }
                ref_counter.counter = 0;
                ref_counter.deinit();
            }
            hmap.deinit();
            hash_map = null;
        }

        fn createAssetHash(str: []const u8, mod: u64) u64 {
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

            return createAssetHash(rel_path, loom.coerceTo(u64, modifier_hash) orelse 0);
        }

        pub fn store(rel_path: []const u8, modifiers: []const i32) !*T {
            const HASH = parseModifierHashAndGetCompleteHash(rel_path, modifiers);
            const hmap = hashMap();

            if (hmap.getPtr(HASH)) |rc| {
                return rc.get();
            }

            const data = try files.getData(rel_path);
            defer loom.allocators.generic().free(data);

            const filetype = try files.getFileExt(rel_path);
            defer loom.allocators.generic().free(filetype);

            const parsed: T = Blk: {
                if (has_parse and has_upload) {
                    const raw = try @call(.auto, Definitions.parse, .{
                        data,
                        filetype,
                        rel_path,
                        modifiers,
                    });
                    defer if (has_release_raw) @call(.auto, Definitions.releaseRaw, .{raw});
                    break :Blk try @call(.auto, Definitions.upload, .{raw});
                } else if (has_parse) {
                    break :Blk try @call(.auto, Definitions.parse, .{
                        data,
                        filetype,
                        rel_path,
                        modifiers,
                    });
                } else if (has_upload) {
                    break :Blk try @call(.auto, Definitions.upload, .{
                        data,
                        filetype,
                        rel_path,
                        modifiers,
                    });
                } else {
                    unreachable;
                }
            };

            const ref_counter = try RefCounter(T).init(loom.allocators.generic(), parsed);
            try hmap.put(HASH, ref_counter);
            return ref_counter.value;
        }

        fn releaseHash(hash: u64) void {
            const hmap = hashMap();

            if (hmap.getPtr(hash)) |ref_counter| {
                ref_counter.counter -= 1;

                if (ref_counter.counter > 0)
                    return;

                if (has_release) {
                    @call(.auto, Definitions.release, .{ref_counter.value.*});
                }
                ref_counter.deinit();
                _ = hmap.remove(hash);
            }
        }

        pub fn release(rel_path: []const u8, modifiers: []const i32) void {
            const path_hash = parseModifierHashAndGetCompleteHash(rel_path, modifiers);
            releaseHash(path_hash);
        }

        pub fn releasePtr(ptr: *T) void {
            const hmap = hashMap();

            var iter = hmap.iterator();
            while (iter.next()) |entry| {
                const value_ptr = entry.value_ptr.*.value;

                if (loom.coerceTo(usize, value_ptr) == loom.coerceTo(usize, ptr)) {
                    releaseHash(entry.key_ptr.*);
                    return;
                }
            }
        }

        pub fn get(rel_path: []const u8, modifiers: []const i32) ?*T {
            const HASH = parseModifierHashAndGetCompleteHash(rel_path, modifiers);
            const hmap = hashMap();

            if (hmap.getPtr(HASH)) |rc| {
                return rc.get();
            }

            return store(rel_path, modifiers) catch null;
        }
    };
}
