const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const lm = @import("root.zig");
const builtin = @import("builtin");
const rl = @import("raylib");

pub const TextureRenderer = struct {
    texture: rl.Texture,
    transform: lm.Transform,
    tint: rl.Color = .white,
    fill_color: ?rl.Color = null,

    entity: ?*lm.Entity = null,

    pub fn draw(self: TextureRenderer) void {
        if (self.fill_color) |color| rl.drawRectanglePro(
            lm.Rect(
                self.transform.position.x,
                self.transform.position.y,
                @max(1, self.transform.scale.x),
                @max(1, self.transform.scale.y),
            ),
            lm.Vec2(self.transform.scale.x / 2, self.transform.scale.y / 2),
            self.transform.rotation,
            color,
        );

        rl.drawTexturePro(
            self.texture,
            lm.Rect(
                0,
                0,
                @max(1, self.transform.scale.x),
                @max(1, self.transform.scale.y),
            ),
            lm.Rect(
                self.transform.position.x,
                self.transform.position.y,
                @max(1, self.transform.scale.x),
                @max(1, self.transform.scale.y),
            ),
            lm.Vec2(self.transform.scale.x / 2, self.transform.scale.y / 2),
            self.transform.rotation,
            self.tint,
        );
    }
};

pub const RectangleRenderer = struct {
    rectangle: lm.Rectangle,
    color: lm.Color,

    pub fn draw(self: RectangleRenderer) void {
        rl.drawRectangle(
            lm.toi32(self.rectangle.x),
            lm.toi32(self.rectangle.y),
            @max(1, lm.toi32(self.rectangle.width)),
            @max(1, lm.toi32(self.rectangle.height)),
            self.color,
        );
    }
};

pub const LineRenderer = struct {
    start_position: lm.Vector2,
    end_position: lm.Vector2,
    color: lm.Color,

    pub fn draw(self: LineRenderer) void {
        rl.drawLine(
            @max(0, lm.toi32(self.start_position.x)),
            @max(0, lm.toi32(self.start_position.y)),
            @max(0, lm.toi32(self.end_position.x)),
            @max(0, lm.toi32(self.end_position.y)),
            self.color,
        );
    }
};

pub const CircleRenderer = struct {
    center_position: lm.Vector2,
    radius: f32,
    color: lm.Color,

    pub fn draw(self: CircleRenderer) void {
        rl.drawCircle(
            @max(0, lm.toi32(self.center_position.x)),
            @max(0, lm.toi32(self.center_position.y)),
            self.radius,
            self.color,
        );
    }
};

pub const RingRenderer = struct {
    center: lm.Vector2,
    inner_radius: f32,
    outer_radius: f32,
    start_angle: f32,
    end_angle: f32,
    segments: i32,
    color: lm.Color,

    pub fn draw(self: RingRenderer) void {
        rl.drawRing(
            self.center,
            self.inner_radius,
            self.outer_radius,
            self.start_angle,
            self.end_angle,
            self.segments,
            self.color,
        );
    }
};

const RendererTag = enum {
    texture,
    rectangle,
    line,
    circle,
    ring,
};

const Renderer = union(RendererTag) {
    texture: TextureRenderer,
    rectangle: RectangleRenderer,
    line: LineRenderer,
    circle: CircleRenderer,
    ring: RingRenderer,
};

const OrderedRenderer = struct {
    renderer: Renderer,
    index: isize = 0,

    pub fn draw(self: OrderedRenderer) void {
        switch (self.renderer) {
            inline else => |r| {
                const T = @TypeOf(r);

                if (comptime !@hasDecl(T, "draw")) @compileError(@typeName(T) ++ " missing required draw() method");
                @call(.auto, @field(T, "draw"), .{r});
            },
        }
    }
};

const BufferType = std.ArrayList(OrderedRenderer);
var buffer: ?BufferType = null;
var allocator: std.mem.Allocator = undefined;

fn sort(_: void, lsh: OrderedRenderer, rsh: OrderedRenderer) bool {
    if (lsh.index != rsh.index) {
        return lsh.index < rsh.index;
    }

    if (lsh.renderer == .texture and rsh.renderer == .texture) {
        const lt = lsh.renderer.texture.transform.position;
        const rt = rsh.renderer.texture.transform.position;
        if (lt.z != rt.z) return lt.z < rt.z;
        return lt.y < rt.y;
    }

    return false;
}

pub fn init() void {
    allocator = lm.allocators.generic();
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

pub fn addRenderer(renderer: OrderedRenderer) !void {
    const buf = &(buffer orelse return);
    try buf.append(allocator, renderer);
}

pub fn render() void {
    const buf = &(buffer orelse return);
    std.sort.insertion(OrderedRenderer, buf.items, {}, sort);

    for (buf.items) |item| {
        item.draw();
    }
}
