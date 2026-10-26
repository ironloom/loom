const std = @import("std");
const lm = @import("../../root.zig");
const rl = lm.deps.rl;
const files = @import("../files.zig");

pub const ShaderData = struct {
    vertex_shader: ?[:0]const u8,
    fragment_shader: ?[:0]const u8,
};

pub fn parse(
    data: []const u8,
    filetype: []const u8,
    path: []const u8,
    mod: []const i32,
) !ShaderData {
    _ = mod;

    var fragment_shader_c_data: ?[:0]const u8 = null;
    errdefer if (fragment_shader_c_data) |fscd| lm.allocators.generic().free(fscd);

    var vertex_shader_c_data: ?[:0]const u8 = null;
    errdefer if (vertex_shader_c_data) |vscd| lm.allocators.generic().free(vscd);

    if (path.len >= 2) {
        const other_shader_filename = try std.mem.concat(lm.allocators.generic(), u8, &.{
            path[0 .. path.len - 2],
            if (std.mem.eql(u8, filetype, ".fs")) "vs" else "fs",
        });
        defer lm.allocators.generic().free(other_shader_filename);

        if (std.mem.eql(u8, filetype, ".fs")) {
            const vertex_shader_data: ?[]const u8 = files.getData(other_shader_filename) catch null;
            defer if (vertex_shader_data) |vsd| lm.allocators.generic().free(vsd);

            vertex_shader_c_data = if (vertex_shader_data) |vs|
                try lm.allocators.generic().dupeSentinel(u8, vs, 0)
            else
                null;

            fragment_shader_c_data = try lm.allocators.generic().dupeSentinel(u8, data, 0);
        } else {
            const fragment_shader_data: ?[]const u8 = files.getData(other_shader_filename) catch null;
            defer if (fragment_shader_data) |fsd| lm.allocators.generic().free(fsd);

            fragment_shader_c_data = if (fragment_shader_data) |fs|
                try lm.allocators.generic().dupeSentinel(u8, fs, 0)
            else
                null;

            vertex_shader_c_data = try lm.allocators.generic().dupeSentinel(u8, data, 0);
        }
    } else {
        if (std.mem.eql(u8, filetype, ".fs")) {
            fragment_shader_c_data = try lm.allocators.generic().dupeSentinel(u8, data, 0);
        } else {
            vertex_shader_c_data = try lm.allocators.generic().dupeSentinel(u8, data, 0);
        }
    }

    return ShaderData{
        .vertex_shader = vertex_shader_c_data,
        .fragment_shader = fragment_shader_c_data,
    };
}

pub fn releaseRaw(raw: ShaderData) void {
    if (raw.vertex_shader) |vs| lm.allocators.generic().free(vs);
    if (raw.fragment_shader) |fs| lm.allocators.generic().free(fs);
}

pub fn upload(raw: ShaderData) !rl.Shader {
    return try rl.loadShaderFromMemory(raw.vertex_shader, raw.fragment_shader);
}

pub fn release(uploaded: rl.Shader) void {
    rl.unloadShader(uploaded);
}
