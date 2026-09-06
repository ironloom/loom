const std = @import("std");
const loom = @import("loom");

const UiExampleGlobal = struct {
    const Self = @This();

    pub fn Update(_: *Self, _: *loom.Scene) !void {
        loom.ui.new(.{
            .id = .ID("ui-container"),
            .layout = .{
                .direction = .top_to_bottom,
                .padding = .axes(10, 8),
                .child_gap = 16,
            },
            .background_color = loom.ui.color(30, 30, 40, 255),
            .corner_radius = .{ .top_left = 8, .top_right = 8, .bottom_left = 8, .bottom_right = 8 },
            .floating = .{
                .attach_to = .to_root,
                .attach_points = .{
                    .element = .center_center,
                    .parent = .center_center,
                },
                .offset = .{ .x = 0, .y = 0 },
            },
        })({
            loom.ui.new(.{
                .id = .ID("box-normal"),
                .background_color = loom.ui.color(60, 60, 80, 255),
                .layout = .{
                    .padding = .axes(10, 8),
                },
            })({
                loom.ui.text("Standard Letter Spacing (0)", .{
                    .font_size = 20,
                    .letter_spacing = 0,
                    .color = loom.ui.color(255, 255, 255, 255),
                });
            });

            loom.ui.new(.{
                .id = .ID("box-medium"),
                .background_color = loom.ui.color(60, 60, 80, 255),
                .layout = .{
                    .padding = .axes(10, 8),
                },
            })({
                loom.ui.text("Medium Letter Spacing (5)", .{
                    .font_size = 20,
                    .letter_spacing = 5,
                    .color = loom.ui.color(100, 220, 255, 255),
                });
            });

            loom.ui.new(.{
                .id = .ID("box-large"),
                .background_color = loom.ui.color(60, 60, 80, 255),
                .layout = .{
                    .padding = .axes(10, 8),
                },
            })({
                loom.ui.text("WIDE LETTER SPACING (12)", .{
                    .font_size = 20,
                    .letter_spacing = 12,
                    .color = loom.ui.color(255, 200, 100, 255),
                });
            });
        });
    }
};

pub fn main() !void {
    loom.project(.{
        .window = .{
            .title = "loom example: ui",
            .resizable = true,
        },
        .asset_paths = .{ .debug = "./" },
    })({
        loom.scene("default")({
            loom.useMainCamera();

            loom.globalBehaviours(.{
                UiExampleGlobal{},
            });
        });
    });
}
