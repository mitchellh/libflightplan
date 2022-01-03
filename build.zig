const std = @import("std");
const Builder = std.build.Builder;

// Our package
const pkgs = struct {
    const flightplan = std.build.Pkg{
        .name = "flightplan",
        .path = .{ .path = "src/main.zig" },
    };
};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    // Primary zig lib
    {
        const lib = b.addStaticLibrary("flightplan", "src/binding.zig");
        initNativeLibrary(lib, mode, target);
        lib.install();
    }

    // All tests
    {
        const lib_tests = b.addTestSource(pkgs.flightplan.path);
        lib_tests.addIncludeDir("src/include");
        lib_tests.addIncludeDir("include");
        lib_tests.setBuildMode(mode);
        lib_tests.linkLibC();
        lib_tests.linkSystemLibrary("libxml-2.0");

        const test_step = b.step("test", "Run all tests");
        test_step.dependOn(&lib_tests.step);
    }
}

fn initNativeLibrary(
    lib: *std.build.LibExeObjStep,
    mode: std.builtin.Mode,
    target: std.zig.CrossTarget,
) void {
    lib.setBuildMode(mode);
    lib.setTarget(target);
    lib.addPackage(pkgs.flightplan);
    lib.addIncludeDir("src/include");
    lib.addIncludeDir("include");
    lib.linkLibC();
}
