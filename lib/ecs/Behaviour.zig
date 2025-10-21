const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("string.h");
    @cInclude("stdlib.h");
});

pub fn Behaviour(comptime T: type) type {
    return struct {
        const FnType = ?(*const fn (self: *anyopaque, target: *T) anyerror!void);
        pub const Events = enum { awake, start, update, tick, end };
        const Error = error{OutOfMemory};
        const FunctionType = enum {
            generic,
            reversed,
            self_only,
            target_only,
            empty,
        };

        const Self = @This();

        cache: *anyopaque,
        cache_size: usize = 0,
        name: []const u8 = "UNNAMED_BEHAVIOUR",
        hash: u64,
        initalised: bool = false,
        marked_for_removal: bool = false,

        awake: FnType = null,
        start: FnType = null,
        update: FnType = null,
        tick: FnType = null,
        end: FnType = null,

        pub fn init(value: anytype) !Self {
            const K: type = comptime @TypeOf(value);

            const c_ptr = std.c.malloc(@sizeOf(K)) orelse return Error.OutOfMemory;
            const ptr: *K = @ptrCast(@alignCast(c_ptr));
            ptr.* = value;

            var self = Self{
                .cache = @ptrCast(@alignCast(ptr)),
                .cache_size = @sizeOf(K),

                .name = @typeName(K),
                .hash = comptime calculateHash(K),
            };
            self.attachEvents(K);

            return self;
        }

        pub fn deinit(self: *Self) void {
            std.c.free(self.cache);
            self.* = undefined;
        }

        pub fn duplicate(self: Self) !Self {
            const c_ptr = std.c.malloc(self.cache_size) orelse return Error.OutOfMemory;
            _ = c.memccpy(c_ptr, self.cache, @intCast(self.cache_size), @intCast(1));

            var new = Self{
                .cache = c_ptr,
                .cache_size = self.cache_size,

                .name = self.name,
                .hash = self.hash,
            };

            new.awake = self.awake;
            new.start = self.start;
            new.update = self.update;
            new.tick = self.tick;
            new.end = self.end;

            return new;
        }

        pub fn add(self: *Self, event: Events, callback: FnType) void {
            switch (event) {
                .awake => self.awake = callback,
                .start => self.start = callback,
                .update => self.update = callback,
                .tick => self.tick = callback,
                .end => self.end = callback,
            }
        }

        pub fn callSafe(self: *Self, event: Events, target: *T) void {
            defer if (event == .awake) {
                self.initalised = true;
            };

            const func = switch (event) {
                .awake => self.awake,
                .start => self.start,
                .update => self.update,
                .tick => self.tick,
                .end => self.end,
            } orelse return;

            func(self.cache, target) catch {
                std.log.err("behaviour event failed ({s}({x})->{s}.{s})", .{
                    target.id,
                    target.uuid,
                    self.name,
                    switch (event) {
                        .awake => "Awake",
                        .start => "Start",
                        .end => "End",
                        .update => "Update",
                        .tick => "Tick",
                    },
                });
            };
        }

        inline fn determineFunctionType(comptime K: type, comptime info: std.builtin.Type.Fn) ?FunctionType {
            switch (info.params.len) {
                2 => {
                    if (info.params[0].type == *K and info.params[1].type == *T) return FunctionType.generic;
                    if (info.params[0].type == *T and info.params[1].type == *K) return FunctionType.reversed;
                },
                1 => {
                    if (info.params[0].type == *K) return FunctionType.self_only;
                    if (info.params[0].type == *T) return FunctionType.target_only;
                },
                0 => {
                    return FunctionType.empty;
                },
                else => {},
            }
            return null;
        }

        fn attachEvents(self: *Self, comptime K: type) void {
            // 5 Function types are excepted
            //  - fn(*Self, *K) - Generic
            //  - fn(*K, *Self) - Reversed
            //  - fn(*Self)     - SelfOnly
            //  - fn(*K)        - TargetOnly
            //  - fn()          - Empty

            const wrapper = struct {
                fn call(comptime fn_name: []const u8, cache: *anyopaque, target: *T) !void {
                    std.debug.assert(std.meta.hasFn(K, fn_name));

                    const func = comptime @field(K, fn_name);
                    const typeinfo = comptime @typeInfo(@TypeOf(func)).@"fn";

                    if (comptime (typeinfo.return_type.? == void))
                        switch ((comptime determineFunctionType(K, typeinfo)) orelse return) {
                            .generic => @call(.auto, func, .{ @as(*K, @ptrCast(@alignCast(cache))), target }),
                            .reversed => @call(.auto, func, .{ target, @as(*K, @ptrCast(@alignCast(cache))) }),
                            .self_only => @call(.auto, func, .{@as(*K, @ptrCast(@alignCast(cache)))}),
                            .target_only => @call(.auto, func, .{target}),
                            .empty => @call(.auto, func, .{}),
                        }
                    else
                        try switch ((comptime determineFunctionType(K, typeinfo)) orelse return) {
                            .generic => @call(.auto, func, .{ @as(*K, @ptrCast(@alignCast(cache))), target }),
                            .reversed => @call(.auto, func, .{ target, @as(*K, @ptrCast(@alignCast(cache))) }),
                            .self_only => @call(.auto, func, .{@as(*K, @ptrCast(@alignCast(cache)))}),
                            .target_only => @call(.auto, func, .{target}),
                            .empty => @call(.auto, func, .{}),
                        };
                }

                pub fn awake(cache: *anyopaque, target: *T) !void {
                    try call("Awake", cache, target);
                }

                pub fn start(cache: *anyopaque, target: *T) !void {
                    try call("Start", cache, target);
                }
                pub fn end(cache: *anyopaque, target: *T) !void {
                    try call("End", cache, target);
                }

                pub fn update(cache: *anyopaque, target: *T) !void {
                    try call("Update", cache, target);
                }
                pub fn tick(cache: *anyopaque, target: *T) !void {
                    try call("Tick", cache, target);
                }
            };

            if (std.meta.hasFn(K, "Awake")) self.add(.awake, wrapper.awake);

            if (std.meta.hasFn(K, "Start")) self.add(.start, wrapper.start);
            if (std.meta.hasFn(K, "End")) self.add(.end, wrapper.end);

            if (std.meta.hasFn(K, "Update")) self.add(.update, wrapper.update);
            if (std.meta.hasFn(K, "Tick")) self.add(.tick, wrapper.tick);
        }

        pub fn castBack(self: *Self, comptime K: type) ?*K {
            return if (self.isType(K)) @ptrCast(@alignCast(self.cache)) else null;
        }

        pub inline fn isType(self: *Self, comptime K: type) bool {
            return self.hash == comptime calculateHash(K);
        }
    };
}

pub inline fn calculateHash(comptime T: type) u64 {
    const struct_hash: comptime_int = comptime switch (@typeInfo(T)) {
        .@"struct", .@"enum" => blk: {
            var fieldsum: comptime_int = 1;

            for (std.meta.fields(T), 0..) |field, index| {
                for (field.name, 0..) |char, jndex| {
                    fieldsum += (@as(comptime_int, @intCast(char)) *
                        (@as(comptime_int, @intCast(jndex)) + 1) *
                        (@as(comptime_int, @intCast(index)) + 1)) % std.math.maxInt(u63);
                }
            }

            break :blk fieldsum;
        },
        else => 1,
    };

    var name_hash: comptime_int = 0;

    inline for (@typeName(T)) |char| {
        name_hash += @as(comptime_int, @intCast(char)) *
            (@as(comptime_int, @intCast(@alignOf(T))) + 1);
    }

    return (@max(1, @sizeOf(T)) * @max(1, @alignOf(T)) +
        @max(1, @bitSizeOf(T)) * @max(1, @alignOf(T)) +
        struct_hash * name_hash * @max(1, @alignOf(T)) * 13) % std.math.maxInt(u63);
}
