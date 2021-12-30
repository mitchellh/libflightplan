const std = @import("std");
const Builder = std.build.Builder;

// Our package
const pkgs = struct {
    const flightplan = std.build.Pkg{
        .name = "flightplan",
        .path = .{ .path = "src/flightplan.zig" },
    };
};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    // Primary zig lib
    {
        const lib = b.addStaticLibrarySource("flightplan", pkgs.flightplan.path);
        lib.setBuildMode(mode);
        lib.setTarget(target);
    }

    // All tests
    {
        const lib_tests = b.addTestSource(pkgs.flightplan.path);
        lib_tests.setBuildMode(mode);

        const test_step = b.step("test", "Run all tests");
        test_step.dependOn(&lib_tests.step);
    }
}
