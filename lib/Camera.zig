const std = @import("std");
const rl = @import("raylib");
const lm = @import("root.zig");

const Drawmode = enum {
    none,
    world,
    custom,
};

const DisplayOptionsTag = enum {
    fullscreen_rendering,
    partial_rendering,
};

const DisplayOptions = union(DisplayOptionsTag) {
    fullscreen_rendering: void,
    partial_rendering: lm.Rectangle,

    pub const fullscreen: DisplayOptions = .{ .fullscreen_rendering = {} };

    pub fn partial(rectangle: lm.Rectangle) DisplayOptions {
        return .{ .partial_rendering = rectangle };
    }
};

const DrawFunction = *const fn () anyerror!void;

pub const Options = struct {
    display: DisplayOptions,
    draw_mode: Drawmode,
    shader: ?[]const u8 = null,
    draw_fn: ?DrawFunction = null,
    clear_color: rl.Color = .white,

    z_index: f32 = 0,
    offset: lm.Vector2 = .init(0, 0),
    target: lm.Vector2 = .init(0, 0),
    rotation: f32 = 0,
    zoom: f32 = 1,
};

const Self = @This();

id: []const u8,
uuid: u128 = 0,
partial: ?lm.Rectangle = null,
shader: ?*rl.Shader = null,

draw_mode: Drawmode = .world,
draw_fn: ?DrawFunction = null,

render_texture: rl.RenderTexture,
camera: rl.Camera2D,

clear_color: rl.Color = .white,

z_index: f32 = 0,
offset: lm.Vector2 = .init(0, 0),
target: lm.Vector2 = .init(0, 0),
rotation: f32 = 0,
zoom: f32 = 1,

pub fn init(id: []const u8, options: Options) !Self {
    const winsize = lm.window.size.get();
    const partial = switch (options.display) {
        .fullscreen_rendering => null,
        .partial_rendering => |partial| partial,
    };

    return Self{
        .id = id,
        .uuid = lm.UUIDv7(),
        .partial = partial,
        .shader = if (options.shader) |path|
            lm.assets.shader.get(path, &.{})
        else
            null,
        .draw_mode = options.draw_mode,
        .draw_fn = options.draw_fn,
        .render_texture = if (partial) |p|
            try .init(lm.toi32(p.width), lm.toi32(p.height))
        else
            try .init(lm.toi32(winsize.x), lm.toi32(winsize.y)),

        .camera = rl.Camera2D{
            .offset = options.offset,
            .target = options.target,
            .rotation = options.rotation,
            .zoom = options.zoom,
        },
        .clear_color = options.clear_color,

        .z_index = options.z_index,
        .offset = options.offset,
        .target = options.target,
        .rotation = options.rotation,
        .zoom = options.zoom,
    };
}

pub fn deinit(self: *Self) void {
    self.render_texture.unload();
    if (self.shader) |self_shader| lm.assets.shader.releasePtr(self_shader);
}

pub fn begin(self: *Self) !void {
    self.camera.offset = self.offset;
    self.camera.target = self.target;
    self.camera.rotation = self.rotation;
    self.camera.zoom = self.zoom;

    const winsize = lm.window.size.get();
    if (self.partial == null)
        if (lm.tof32(self.render_texture.texture.height) != winsize.y or
            lm.tof32(self.render_texture.texture.width) != winsize.x)
        {
            self.render_texture.texture.unload();
            self.render_texture.unload();
            self.render_texture = try .init(lm.toi32(winsize.x), lm.toi32(winsize.y));
        };
    if (self.partial) |partial| {
        if (partial.height != lm.tof32(self.render_texture.texture.height) or
            partial.width != lm.tof32(self.render_texture.texture.width))
        {
            self.render_texture.texture.unload();
            self.render_texture.unload();
            self.render_texture = try .init(lm.toi32(partial.width), lm.toi32(partial.height));
        }
    }

    self.render_texture.begin();

    rl.clearBackground(self.clear_color);

    self.camera.begin();
}

pub fn end(self: *Self) void {
    self.camera.end();
    self.render_texture.end();

    if (self.shader) |shader| shader.activate();

    rl.drawTextureRec(
        self.render_texture.texture,
        lm.Rect(0, 0, self.render_texture.texture.width, -self.render_texture.texture.height),
        if (self.partial) |p|
            .init(p.x, p.y)
        else
            .init(0, 0),

        .white,
    );

    if (self.shader) |shader| shader.deactivate();
}

pub fn screenToWorldPos(self: *Self, pos: lm.Vector2) lm.Vector2 {
    const offset = self.partial orelse lm.Rect(0, 0, 0, 0);

    return rl.getScreenToWorld2D(
        pos,
        self.camera,
    ).subtract(.init(offset.x, offset.y));
}

pub fn worldToScreenPos(self: *Self, pos: lm.Vector2) lm.Vector2 {
    const offset = self.partial orelse lm.Rect(0, 0, 0, 0);

    return rl.getWorldToScreen2D(
        pos,
        self.camera,
    ).add(.init(offset.x, offset.y));
}

pub fn useShader(self: *Self, shader_path: ?[]const u8) void {
    if (self.shader) |current_shader|
        lm.assets.shader.releasePtr(current_shader);

    self.shader = if (shader_path) |sp|
        try lm.assets.shader.get(sp, .{})
    else
        null;
}
