const Allocator = @import("std").mem.Allocator;

/// # Pen
/// Pen is the drawing abstraction layer from the backend.
/// This is useful, since we can swap backends by having
/// different implementations for the Pen interface.
pub fn Pen(
    comptime Font: type,
    comptime Vector2: type,
    comptime Rectangle: type,
    comptime Color: type,
    comptime Texture: type,
    comptime TextureFilter: type,
    comptime RenderTexture: type,
    comptime Camera2D: type,
    comptime Shader: type,
) type {
    return struct {
        const Self = @This();

        comptime Font: type = Font,
        comptime Vector2: type = Vector2,
        comptime Rectangle: type = Rectangle,
        comptime Color: type = Color,
        comptime Texture: type = Texture,
        comptime TextureFilter: type = TextureFilter,
        comptime RenderTexture: type = RenderTexture,
        comptime Camera2D: type = Camera2D,
        comptime Shader: type = Shader,

        allocator: Allocator,

        // Text Functions

        /// Load font from file into GPU memory (VRAM)
        loadFont: fn (
            self: Self,
            data: []const u8,
            filetype: []const u8,
            chars: ?[]const i32,
        ) anyerror!Font,
        unloadFont: fn (self: Self, font: Font) void,
        /// Set vertical line spacing when drawing with line-breaks
        setTextLineSpacing: fn (self: Self, spacing: f32) void,
        /// Draw text using font and additional parameters
        drawText: fn (
            self: Self,
            font: Font,
            text: []const u8,
            position: Vector2,
            origin: Vector2,
            rotation: f32,
            fontSize: f32,
            spacing: f32,
            tint: Color,
        ) void,
        getGlyphIndex: fn (self: Self, font: Font, codepoint: usize) void,
        /// Get the default Font
        getDefaultFont: fn (self: Self) Font,
        isValidFont: fn (self: Self, font: Font) bool,

        // Textures

        loadTexture: fn (
            self: Self,
            data: []const u8,
            filetype: []const u8,
            size: Vector2,
        ) anyerror!Texture,
        /// Unload texture from GPU memory (VRAM)
        unloadTexture: fn (self: Self, texture: Texture) void,
        /// Draw a Texture2D with extended parameters
        drawTexture: fn (
            self: Self,
            texture: Texture,
            source: Rectangle,
            dest: Rectangle,
            origin: Vector2,
            rotation: f32,
            tint: Color,
        ) void,
        /// Set texture scaling filter mode
        setTextureFilter: fn (self: Self, texture: Texture, filter: TextureFilter) void,

        // RenderTextures
        loadRenderTexture: fn (self: Self, scale: Vector2) anyerror!RenderTexture,
        unloadRenderTexture: fn (self: Self, texture: RenderTexture) void,
        beginTextureMode: fn (self: Self, texture: RenderTexture) void,
        endTextureMode: fn (self: Self) void,

        // Scissors

        /// Begin scissor mode (define screen area for following drawing)
        beginScissorMode: fn (self: Self, position: Vector2, scale: Vector2) void,
        /// End scissor mode
        endScissorMode: fn (
            self: Self,
        ) void,

        // Shapes

        /// Draw rectangle with rounded edges
        drawRectangleRounded: fn (
            self: Self,
            rectangle: Rectangle,
            border_radius: f32,
            segments: usize,
            color: Color,
        ) void,
        /// Draw a color-filled rectangle
        drawRectangle: fn (
            self: Self,
            rectangle: Rectangle,
            color: Color,
        ) void,
        /// Draw ring
        drawRing: fn (
            self: Self,
            centre: Vector2,
            innerRadius: f32,
            outerRadius: f32,
            startAngle: f32,
            endAngle: f32,
            segments: usize,
            color: Color,
        ) void,

        // Cameras

        /// Begin 2D mode with camera
        beginMode2D: fn (self: Self, camera: Camera2D) void,
        /// Ends 2D mode with camera
        endMode2D: fn (self: Self) void,
        /// Get the screen space position for a 2d camera world space position
        getWorldToScreen2D: fn (self: Self, camera: Camera2D, position: Vector2) Vector2,
        /// Get the world space position for a 2d camera screen space position
        getScreenToWorld2D: fn (self: Self, camera: Camera2D, position: Vector2) Vector2,

        // Shaders

        loadShader: fn (self: Self, vertex_shader: []const u8, fragment_shader: []const u8) anyerror!Shader,
        /// Unload shader from GPU memory (VRAM)
        unloadShader: fn (self: Self, shader: Shader) void,

        /// Begin custom shader drawing
        beginShaderMode: fn (self: Self, shader: Shader) void,
        /// End custom shader drawing (use default shader)
        endShaderMode: fn (self: Self) void,
    };
}
