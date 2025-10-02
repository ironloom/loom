const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const loom_mod = b.createModule(.{
        .root_source_file = b.path("lib/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
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

    if (b.lazyDependency("system_sdk", .{})) |system_sdk| switch (target.result.os.tag) {
        .windows => {
            if (target.result.cpu.arch.isX86() and (target.result.abi.isGnu() or target.result.abi.isMusl())) {
                loom_mod.addLibraryPath(system_sdk.path("windows/lib/x86_64-windows-gnu"));
            }
        },
        .macos => {
            loom_mod.addLibraryPath(system_sdk.path("macos12/usr/lib"));
            loom_mod.addFrameworkPath(system_sdk.path("macos12/System/Library/Frameworks"));

            loom_mod.linkFramework("Foundation", .{ .needed = true });
            loom_mod.linkFramework("CoreFoundation", .{ .needed = true });
            loom_mod.linkFramework("CoreGraphics", .{ .needed = true });
            loom_mod.linkFramework("CoreServices", .{ .needed = true });
            loom_mod.linkFramework("AppKit", .{ .needed = true });
            loom_mod.linkFramework("IOKit", .{ .needed = true });

            loom_mod.linkSystemLibrary("objc", .{});
        },
        .linux => {
            if (target.result.cpu.arch.isX86()) {
                raylib.addLibraryPath(system_sdk.path("linux/lib/x86_64-linux-gnu"));
                raylib.addSystemIncludePath(system_sdk.path("linux/include"));

                raylib.addLibraryPath(.{ .cwd_relative = "/usr/bin" });
                raylib.addLibraryPath(.{ .cwd_relative = "/usr/lib/x86_64-linux-gnu" });
                raylib.addSystemIncludePath(.{ .cwd_relative = "/usr/include/X11" });

                raylib.linkSystemLibrary("GL", .{ .needed = true });
                raylib.linkSystemLibrary("GLX", .{ .needed = true });
                raylib.linkSystemLibrary("X11", .{ .needed = true });
                raylib.linkSystemLibrary("Xcursor", .{ .needed = true });
                raylib.linkSystemLibrary("Xext", .{ .needed = true });
                raylib.linkSystemLibrary("Xi", .{ .needed = true });
                raylib.linkSystemLibrary("Xinerama", .{ .needed = true });
                raylib.linkSystemLibrary("Xrandr", .{ .needed = true });
                raylib.linkSystemLibrary("Xrender", .{ .needed = true });

                raylib_artifact.addLibraryPath(system_sdk.path("linux/lib/x86_64-linux-gnu"));
                raylib_artifact.addSystemIncludePath(system_sdk.path("linux/include"));

                raylib_artifact.addLibraryPath(.{ .cwd_relative = "/usr/bin" });
                raylib_artifact.addLibraryPath(.{ .cwd_relative = "/usr/lib/x86_64-linux-gnu" });
                raylib_artifact.addSystemIncludePath(.{ .cwd_relative = "/usr/include/X11" });

                raylib_artifact.linkSystemLibrary("GLX");
                raylib_artifact.linkSystemLibrary("X11");
                raylib_artifact.linkSystemLibrary("Xcursor");
                raylib_artifact.linkSystemLibrary("Xext");
                raylib_artifact.linkSystemLibrary("Xi");
                raylib_artifact.linkSystemLibrary("Xinerama");
                raylib_artifact.linkSystemLibrary("Xrandr");
                raylib_artifact.linkSystemLibrary("Xrender");
            } else if (target.result.cpu.arch == .aarch64) {
                loom_mod.addLibraryPath(system_sdk.path("linux/lib/aarch64-linux-gnu"));
            }
        },
        else => {},
    };

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
        "display-sorting",
        "components",
        "global-behaviours",
        "audio",
        "gamepad",
        "cameras",
        "animator",
    };

    const build_all_step = b.step("example=all", "");
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

        const run_step = b.step("run-example=" ++ example, "");
        const build_step = b.step("example=" ++ example, "");

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        const exe_cmd = b.addInstallArtifact(exe, .{});
        build_step.dependOn(b.getInstallStep());

        run_step.dependOn(&run_cmd.step);

        build_step.dependOn(&exe_cmd.step);
        build_all_step.dependOn(&exe_cmd.step);
    }
}
