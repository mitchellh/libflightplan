const std = @import("std");
const Builder = std.build.Builder;
const libxml2 = @import("vendor/zig-libxml2/libxml2.zig");

const ScdocStep = @import("src-build/ScdocStep.zig");

// Zig packages in use
const pkgs = struct {
    const flightplan = pkg("src/main.zig");
};

/// pkg can be called to get the Pkg for this library. Downstream users
/// can use this to add the package to the import paths.
pub fn pkg(path: []const u8) std.build.Pkg {
    return std.build.Pkg{
        .name = "flightplan",
        .path = .{ .path = path },
    };
}

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    // Options
    const man_pages = b.option(
        bool,
        "man-pages",
        "Set to true to build man pages. Requires scdoc. Defaults to true if scdoc is found.",
    ) orelse scdoc_found: {
        _ = b.findProgram(&[_][]const u8{"scdoc"}, &[_][]const u8{}) catch |err| switch (err) {
            error.FileNotFound => break :scdoc_found false,
            else => return err,
        };
        break :scdoc_found true;
    };

    // Steps
    const test_step = b.step("test", "Run all tests");
    const test_unit_step = b.step("test-unit", "Run unit tests only");

    // Build libxml2 for static builds only
    const xml2 = try libxml2.create(b, target, mode, .{
        .iconv = false,
        .lzma = false,
        .zlib = false,
    });

    // Native Zig tests
    const lib_tests = b.addTestSource(pkgs.flightplan.path);
    addSharedSettings(lib_tests, mode, target);
    xml2.link(lib_tests);
    test_unit_step.dependOn(&lib_tests.step);
    test_step.dependOn(&lib_tests.step);

    // Static C lib
    {
        const static_lib = b.addStaticLibrary("flightplan", "src/binding.zig");
        addSharedSettings(static_lib, mode, target);
        xml2.addIncludeDirs(static_lib);
        static_lib.install();
        b.default_step.dependOn(&static_lib.step);

        const static_binding_test = b.addExecutable("static-binding", null);
        static_binding_test.setBuildMode(mode);
        static_binding_test.setTarget(target);
        static_binding_test.linkLibC();
        static_binding_test.addIncludeDir("include");
        static_binding_test.addCSourceFile("examples/basic.c", &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" });
        static_binding_test.linkLibrary(static_lib);
        xml2.link(static_binding_test);

        const static_binding_test_run = static_binding_test.run();

        test_step.dependOn(&static_binding_test_run.step);
    }

    // Dynamic C lib. We only build this if this is the native target so we
    // can link to libxml2 on our native system.
    if (target.isNative()) {
        const dynamic_lib_name = if (target.isWindows())
            "flightplan.dll"
        else
            "flightplan";

        const dynamic_lib = b.addSharedLibrary(dynamic_lib_name, "src/binding.zig", .unversioned);
        addSharedSettings(dynamic_lib, mode, target);
        dynamic_lib.linkSystemLibrary("libxml-2.0");
        dynamic_lib.install();
        b.default_step.dependOn(&dynamic_lib.step);

        const dynamic_binding_test = b.addExecutable("dynamic-binding", null);
        dynamic_binding_test.setBuildMode(mode);
        dynamic_binding_test.setTarget(target);
        dynamic_binding_test.linkLibC();
        dynamic_binding_test.addIncludeDir("include");
        dynamic_binding_test.addCSourceFile("examples/basic.c", &[_][]const u8{ "-Wall", "-Wextra", "-pedantic", "-std=c99" });
        dynamic_binding_test.linkLibrary(dynamic_lib);

        const dynamic_binding_test_run = dynamic_binding_test.run();
        test_step.dependOn(&dynamic_binding_test_run.step);
    }

    // Headers
    const install_header = b.addInstallFileWithDir(
        .{ .path = "include/flightplan.h" },
        .header,
        "flightplan.h",
    );
    b.getInstallStep().dependOn(&install_header.step);

    // pkg-config
    {
        const file = try std.fs.path.join(
            b.allocator,
            &[_][]const u8{ b.cache_root, "libflightplan.pc" },
        );
        const pkgconfig_file = try std.fs.cwd().createFile(file, .{});

        const writer = pkgconfig_file.writer();
        try writer.print(
            \\prefix={s}
            \\includedir=${{prefix}}/include
            \\libdir=${{prefix}}/lib
            \\
            \\Name: libflightplan
            \\URL: https://github.com/mitchellh/libflightplan
            \\Description: Library for reading and writing aviation flight plans.
            \\Version: 0.1.0
            \\Cflags: -I${{includedir}}
            \\Libs: -L${{libdir}} -lflightplan
        , .{b.install_prefix});
        defer pkgconfig_file.close();

        b.installFile(file, "share/pkgconfig/libflightplan.pc");
    }

    if (man_pages) {
        const scdoc_step = ScdocStep.create(b);
        try scdoc_step.install();
    }
}

/// The shared settings that we need to apply when building a library or
/// executable using libflightplan.
fn addSharedSettings(
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
