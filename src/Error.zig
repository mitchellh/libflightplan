const Self = @This();

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
pub threadlocal var lastError: ?Self = null;

/// Error code for this error
code: Set,

/// Additional details for this error. Whether this is set depends on what
/// triggered the error. The type of this is dependent on the context in which
/// the error was triggered.
detail: ?Detail = null,

/// Extra details for an error. What is set is dependent on what raised the error.
pub const Detail = union(enum) {
    xml: XMLDetail,

    pub fn deinit(self: Detail) void {
        switch (self) {
            .xml => |v| v.deinit(),
        }
    }
};

/// XMLDetail when an XML-related error occurs for formats that use XML.
pub const XMLDetail = struct {
    ctx: c.xmlParserCtxtPtr,

    /// Return the raw xmlError structure.
    pub fn err(self: *XMLDetail) ?*c.xmlError {
        return c.xmlCtxtGetLastError(self.ctx);
    }

    pub fn deinit(self: XMLDetail) void {
        c.xmlFreeParserCtxt(self.ctx);
    }
};

/// Release resources associated with an error.
pub fn deinit(self: Self) void {
    if (self.detail) |detail| {
        detail.deinit();
    }
}

// Set a new last error.
pub fn setLastError(err: ?Self) void {
    // Unset previous error if there is one.
    if (lastError) |last| {
        last.deinit();
    }

    lastError = err;
}
