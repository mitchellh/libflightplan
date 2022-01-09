const std = @import("std");
const Builder = std.build.Builder;

// Our package
const pkgs = struct {
    const flightplan = std.build.Pkg{
        .name = "flightplan",
        .path = .{ .path = "src/main.zig" },
    };
};

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

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

    // Defaults when you do `zig build`
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

// ScdocStep creates man pages using scdoc(1).
const ScdocStep = struct {
    const scd_paths = [_][]const u8{
        "doc/libflightplan.3.scd",
    };

    builder: *Builder,
    step: std.build.Step,

    fn create(builder: *Builder) *ScdocStep {
        const self = builder.allocator.create(ScdocStep) catch @panic("out of memory");
        self.* = init(builder);
        return self;
    }

    fn init(builder: *Builder) ScdocStep {
        return ScdocStep{
            .builder = builder,
            .step = std.build.Step.init(.custom, "Generate man pages", builder.allocator, make),
        };
    }

    fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(ScdocStep, "step", step);
        for (scd_paths) |path| {
            const command = try std.fmt.allocPrint(
                self.builder.allocator,
                "scdoc < {s} > {s}",
                .{ path, path[0..(path.len - 4)] },
            );
            _ = try self.builder.exec(&[_][]const u8{ "sh", "-c", command });
        }
    }

    fn install(self: *ScdocStep) !void {
        self.builder.getInstallStep().dependOn(&self.step);

        for (scd_paths) |path| {
            const path_no_ext = path[0..(path.len - 4)];
            const basename_no_ext = std.fs.path.basename(path_no_ext);
            const section = path_no_ext[(path_no_ext.len - 1)..];

            const output = try std.fmt.allocPrint(
                self.builder.allocator,
                "share/man/man{s}/{s}",
                .{ section, basename_no_ext },
            );

            self.builder.installFile(path_no_ext, output);
        }
    }
};
