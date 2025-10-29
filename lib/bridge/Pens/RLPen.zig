const Allocator = @import("std").mem.Allocator;

const lm = @import("../../root.zig");

const rl = @import("raylib");
const Pen = @import("../Pen.zig").Pen;

pub const RLPen = struct {
    const Font = rl.Font;
    const Vector2 = rl.Vector2;
    const Rectangle = rl.Rectangle;
    const Color = rl.Color;
    const Texture = rl.Texture;
    const TextureFilter = rl.TextureFilter;
    const RenderTexture = rl.RenderTexture;
    const Camera2D = rl.Camera2D;
    const Shader = rl.Shader;

    const PenType = Pen(
        Font,
        Vector2,
        Rectangle,
        Color,
        Texture,
        TextureFilter,
        RenderTexture,
        Camera2D,
        Shader,
    );

    // Text helpers (existing)
    fn loadFont(
        self: PenType,
        data: []const u8,
        filetype: []const u8,
        chars: ?[]const i32,
    ) !Font {
        const str: [:0]const u8 = try self.allocator.dupeZ(u8, filetype);
        defer self.allocator.free(str);

        var font_chars_base = [_]i32{
            48,  49,  50,  51,  52,  53,  54,  55,  56,  57,
            65,  66,  67,  68,  69,  70,  71,  72,  73,  74,
            75,  76,  77,  78,  79,  80,  81,  82,  83,  84,
            85,  86,  87,  88,  89,  90,  97,  98,  99,  100,
            101, 102, 103, 104, 105, 106, 107, 108, 109, 110,
            111, 112, 113, 114, 115, 116, 117, 118, 119, 120,
            121, 122, 33,  34,  35,  36,  37,  38,  39,  40,
            41,  42,  43,  44,  45,  46,  47,  58,  59,  60,
            61,  62,  63,  64,  91,  92,  93,  94,  95,  96,
            123, 124, 125, 126,
        };

        const font_chars: []const i32 = if (chars.len == 0) &font_chars_base else chars;

        const fnt = try rl.loadFontFromMemory(
            str,
            data,
            lm.toi32(font_chars.len),
            font_chars,
        );
        return fnt;
    }

    fn unloadFont(_: PenType, font: Font) void {
        rl.unloadFont(font);
    }

    fn setTextLineSpacing(_: PenType, spacing: f32) void {
        rl.setTextLineSpacing(lm.toi32(spacing));
    }

    fn drawText(
        self: PenType,
        font: Font,
        text: []const u8,
        position: Vector2,
        origin: Vector2,
        rotation: f32,
        fontSize: f32,
        spacing: f32,
        tint: Color,
    ) void {
        const c_string: [:0]const u8 = self.allocator.dupeZ(u8, text) catch text;
        // prefer to free if we duplicated, but dupeZ may fall back; guard
        defer if (c_string.ptr != text.ptr) self.allocator.free(c_string);

        rl.drawTextPro(
            font,
            c_string,
            position,
            origin,
            rotation,
            fontSize,
            spacing,
            tint,
        );
    }

    // Minimal glyph / font helpers
    fn getGlyphIndex(_: PenType, font: Font, codepoint: usize) void {
        _ = rl.getGlyphIndex(font, @as(i32, codepoint));
    }

    fn getDefaultFont(_: PenType) Font {
        return rl.getFontDefault() catch rl.Font{};
    }

    fn isValidFont(_: PenType, font: Font) bool {
        return rl.isFontValid(font);
    }

    // Textures
    fn loadTexture(
        self: PenType,
        data: []const u8,
        filetype: []const u8,
        size: Vector2,
    ) anyerror!Texture {
        const str: [:0]const u8 = try self.allocator.dupeZ(u8, filetype);
        defer self.allocator.free(str);

        const img = try rl.loadImageFromMemory(str, data);
        defer rl.unloadImage(img);

        rl.imageResizeNN(&img, lm.toi32(size.x), lm.toi32(size.y));

        const tex = try rl.loadTextureFromImage(img);
        return tex;
    }

    fn unloadTexture(_: PenType, texture: Texture) void {
        rl.unloadTexture(texture);
    }

    fn drawTexture(
        _: PenType,
        texture: Texture,
        source: Rectangle,
        dest: Rectangle,
        origin: Vector2,
        rotation: f32,
        tint: Color,
    ) void {
        // use origin (0,0); dest rectangle carries size — scale is ignored because dest already encoded
        rl.drawTexturePro(
            texture,
            source,
            dest,
            origin,
            rotation,
            tint,
        );
    }

    fn setTextureFilter(_: PenType, texture: Texture, filter: TextureFilter) void {
        rl.setTextureFilter(texture, filter);
    }

    // Render textures
    fn loadRenderTexture(_: PenType, scale: Vector2) anyerror!RenderTexture {
        return rl.loadRenderTexture(lm.toi32(scale.x), lm.toi32(scale.y));
    }

    fn unloadRenderTexture(_: PenType, texture: RenderTexture) void {
        rl.unloadRenderTexture(texture);
    }

    fn beginTextureMode(_: PenType, texture: RenderTexture) void {
        rl.beginTextureMode(texture);
    }

    fn endTextureMode(_: PenType) void {
        // raylib endTextureMode has no param; keep signature to match Pen type
        rl.endTextureMode();
    }

    // Scissors
    fn beginScissorMode(_: PenType, position: Vector2, scale: Vector2) void {
        rl.beginScissorMode(
            lm.toi32(position.x),
            lm.toi32(position.y),
            lm.toi32(scale.x),
            lm.toi32(scale.y),
        );
    }

    fn endScissorMode(_: PenType) void {
        rl.endScissorMode();
    }

    // Shapes
    fn drawRectangleRounded(
        _: PenType,
        rectangle: Rectangle,
        border_radius: f32,
        segments: usize,
        color: Color,
    ) void {
        rl.drawRectangleRounded(rectangle, border_radius, @as(c_int, segments), color);
    }

    fn drawRectangle(_: PenType, rectangle: Rectangle, color: Color) void {
        rl.drawRectangleRec(rectangle, color);
    }

    fn drawRing(
        _: PenType,
        centre: Vector2,
        innerRadius: f32,
        outerRadius: f32,
        startAngle: f32,
        endAngle: f32,
        segments: usize,
        color: Color,
    ) void {
        rl.drawRing(
            centre,
            innerRadius,
            outerRadius,
            startAngle,
            endAngle,
            lm.toi32(segments),
            color,
        );
    }

    // Cameras
    fn beginMode2D(_: PenType, camera: Camera2D) void {
        rl.beginMode2D(camera);
    }

    fn endMode2D(_: PenType) void {
        // raylib endMode2D takes no params; keep signature for compatibility
        rl.endMode2D();
    }

    fn getWorldToScreen2D(_: PenType, camera: Camera2D, position: Vector2) Vector2 {
        // Pen's order: (self, camera, position)
        return rl.getWorldToScreen2D(position, camera);
    }

    fn getScreenToWorld2D(_: PenType, camera: Camera2D, position: Vector2) Vector2 {
        return rl.getScreenToWorld2D(position, camera);
    }

    // Shaders
    fn loadShader(_: PenType, vertex_shader: []const u8, fragment_shader: []const u8) anyerror!Shader {
        return rl.loadShaderFromMemory(vertex_shader, fragment_shader);
    }

    fn unloadShader(_: PenType, shader: Shader) void {
        rl.unloadShader(shader);
    }

    fn beginShaderMode(_: PenType, shader: Shader) void {
        rl.beginShaderMode(shader);
    }

    fn endShaderMode(_: PenType) void {
        rl.endShaderMode();
    }

    pub fn pen(allocator: Allocator) PenType {
        return PenType{
            .allocator = allocator,
            // Text
            .loadFont = loadFont,
            .unloadFont = unloadFont,
            .setTextLineSpacing = setTextLineSpacing,
            .drawText = drawText,
            .getGlyphIndex = getGlyphIndex,
            .getDefaultFont = getDefaultFont,
            .isValidFont = isValidFont,

            // Textures
            .loadTexture = loadTexture,
            .unloadTexture = unloadTexture,
            .drawTexture = drawTexture,
            .setTextureFilter = setTextureFilter,

            // RenderTextures
            .loadRenderTexture = loadRenderTexture,
            .unloadRenderTexture = unloadRenderTexture,
            .beginTextureMode = beginTextureMode,
            .endTextureMode = endTextureMode,

            // Scissors
            .beginScissorMode = beginScissorMode,
            .endScissorMode = endScissorMode,

            // Shapes
            .drawRectangleRounded = drawRectangleRounded,
            .drawRectangle = drawRectangle,
            .drawRing = drawRing,

            // Cameras
            .beginMode2D = beginMode2D,
            .endMode2D = endMode2D,
            .getWorldToScreen2D = getWorldToScreen2D,
            .getScreenToWorld2D = getScreenToWorld2D,

            // Shaders
            .loadShader = loadShader,
            .unloadShader = unloadShader,
            .beginShaderMode = beginShaderMode,
            .endShaderMode = endShaderMode,
        };
    }
}.pen;
