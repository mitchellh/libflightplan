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
    const static_lib = b.addStaticLibrary("flightplan", "src/binding.zig");
    initNativeLibrary(static_lib, mode, target);
    static_lib.install();

    // All tests
    {
        const lib_tests = b.addTestSource(pkgs.flightplan.path);
        lib_tests.addIncludeDir("src/include");
        lib_tests.addIncludeDir("include");
        lib_tests.setBuildMode(mode);
        lib_tests.linkLibC();
        lib_tests.linkSystemLibrary("libxml-2.0");

        const static_binding_test = b.addExecutable("static-binding", null);
        static_binding_test.setBuildMode(mode);
        static_binding_test.linkLibC();
        static_binding_test.addIncludeDir("include");
        static_binding_test.addCSourceFile("examples/basic.c", &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" });
        static_binding_test.linkLibrary(static_lib);

        const static_binding_test_run = static_binding_test.run();

        const test_step = b.step("test", "Run all tests");
        test_step.dependOn(&lib_tests.step);
        test_step.dependOn(&static_binding_test_run.step);
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
    lib.linkSystemLibrary("libxml-2.0");
}
