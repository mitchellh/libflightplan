const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("xml.zig").c;

/// Possible errors that can be returned by many of the functions
/// in this library. See the function doc comments for details on
/// exactly which of these can be returnd.
pub const Set = error{
    ReadFailed,
    NodeExpected,
    InvalidElement,
};

/// last error that occurred, this MIGHT be set if an error code is returned.
/// This is thread local so using this library in a threaded environment will
/// store errors separately.
threadlocal var _lastError: ?Self = null;

/// Error code for this error
code: Set,

/// Additional details for this error. Whether this is set depends on what
/// triggered the error. The type of this is dependent on the context in which
/// the error was triggered.
detail: ?Detail = null,

/// Extra details for an error. What is set is dependent on what raised the error.
pub const Detail = union(enum) {
    /// message is a basic string message.
    message: ManagedString,

    /// xml-specific error message (typically a parse error)
    xml: XMLDetail,

    /// Gets a human-friendly message regardless of type.
    pub fn message(self: *Detail) [:0]const u8 {
        switch (self.*) {
            .message => |*v| return v.message,
            .xml => |*v| return v.message(),
        }
    }

    pub fn deinit(self: Detail) void {
        switch (self) {
            .message => |v| v.deinit(),
            .xml => |v| v.deinit(),
        }
    }

    /// XMLDetail when an XML-related error occurs for formats that use XML.
    pub const XMLDetail = struct {
        ctx: c.xmlParserCtxtPtr,

        /// Return the raw xmlError structure.
        pub fn err(self: *XMLDetail) ?*c.xmlError {
            return c.xmlCtxtGetLastError(self.ctx);
        }

        pub fn message(self: *XMLDetail) [:0]const u8 {
            const v = self.err() orelse return "no error";
            return std.mem.span(v.message);
        }

        pub fn deinit(self: XMLDetail) void {
            c.xmlFreeParserCtxt(self.ctx);
        }
    };

    pub const ManagedString = struct {
        alloc: Allocator,
        message: [:0]const u8,

        pub fn init(alloc: Allocator, comptime fmt: []const u8, args: anytype) !ManagedString {
            const msg = try std.fmt.allocPrintZ(alloc, fmt, args);
            return ManagedString{ .alloc = alloc, .message = msg };
        }

        pub fn deinit(self: ManagedString) void {
            self.alloc.free(self.message);
        }
    };
};

/// Helper to easily initialize an error with a message.
pub fn initMessage(alloc: Allocator, code: Set, comptime fmt: []const u8, args: anytype) !Self {
    const detail = Detail{
        .message = try Detail.ManagedString.init(alloc, fmt, args),
    };
    return Self{
        .code = code,
        .detail = detail,
    };
}

/// Returns a human-friendly message about the error.
pub fn message(self: *Self) [:0]const u8 {
    if (self.detail) |*detail| {
        return detail.message();
    }

    return "no error message";
}

/// Release resources associated with an error.
pub fn deinit(self: Self) void {
    if (self.detail) |detail| {
        detail.deinit();
    }
}

/// Return the last error (if any).
pub inline fn lastError() ?Self {
    return _lastError;
}

// Set a new last error.
pub fn setLastError(err: ?Self) void {
    // Unset previous error if there is one.
    if (_lastError) |last| {
        last.deinit();
    }

    _lastError = err;
}

test "set last error" {
    // Setting it while null does nothing
    setLastError(null);
    setLastError(null);

    // Can set and retrieve
    setLastError(Self{ .code = Set.ReadFailed });
    const err = lastError().?;
    try std.testing.expectEqual(err.code, Set.ReadFailed);

    // Can set to null
    setLastError(null);
    try std.testing.expect(lastError() == null);
}
