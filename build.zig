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

    // Static C lib
    const static_lib = b.addStaticLibrary("flightplan", "src/binding.zig");
    initNativeLibrary(static_lib, mode, target);
    static_lib.install();

    // Dynamic C lib
    const dynamic_lib_name = if (target.isWindows())
        "flightplan.dll"
    else
        "flightplan";

    const dynamic_lib = b.addSharedLibrary(dynamic_lib_name, "src/binding.zig", .unversioned);
    initNativeLibrary(dynamic_lib, mode, target);
    dynamic_lib.install();

    const install_header = b.addInstallFileWithDir(
        .{ .path = "include/flightplan.h" },
        .header,
        "flightplan.h",
    );
    b.getInstallStep().dependOn(&install_header.step);

    // Defaults
    b.default_step.dependOn(&static_lib.step);
    b.default_step.dependOn(&dynamic_lib.step);

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

        const dynamic_binding_test = b.addExecutable("dynamic-binding", null);
        dynamic_binding_test.setBuildMode(mode);
        dynamic_binding_test.linkLibC();
        dynamic_binding_test.addIncludeDir("include");
        dynamic_binding_test.addCSourceFile("examples/basic.c", &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" });
        dynamic_binding_test.linkLibrary(dynamic_lib);

        const static_binding_test_run = static_binding_test.run();
        const dynamic_binding_test_run = dynamic_binding_test.run();

        const test_step = b.step("test", "Run all tests");
        test_step.dependOn(&lib_tests.step);
        test_step.dependOn(&static_binding_test_run.step);
        test_step.dependOn(&dynamic_binding_test_run.step);

        const test_unit_step = b.step("test-unit", "Run unit tests only");
        test_unit_step.dependOn(&lib_tests.step);
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
