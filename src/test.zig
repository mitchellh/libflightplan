const std = @import("std");

/// Get the path to a test fixture file. This should only be used in tests
/// since it depends on a predictable source path.
pub fn testFile(comptime path: []const u8) []const u8 {
    comptime {
        const sepSlice = &[_]u8{std.fs.path.sep};

        // Build our path which has our relative test directory.
        var path2 = "/../test/" ++ path;

        // The path is expected to always use / so we replace it if its
        // a different value. If sep is / we technically don't have to do this
        // but we always do just so we can ensure this code path works
        var buf: [path2.len]u8 = undefined;
        _ = std.mem.replace(
            u8,
            path2,
            &[_]u8{'/'},
            sepSlice,
            buf[0..],
        );
        const finalPath = buf[0..];

        // Get the directory of this source file.
        const srcDir = std.fs.path.dirname(@src().file) orelse unreachable;

        // Add our path
        return srcDir ++ finalPath;
    }
}
