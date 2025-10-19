const std = @import("std");
const loom = @import("../root.zig");
const rl = @import("raylib");
const assets = loom.assets;

const Transform = @import("Transform.zig");

pub const DisplayCache = struct {
    const This = @This();

    transform: Transform,
    img_path: []const u8,
    texture: ?*rl.Texture = null,

    pub fn free(self: *This) void {
        if (self.texture == null) return;

        self.texture = null;
        assets.texture.release(
            self.img_path,
            &.{ loom.toi32(self.transform.scale.x), loom.toi32(self.transform.scale.y) },
        );
    }
};

const Self = @This();

img_path: []const u8,
tile_size: ?loom.Vector2 = null,
tint: rl.Color = rl.Color.white,
fill_color: ?rl.Color = null,

transform: ?*Transform = null,
display_cache: ?*DisplayCache = null,
is_child: bool = false,
parent: ?*Transform = null,

pub fn sprite(path: []const u8) Self {
    return Self{
        .img_path = path,
    };
}

pub fn tile(path: []const u8, tile_size: loom.Vector2) Self {
    return Self{
        .img_path = path,
        .tile_size = tile_size,
    };
}

pub fn init(config: struct {
    img_path: []const u8 = "[INVALID]",
    tint: rl.Color = rl.Color.white,

    tile_size: ?loom.Vector2 = null,
    fill_color: ?rl.Color = null,
}) Self {
    return Self{
        .img_path = config.img_path,
        .tint = config.tint,
        .tile_size = config.tile_size,
        .fill_color = config.fill_color,
    };
}

pub fn Awake(self: *Self, entity: *loom.Entity) !void {
    try entity.addComponent(DisplayCache{
        .img_path = self.img_path,
        .transform = Transform{
            .scale = .init(-1, -1),
        },
        .texture = assets.texture.get(
            self.img_path,
            &.{ 1, 1 },
        ),
    });
    self.display_cache = try entity.getComponentUnsafe(DisplayCache).unwrap();
}

pub fn Start(self: *Self, entity: *loom.Entity) !void {
    if (entity.getComponent(Transform)) |transform| {
        self.transform = transform;
    }
}

pub fn Update(self: *Self, entity: *loom.Entity) !void {
    const display_cache: *DisplayCache = try loom.ensureComponent(self.display_cache);
    const transform: *Transform = try loom.ensureComponent(self.transform);

    if (transform.scale.x == 0 or transform.scale.y == 0) return;

    const tile_size = self.tile_size orelse transform.scale;

    const has_to_be_updated =
        transform.scale.equals(display_cache.transform.scale) == 0 or
        !std.mem.eql(u8, self.img_path, display_cache.img_path) or
        display_cache.texture == null;

    if (has_to_be_updated) {
        display_cache.free();

        display_cache.* = DisplayCache{
            .img_path = self.img_path,
            .transform = transform.*,
            .texture = assets.texture.get(
                self.img_path,
                &.{ loom.toi32(tile_size.x), loom.toi32(tile_size.y) },
            ),
        };
    }

    const texture = display_cache.texture orelse return;
    try loom.display.add(.{
        .texture = texture.*,
        .transform = Transform{
            .position = transform.*.position.add(
                if (self.parent) |parent|
                    parent.position
                else
                    loom.vec3(),
            ),
            .rotation = transform.*.rotation,
            .scale = transform.*.scale,
        },
        .display = .{
            .img_path = self.img_path,
            .tint = self.tint,
            .fill_color = self.fill_color,
        },
        .entity = entity,
    });
}

pub fn End(self: *Self) !void {
    const display_cache = self.display_cache orelse return;
    display_cache.free();
}
