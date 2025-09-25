const std = @import("std");
const loom = @import("loom");
const ui = loom.ui;

const Self = @This();

arena: std.heap.ArenaAllocator = undefined,
alloc: std.mem.Allocator = std.heap.smp_allocator,

pub fn Start(self: *Self) !void {
    self.arena = .init(loom.allocators.generic());
    self.alloc = self.arena.allocator();
}

pub fn Update(self: *Self) !void {
    _ = self.arena.reset(.free_all);

    if (loom.keyboard.getKeyDown(.f)) {
        try loom.audio.playAdvanced("noise.wav", .{
            .pitch = loom.randFloat(f32, 0.5, 1),
            .pan = loom.randFloat(f32, 0.5, 1),
        });
    }

    loom.ui.new(.{
        .id = .ID("info"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = 36, .y = 36 },
        },
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = 36,
        },
    })({
        loom.ui.text("Press F to play noise.", .{
            .letter_spacing = 3,
        });

        loom.ui.text("---", .{
            .letter_spacing = 3,
        });

        loom.ui.text(try std.fmt.allocPrint(
            self.alloc,
            "playing: {any}",
            .{loom.audio.isPlaying("noise.wav")},
        ), .{
            .letter_spacing = 3,
        });

        loom.ui.text(try std.fmt.allocPrint(
            self.alloc,
            "volume: {d}",
            .{loom.audio.getVolume("noise.wav")},
        ), .{
            .letter_spacing = 3,
        });

        loom.ui.text(try std.fmt.allocPrint(
            self.alloc,
            "pitch: {d}",
            .{loom.audio.getPitch("noise.wav")},
        ), .{
            .letter_spacing = 3,
        });

        loom.ui.text(try std.fmt.allocPrint(
            self.alloc,
            "pan: {d}",
            .{loom.audio.getPan("noise.wav")},
        ), .{
            .letter_spacing = 3,
        });
    });
}

pub fn End(self: *Self) void {
    self.arena.deinit();
}
