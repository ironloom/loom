const std = @import("std");
const lm = @import("../root.zig");
const builtin = @import("builtin");

pub const paths = struct {
    pub var debug: []const u8 = "src" ++ std.fs.path.sep_str ++ "assets";
    pub var release: []const u8 = "assets";

    pub fn use(config: struct {
        debug: ?[]const u8 = null,
        release: ?[]const u8 = null,
    }) void {
        if (config.debug) |debug_path|
            debug = debug_path;

        if (config.release) |release_path|
            release = release_path;

        deinit();
    }
};

var cached_base_path: ?[:0]const u8 = null;

pub fn deinit() void {
    if (cached_base_path) |base_path| {
        lm.allocators.generic().free(base_path);
        cached_base_path = null;
    }
}

pub fn getBase() ![]const u8 {
    if (cached_base_path) |base_path| return base_path;

    const executable_path = switch (builtin.mode) {
        .debug => try std.Io.Dir.cwd().realPathFileAlloc(
            lm.io.singleThreaded(),
            ".",
            lm.allocators.generic(),
        ),
        else => try std.process.executablePathAlloc(
            lm.io.singleThreaded(),
            lm.allocators.generic(),
        ),
    };
    defer lm.allocators.generic().free(executable_path);

    const combined_path = try std.fmt.allocPrint(lm.allocators.generic(), "{s}{s}{s}", .{
        executable_path, std.fs.path.sep_str,
        switch (builtin.mode) {
            .debug => paths.debug,
            else => paths.release,
        },
    });
    defer lm.allocators.generic().free(combined_path);

    const resolved_base_path = try std.Io.Dir.cwd().realPathFileAlloc(
        lm.io.singleThreaded(),
        combined_path,
        lm.allocators.generic(),
    );
    cached_base_path = resolved_base_path;

    return resolved_base_path;
}

pub fn getFilePath(relative_path: []const u8) ![]const u8 {
    const base_path = try getBase();

    return try std.fmt.allocPrint(lm.allocators.generic(), "{s}{s}{s}", .{ base_path, std.fs.path.sep_str, relative_path });
}

pub fn getFileExt(relative_path: []const u8) ![]const u8 {
    const extension_index = std.mem.lastIndexOf(u8, relative_path, ".") orelse 0;
    const extension_buffer = try lm.allocators.generic().alloc(u8, relative_path.len - extension_index);
    std.mem.copyForwards(u8, extension_buffer, relative_path[extension_index..]);

    return extension_buffer;
}

pub fn getData(relative_path: []const u8) ![]const u8 {
    const real_path = try getFilePath(relative_path);
    defer lm.allocators.generic().free(real_path);

    const read_file = try std.Io.Dir.cwd().openFile(
        lm.io.singleThreaded(),
        real_path,
        .{ .mode = .read_only },
    );
    defer read_file.close(lm.io.singleThreaded());

    var buffer: [1024]u8 = @splat(0);
    var reader = read_file.reader(lm.io.singleThreaded(), &buffer);

    return try reader.interface.allocRemaining(lm.allocators.generic(), .unlimited);
}
