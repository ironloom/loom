const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const loom_mod = b.createModule(.{
        .root_source_file = b.path("lib/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .linux_display_backend = rlz.LinuxDisplayBackend.X11,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const zclay_dep = b.dependency("zclay", .{ .target = target, .optimize = optimize });
    const zclay = zclay_dep.module("zclay");

    const uuid_dep = b.dependency("uuid", .{ .target = target, .optimize = optimize });
    const uuid = uuid_dep.module("uuid");

    loom_mod.addImport("raylib", raylib);
    loom_mod.addImport("raygui", raygui);
    loom_mod.addImport("zclay", zclay);
    loom_mod.linkLibrary(raylib_artifact);

    loom_mod.addImport("uuid", uuid);

    try b.modules.put("loom", loom_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "loom",
        .root_module = loom_mod,
    });
    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{ .root_module = loom_mod });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const examples: []const []const u8 = &.{
        "spawning-removing",
    };

    inline for (examples) |example| {
        const exe_mod = b.createModule(.{
            .root_source_file = b.path("examples/" ++ example ++ "/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe_mod.addImport("loom", loom_mod);

        const exe = b.addExecutable(.{
            .name = example,
            .root_module = exe_mod,
        });

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step("example=" ++ example, "");
        run_step.dependOn(&run_cmd.step);
    }
}
