const std = @import("std");
const loom = @import("../root.zig");
const builtin = @import("builtin");

const files = @import("files.zig");
const AssetPromise = @import("asset_promise.zig").AssetPromise;

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

fn ParseFn(comptime Raw: type) type {
    return *const fn (data: []const u8, filetype: []const u8, path: []const u8, mod: []const i32) anyerror!Raw;
}
fn UploadFn(comptime Raw: type, comptime Uploaded: type) type {
    return *const fn (Raw) anyerror!Uploaded;
}
fn ReleaseFn(comptime Uploaded: type) type {
    return *const fn (data: Uploaded) void;
}

pub fn AssetCache(comptime Raw: type, comptime Uploaded: type, comptime Definitions: type) type {
    return struct {
        pub const Promise = AssetPromise(Raw, Uploaded);
        const HashMapType = std.AutoHashMap(u64, RefCounter(Uploaded));
        const PromiseMapType = std.AutoHashMap(u64, *Promise);

        var hash_map: ?HashMapType = null;
        var promise_map: ?PromiseMapType = null;

        const parseFunction: ParseFn(Raw) = if (@hasDecl(Definitions, "parse"))
            @field(Definitions, "parse")
        else
            @compileError("Definitions struct must have parse() decl.");

        const uploadFunction: UploadFn(Raw, Uploaded) = if (@hasDecl(Definitions, "upload"))
            @field(Definitions, "upload")
        else
            @compileError("Definitions struct must have upload() decl.");

        const releaseFunction: ReleaseFn(Uploaded) = if (@hasDecl(Definitions, "release"))
            @field(Definitions, "release")
        else
            @compileError("Definitions struct must have release() decl.");

        const releaseRawFunction: ?*const fn (Raw) void = if (@hasDecl(Definitions, "releaseRaw"))
            @field(Definitions, "releaseRaw")
        else
            null;

        fn hashMap() *HashMapType {
            return &(hash_map orelse Blk: {
                hash_map = HashMapType.init(loom.allocators.generic());
                break :Blk hash_map.?;
            });
        }

        fn promiseMap() *PromiseMapType {
            return &(promise_map orelse Blk: {
                promise_map = PromiseMapType.init(loom.allocators.generic());
                break :Blk promise_map.?;
            });
        }

        pub fn deinit() void {
            const hmap = hashMap();
            var hmap_iter = hmap.iterator();

            while (hmap_iter.next()) |entry| {
                var ref_counter = entry.value_ptr.*;

                @call(.auto, releaseFunction, .{ref_counter.value.*});
                ref_counter.counter = 0;
                ref_counter.deinit();
            }
            hmap.deinit();
            hash_map = null;

            const pmap = promiseMap();
            var pmap_iter = pmap.iterator();
            while (pmap_iter.next()) |entry| {
                const promise = entry.value_ptr.*;
                if (promise.raw_data) |raw| {
                    if (releaseRawFunction) |relRaw| {
                        relRaw(raw);
                    }
                }
                loom.allocators.generic().destroy(promise);
            }
            pmap.deinit();
            promise_map = null;
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

        const LoadContext = struct {
            promise: *Promise,
            path: []const u8,
            modifiers: []const i32,
            allocator: Allocator,

            fn run(ctx: @This()) void {
                defer {
                    ctx.allocator.free(ctx.path);
                    ctx.allocator.free(ctx.modifiers);
                }

                const data = files.getData(ctx.path) catch {
                    ctx.promise.status.store(.failed, .release);
                    return;
                };
                defer ctx.allocator.free(data);

                const filetype = files.getFileExt(ctx.path) catch {
                    ctx.promise.status.store(.failed, .release);
                    return;
                };
                defer ctx.allocator.free(filetype);

                const parsed: Raw = @call(.auto, parseFunction, .{
                    data,
                    filetype,
                    ctx.path,
                    ctx.modifiers,
                }) catch {
                    ctx.promise.status.store(.failed, .release);
                    return;
                };

                ctx.promise.raw_data = parsed;
                ctx.promise.status.store(.cpu_ready, .release);
            }
        };

        pub fn store(rel_path: []const u8, modifiers: []const i32) !*Promise {
            const HASH = parseModifierHashAndGetCompleteHash(rel_path, modifiers);
            const pmap = promiseMap();

            if (pmap.get(HASH)) |promise_ptr| {
                const hmap = hashMap();
                if (hmap.getPtr(HASH)) |rc| {
                    rc.counter += 1;
                } else {
                    promise_ptr.ref_count += 1;
                }
                return promise_ptr;
            }

            const promise = try loom.allocators.generic().create(Promise);
            promise.* = .{
                .hash = HASH,
                .uploadFn = upload,
                .releaseRawFn = releaseRawFunction,
                .status = .init(.pending),
                .raw_data = null,
                .value = null,
                .ref_count = 1,
            };
            try pmap.put(HASH, promise);

            const duped_path = try loom.allocators.generic().dupe(u8, rel_path);
            errdefer loom.allocators.generic().free(duped_path);

            const duped_modifiers = try loom.allocators.generic().dupe(i32, modifiers);
            errdefer loom.allocators.generic().free(duped_modifiers);

            const ctx = LoadContext{
                .promise = promise,
                .path = duped_path,
                .modifiers = duped_modifiers,
                .allocator = loom.allocators.generic(),
            };

            const thread = std.Thread.spawn(.{}, LoadContext.run, .{ctx}) catch |err| {
                promise.status.store(.failed, .release);
                return err;
            };
            thread.detach();

            return promise;
        }

        pub fn upload(hash: u64, raw: Raw, initial_ref_count: usize) !*Uploaded {
            const hmap = hashMap();
            if (hmap.getPtr(hash)) |ref_counter| {
                return ref_counter.value;
            }

            const value: Uploaded = try @call(.auto, uploadFunction, .{raw});
            var ref_counter = try RefCounter(Uploaded).init(loom.allocators.generic(), value);
            ref_counter.counter = initial_ref_count;
            try hmap.put(hash, ref_counter);
            return ref_counter.value;
        }

        fn releaseHash(hash: u64) void {
            const hmap = hashMap();

            if (hmap.getPtr(hash)) |ref_counter| {
                ref_counter.counter -= 1;

                if (ref_counter.counter > 0)
                    return;

                @call(.auto, releaseFunction, .{ref_counter.value.*});
                ref_counter.deinit();
                _ = hmap.remove(hash);

                const pmap = promiseMap();
                if (pmap.fetchRemove(hash)) |kv| {
                    loom.allocators.generic().destroy(kv.value);
                }
            } else {
                const pmap = promiseMap();
                if (pmap.get(hash)) |promise| {
                    if (promise.ref_count > 0) promise.ref_count -= 1;
                }
            }
        }

        pub fn release(rel_path: []const u8, modifiers: []const i32) void {
            const path_hash = parseModifierHashAndGetCompleteHash(rel_path, modifiers);
            releaseHash(path_hash);
        }

        pub fn releasePromise(promise: *Promise) void {
            releaseHash(promise.hash);
        }

        pub fn releasePtr(ptr: *Uploaded) void {
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

        pub fn get(rel_path: []const u8, modifiers: []const i32) ?*Promise {
            const HASH = parseModifierHashAndGetCompleteHash(rel_path, modifiers);
            const pmap = promiseMap();

            if (pmap.get(HASH)) |promise_ptr| {
                const hmap = hashMap();
                if (hmap.getPtr(HASH)) |rc| {
                    rc.counter += 1;
                } else {
                    promise_ptr.ref_count += 1;
                }
                return promise_ptr;
            }

            return store(rel_path, modifiers) catch null;
        }
    };
}
