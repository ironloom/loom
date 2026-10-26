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
        if (config.debug) |d|
            debug = d;

        if (config.release) |r|
            release = r;
    }
};

pub fn getBase() ![]const u8 {
    const exepath = switch (builtin.mode) {
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
    defer lm.allocators.generic().free(exepath);

    const path = try std.fmt.allocPrint(lm.allocators.generic(), "{s}{s}{s}", .{
        exepath, std.fs.path.sep_str,
        switch (builtin.mode) {
            .debug => paths.debug,
            else => paths.release,
        },
    });
    defer lm.allocators.generic().free(path);

    const result = try std.Io.Dir.cwd().realPathFileAlloc(lm.io.singleThreaded(), path, lm.allocators.generic());
    defer lm.allocators.generic().free(result);

    return std.fmt.allocPrint(lm.allocators.generic(), "{s}", .{result});
}

pub fn getFilePath(rel_path: []const u8) ![]const u8 {
    const basepath = try getBase();
    defer lm.allocators.generic().free(basepath);

    return try std.fmt.allocPrint(lm.allocators.generic(), "{s}{s}{s}", .{ basepath, std.fs.path.sep_str, rel_path });
}

pub fn getFileExt(rel_path: []const u8) ![]const u8 {
    const index = std.mem.lastIndexOf(u8, rel_path, ".") orelse 0;
    const buf = try lm.allocators.generic().alloc(u8, rel_path.len - index);
    std.mem.copyForwards(u8, buf, rel_path[index..]);

    return buf;
}

pub fn getData(pth: []const u8) ![]const u8 {
    const real_path = try getFilePath(pth);
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
