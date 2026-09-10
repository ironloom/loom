const std = @import("std");
const loom = @import("root.zig");
const rl = @import("raylib");

const clay = @import("zclay");

var _size = loom.Vec2(860, 480);
var _temp_size = loom.Vec2(860, 480);
var _temp_pos: ?loom.Vector2 = null;
var _temp_fullscreen: bool = false;
var _temp_borderless: bool = false;
var is_resizable = false;

var is_alive = false;

pub var clear_color: rl.Color = rl.Color.black;
pub var use_debug_mode = false;

pub const clearColor = struct {
    pub inline fn set(to: rl.Color) void {
        clear_color = to;
    }

    pub inline fn get() rl.Color {
        return clear_color;
    }
};

pub inline fn setClearColor(to: rl.Color) void {
    clear_color = to;
}

pub inline fn getClearColor() rl.Color {
    return clear_color;
}

pub const setExitKey = rl.setExitKey;

pub fn init() void {
    defer is_alive = true;
    const start_size = size.get();

    rl.initWindow(
        loom.toi32(start_size.x),
        loom.toi32(start_size.y),
        title.get(),
    );
    if (_temp_pos) |pos| {
        rl.setWindowPosition(loom.toi32(pos.x), loom.toi32(pos.y));
    }
    if (_temp_fullscreen) {
        fullscreen.enable();
    }
    if (_temp_borderless) {
        borderless.enable();
    }
    rl.pollInputEvents();
    _size = loom.Vec2(rl.getScreenWidth(), rl.getScreenHeight());
    _temp_size = _size;
    rl.initAudioDevice();
}

pub fn deinit() void {
    defer is_alive = false;

    rl.closeAudioDevice();
    rl.closeWindow();
}

pub fn clearBackground() void {
    rl.clearBackground(clear_color);
}

pub const shouldClose = rl.windowShouldClose;

pub fn toggleDebugMode() void {
    use_debug_mode = !use_debug_mode;
    clay.setDebugModeEnabled(use_debug_mode);
}

/// FPS: frames per second
pub const fpsTarget = struct {
    var state: i32 = 60;

    /// Set the maximum FPS the program can run at
    pub inline fn set(to: anytype) void {
        state = loom.coerceTo(i32, to) orelse 60;
        rl.setTargetFPS(state);
    }

    /// Get the maximum FPS the program can run at
    pub inline fn get() i32 {
        return state;
    }

    /// Get the currect FPS
    pub const getCurrent = rl.getFPS;
};

pub const size = struct {
    inline fn update() void {
        _size = loom.Vec2(rl.getScreenWidth(), rl.getScreenHeight());
        _temp_size = _size;
    }

    pub inline fn set(to: loom.Vector2) void {
        _size = to;
        _temp_size = to;
        if (is_alive) {
            rl.setWindowSize(
                loom.toi32(to.x),
                loom.toi32(to.y),
            );
        }
    }

    pub inline fn get() loom.Vector2 {
        if (!is_alive) return _temp_size;
        if (rl.isWindowResized()) {
            update();
        }
        return _size;
    }
};

pub const resizing = struct {
    pub fn toggle() void {
        set(!is_resizable);
    }

    pub inline fn enable() void {
        set(true);
    }

    pub inline fn disable() void {
        set(false);
    }

    pub inline fn set(to: bool) void {
        is_resizable = to;
        config_flags.set(.{ .window_resizable = true }, is_resizable);
    }

    pub inline fn get() bool {
        return is_resizable;
    }
};

pub const borderless = struct {
    var state: bool = false;

    pub fn enable() void {
        set(true);
    }

    pub fn disable() void {
        set(false);
    }

    pub fn toggle() void {
        set(!state);
    }

    pub fn set(to: bool) void {
        if (state == to) return;

        rl.toggleBorderlessWindowed();
        state = !state;
    }

    pub fn get() bool {
        return state;
    }
};

pub const fullscreen = struct {
    var state: bool = false;

    pub fn enable() void {
        set(true);
    }

    pub fn disable() void {
        set(false);
    }

    pub fn toggle() void {
        set(!state);
    }

    pub fn set(to: bool) void {
        if (state == to) return;

        rl.toggleFullscreen();
        state = !state;
    }

    pub fn get() bool {
        return state;
    }
};

pub const vsync = struct {
    var state: bool = false;
    var before: i32 = 60;

    pub fn enable() void {
        set(true);
    }

    pub fn disable() void {
        set(false);
    }

    pub fn toggle() void {
        set(!state);
    }

    pub fn set(to: bool) void {
        if (state == to) return;

        if (to) {
            before = fpsTarget.get();
            fpsTarget.set(rl.getMonitorRefreshRate(rl.getCurrentMonitor()));

            std.log.info("fps target: {d}", .{rl.getMonitorRefreshRate(rl.getCurrentMonitor())});
        } else {
            fpsTarget.set(before);
        }

        state = !state;
    }

    pub fn get() bool {
        return state;
    }
};

