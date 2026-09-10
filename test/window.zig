const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

const loom = @import("loom");
const Color = loom.Color;

test "window clear_color API" {
    const original = loom.window.clear_color;
    defer loom.window.clear_color = original;

    // Test direct assignment
    loom.window.clear_color = .red;
    try expectEqual(Color.red, loom.window.clear_color);

    // Test clearColor namespace struct
    loom.window.clearColor.set(.blue);
    try expectEqual(Color.blue, loom.window.clearColor.get());
    try expectEqual(Color.blue, loom.window.clear_color);

    // Test setClearColor / getClearColor helper functions
    loom.window.setClearColor(.green);
    try expectEqual(Color.green, loom.window.getClearColor());
    try expectEqual(Color.green, loom.window.clear_color);
}

test "window restore_state toggle" {
    const original = loom.window.restore_state.get();
    defer loom.window.restore_state.set(original);

    // Enabled by default
    try expect(loom.window.restore_state.get() == true);

    loom.window.restore_state.disable();
    try expect(loom.window.restore_state.get() == false);

    loom.window.restore_state.enable();
    try expect(loom.window.restore_state.get() == true);

    loom.window.restore_state.set(false);
    try expect(loom.window.restore_state.get() == false);
}

test "window state binary packet encoding/decoding" {
    // Verify 9-byte packet format matches specification
    const test_cases = [_]struct {
        pos_x: i16,
        pos_y: i16,
        size_x: i16,
        size_y: i16,
        fullscreen: bool,
        borderless: bool,
    }{
        .{ .pos_x = 100, .pos_y = 200, .size_x = 1280, .size_y = 720, .fullscreen = false, .borderless = false },
        .{ .pos_x = -50, .pos_y = -100, .size_x = 1920, .size_y = 1080, .fullscreen = true, .borderless = false },
        .{ .pos_x = 0, .pos_y = 0, .size_x = 3840, .size_y = 2160, .fullscreen = false, .borderless = true },
        .{ .pos_x = -1920, .pos_y = 500, .size_x = 2560, .size_y = 1440, .fullscreen = true, .borderless = true },
    };

    for (test_cases) |tc| {
        var flags: u8 = 0;
        if (tc.fullscreen) flags |= 0b0000_0001;
        if (tc.borderless) flags |= 0b0000_0010;

        var bytes: [9]u8 = undefined;
        std.mem.writeInt(i16, bytes[0..2], tc.pos_x, .big);
        std.mem.writeInt(i16, bytes[2..4], tc.pos_y, .big);
        std.mem.writeInt(i16, bytes[4..6], tc.size_x, .big);
        std.mem.writeInt(i16, bytes[6..8], tc.size_y, .big);
        bytes[8] = flags;

        // Decode and verify
        const decoded_pos_x = std.mem.readInt(i16, bytes[0..2], .big);
        const decoded_pos_y = std.mem.readInt(i16, bytes[2..4], .big);
        const decoded_size_x = std.mem.readInt(i16, bytes[4..6], .big);
        const decoded_size_y = std.mem.readInt(i16, bytes[6..8], .big);
        const decoded_flags = bytes[8];

        try expectEqual(tc.pos_x, decoded_pos_x);
        try expectEqual(tc.pos_y, decoded_pos_y);
        try expectEqual(tc.size_x, decoded_size_x);
        try expectEqual(tc.size_y, decoded_size_y);
        try expectEqual(tc.fullscreen, (decoded_flags & 0b0000_0001) > 0);
        try expectEqual(tc.borderless, (decoded_flags & 0b0000_0010) > 0);
    }
}

test "camera clear_color default and getters/setters" {
    const opts = loom.Camera.Options{
        .display = .fullscreen,
        .draw_mode = .world,
    };
    try expectEqual(@as(?Color, null), opts.clear_color);

    const opts_with_color = loom.Camera.Options{
        .display = .fullscreen,
        .draw_mode = .world,
        .clear_color = .purple,
    };
    try expectEqual(@as(?Color, Color.purple), opts_with_color.clear_color);
}

test "window state file I/O round-trip" {
    const tmp_path = ".test_loom_winstate";
    defer std.Io.Dir.cwd().deleteFile(loom.io.singleThreaded(), tmp_path) catch {};

    // 1. Write 9 bytes
    {
        var file = try std.Io.Dir.cwd().createFile(loom.io.singleThreaded(), tmp_path, .{});
        defer file.close(loom.io.singleThreaded());

        var bytes: [9]u8 = undefined;
        std.mem.writeInt(i16, bytes[0..2], -150, .big);
        std.mem.writeInt(i16, bytes[2..4], 300, .big);
        std.mem.writeInt(i16, bytes[4..6], 1920, .big);
        std.mem.writeInt(i16, bytes[6..8], 1080, .big);
        bytes[8] = 0b0000_0011;

        try file.writePositionalAll(loom.io.singleThreaded(), &bytes, 0);
    }

    // 2. Verify file on disk is exactly 9 bytes (non-empty!)
    {
        var file = try std.Io.Dir.cwd().openFile(loom.io.singleThreaded(), tmp_path, .{ .mode = .read_only });
        defer file.close(loom.io.singleThreaded());

        var bytes: [9]u8 = undefined;
        const read_count = try file.readPositionalAll(loom.io.singleThreaded(), &bytes, 0);
        try expectEqual(9, read_count);

        try expectEqual(@as(i16, -150), std.mem.readInt(i16, bytes[0..2], .big));
        try expectEqual(@as(i16, 300), std.mem.readInt(i16, bytes[2..4], .big));
        try expectEqual(@as(i16, 1920), std.mem.readInt(i16, bytes[4..6], .big));
        try expectEqual(@as(i16, 1080), std.mem.readInt(i16, bytes[6..8], .big));
        try expectEqual(@as(u8, 0b0000_0011), bytes[8]);
    }
}
test "window pre-init size get and set" {
    const original_size = loom.window.size.get();
    defer loom.window.size.set(original_size);

    loom.window.size.set(loom.Vec2(1600, 900));
    try expectEqual(loom.Vec2(1600, 900), loom.window.size.get());

    loom.window.size.set(loom.Vec2(1024, 768));
    try expectEqual(loom.Vec2(1024, 768), loom.window.size.get());
}
