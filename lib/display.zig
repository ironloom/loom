const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const loom = @import("root.zig");
const builtin = @import("builtin");
const rl = @import("raylib");

pub const Renderer = struct {
    texture: rl.Texture,
    transform: loom.Transform,
    display: struct {
        img_path: []const u8,
        tint: rl.Color,
        fill_color: ?rl.Color,
    },
    entity: ?*loom.Entity = null,
};

const BufferType = std.ArrayList(Renderer);
var buffer: ?BufferType = null;
var allocator: std.mem.Allocator = undefined;

fn sort(_: void, lsh: Renderer, rsh: Renderer) bool {
    if (lsh.transform.position.z < rsh.transform.position.z)
        return true
    else if (lsh.transform.position.z == rsh.transform.position.z)
        if (lsh.transform.position.y < rsh.transform.position.y) return true;

    return false;
}

pub fn init() void {
    allocator = loom.allocators.generic();
    buffer = .empty;
}

pub fn reset() void {
    const buf = &(buffer orelse return);
    buf.clearAndFree(allocator);
}

pub fn deinit() void {
    const buf = &(buffer orelse return);
    buf.deinit(allocator);
}

pub fn add(r: Renderer) !void {
    if (r.transform.scale.equals(loom.vec2()) == 1) return;
    const buf = &(buffer orelse return);

    try buf.append(allocator, r);
}

pub fn render() void {
    const buf = &(buffer orelse return);
    std.sort.insertion(Renderer, buf.items, {}, sort);

    for (buf.items) |item| {
        if (builtin.mode == .Debug and loom.window.use_debug_mode) Debug: {
            if (item.entity) |entity| blk: {
                const collider = entity.getComponent(loom.RectangleCollider) orelse break :blk;

                const points = collider.points orelse break :blk;

                const color: rl.Color = switch (collider.type) {
                    .static => .lime,
                    .dynamic => .pink,
                    .passtrough => .sky_blue,
                    .trigger => .orange,
                };

                rl.drawCircle(loom.toi32(points.A.x), loom.toi32(points.A.y), 5, color);
                rl.drawLineEx(points.A, points.B, 2, color);

                rl.drawCircle(loom.toi32(points.B.x), loom.toi32(points.B.y), 5, color);
                rl.drawLineEx(points.B, points.C, 2, color);

                rl.drawCircle(loom.toi32(points.C.x), loom.toi32(points.C.y), 5, color);
                rl.drawLineEx(points.C, points.D, 2, color);

                rl.drawCircle(loom.toi32(points.D.x), loom.toi32(points.D.y), 5, color);
                rl.drawLineEx(points.D, points.A, 2, color);

                rl.drawLineEx(loom.vec3ToVec2(item.transform.position), loom.vec3ToVec2(item.transform.position).add(.init(collider.R(), 0)), 2, .orange);
                rl.drawCircleLinesV(loom.vec3ToVec2(item.transform.position), collider.R(), .maroon);

                break :Debug;
            }

            rl.drawRectanglePro(
                loom.Rect(
                    item.transform.position.x - 2,
                    item.transform.position.y - 2,
                    item.transform.scale.x + 4,
                    item.transform.scale.y + 4,
                ),
                loom.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
                item.transform.rotation,
                rl.Color.lime,
            );
            rl.drawRectanglePro(
                loom.Rect(
                    item.transform.position.x,
                    item.transform.position.y,
                    item.transform.scale.x,
                    item.transform.scale.y,
                ),
                loom.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
                item.transform.rotation,
                loom.window.clear_color,
            );
        }

        if (item.display.fill_color) |color| rl.drawRectanglePro(
            loom.Rect(
                item.transform.position.x,
                item.transform.position.y,
                item.transform.scale.x,
                item.transform.scale.y,
            ),
            loom.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
            item.transform.rotation,
            color,
        );

        rl.drawTexturePro(
            item.texture,
            loom.Rect(
                0,
                0,
                item.transform.scale.x,
                item.transform.scale.y,
            ),
            loom.Rect(
                item.transform.position.x,
                item.transform.position.y,
                item.transform.scale.x,
                item.transform.scale.y,
            ),
            loom.Vec2(item.transform.scale.x / 2, item.transform.scale.y / 2),
            item.transform.rotation,
            item.display.tint,
        );
    }
}