pub const ConfigFlags = rl.ConfigFlags;
pub const config_flags = struct {
    pub fn set(flags: ConfigFlags, enable: bool) void {
        if (!is_alive) {
            if (enable) rl.setConfigFlags(flags);
            return;
        }

        if (enable) {
            rl.setWindowState(flags);
            return;
        }

        rl.clearWindowState(flags);
    }

    pub fn get(flag: ConfigFlags) bool {
        return rl.isWindowState(flag);
    }
};

pub const title = struct {
    var current_title: [:0]const u8 = "[loom] Untitled Project";

    pub fn set(to: [:0]const u8) void {
        if (is_alive) {
            rl.setWindowTitle(to);
            return;
        }
        current_title = to;
    }

    pub fn get() [:0]const u8 {
        return current_title;
    }
};

/// ## `restore_state`
/// Restore state handles window position and size saving and loading.
///
/// **This feature is enabled by default!**
///
/// You can toggle this setting via `.enable()` and `.disable()`.
pub const restore_state = struct {
    var use: bool = true;

    pub fn enable() void {
        use = true;
    }

    pub fn disable() void {
        use = false;
    }

    pub fn set(to: bool) void {
        use = to;
    }

    pub fn get() bool {
        return use;
    }

    pub fn save() !void {
        if (!use) return;

        const exepath = try std.process.executableDirPathAlloc(loom.io.singleThreaded(), loom.allocators.generic());
        defer loom.allocators.generic().free(exepath);

        const path = try std.fmt.allocPrint(loom.allocators.generic(), "{s}{s}{s}", .{ exepath, std.fs.path.sep_str, ".loom.winstate" });
        defer loom.allocators.generic().free(path);

        var file = try std.Io.Dir.cwd().createFile(loom.io.singleThreaded(), path, .{});
        defer file.close(loom.io.singleThreaded());

        const win_size = size.get();
        const win_size_x: i16 = @intCast(std.math.clamp(@as(i32, @intFromFloat(@round(win_size.x))), 1, std.math.maxInt(i16)));
        const win_size_y: i16 = @intCast(std.math.clamp(@as(i32, @intFromFloat(@round(win_size.y))), 1, std.math.maxInt(i16)));

        const win_pos = rl.getWindowPosition();
        const win_pos_x: i16 = @intCast(std.math.clamp(@as(i32, @intFromFloat(@round(win_pos.x))), std.math.minInt(i16), std.math.maxInt(i16)));
        const win_pos_y: i16 = @intCast(std.math.clamp(@as(i32, @intFromFloat(@round(win_pos.y))), std.math.minInt(i16), std.math.maxInt(i16)));

        var config_flags_bits: u8 = 0b0000_0000;
        if (fullscreen.get()) config_flags_bits |= 0b0000_0001;
        if (borderless.get()) config_flags_bits |= 0b0000_0010;

        var bytes: [9]u8 = undefined;
        std.mem.writeInt(i16, bytes[0..2], win_pos_x, .big);
        std.mem.writeInt(i16, bytes[2..4], win_pos_y, .big);
        std.mem.writeInt(i16, bytes[4..6], win_size_x, .big);
        std.mem.writeInt(i16, bytes[6..8], win_size_y, .big);
        bytes[8] = config_flags_bits;

        try file.writePositionalAll(loom.io.singleThreaded(), &bytes, 0);
    }

    pub fn load() !void {
        if (!use) return;

        const exepath = try std.process.executableDirPathAlloc(loom.io.singleThreaded(), loom.allocators.generic());
        defer loom.allocators.generic().free(exepath);

        const path = try std.fmt.allocPrint(loom.allocators.generic(), "{s}{s}{s}", .{ exepath, std.fs.path.sep_str, ".loom.winstate" });
        defer loom.allocators.generic().free(path);

        var file = std.Io.Dir.cwd().openFile(
            loom.io.singleThreaded(),
            path,
            .{ .mode = .read_only },
        ) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer file.close(loom.io.singleThreaded());

        var bytes: [9]u8 = undefined;
        const bytes_read = try file.readPositionalAll(loom.io.singleThreaded(), &bytes, 0);
        if (bytes_read < 9) return;

        const pos_x = std.mem.readInt(i16, bytes[0..2], .big);
        const pos_y = std.mem.readInt(i16, bytes[2..4], .big);
        const size_x = std.mem.readInt(i16, bytes[4..6], .big);
        const size_y = std.mem.readInt(i16, bytes[6..8], .big);
        const config_flag_bits = bytes[8];

        if (size_x <= 0 or size_y <= 0) return;

        if (is_alive) {
            rl.setWindowPosition(@as(i32, pos_x), @as(i32, pos_y));
            size.set(loom.Vec2(size_x, size_y));

            if (config_flag_bits & 0b0000_0001 > 0) fullscreen.enable();
            if (config_flag_bits & 0b0000_0010 > 0) borderless.enable();
        } else {
            _temp_pos = loom.Vec2(pos_x, pos_y);
            size.set(loom.Vec2(size_x, size_y));

            if (config_flag_bits & 0b0000_0001 > 0) _temp_fullscreen = true;
            if (config_flag_bits & 0b0000_0010 > 0) _temp_borderless = true;
        }
    }
};
