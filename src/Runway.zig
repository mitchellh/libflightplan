const Self = @This();

const std = @import("std");
const testing = std.testing;

// Number is the runway number such as "25"
number: u16,

// Position is the relative position of the runway, if any, such as
// L, R, C. This is a byte so that it can be any ASCII character, but
position: ?Position = null,

/// Position is the potential position of runways with matching numbers.
pub const Position = enum {
    L,
    R,
    C,
};

/// Runway string such as "15L", "15", etc. The buffer must be at least
/// 3 characters large. If the buffer isn't large enough you'll get an error.
pub fn toString(self: Self, buf: []u8) ![:0]u8 {
    var posString: [:0]const u8 = "";
    if (self.position) |pos| {
        posString = @tagName(pos);
    }

    return try std.fmt.bufPrintZ(buf, "{d:0>2}{s}", .{ self.number, posString });
}

test "string" {
    var buf: [6]u8 = undefined;

    {
        const rwy = Self{ .number = 25 };
        try testing.expectEqualStrings(try rwy.toString(&buf), "25");
    }

    {
        const rwy = Self{ .number = 25, .position = .L };
        try testing.expectEqualStrings(try rwy.toString(&buf), "25L");
    }

    {
        const rwy = Self{ .number = 1, .position = .C };
        try testing.expectEqualStrings(try rwy.toString(&buf), "01C");
    }

    // Stupid but should work
    {
        const rwy = Self{ .number = 679 };
        try testing.expectEqualStrings(try rwy.toString(&buf), "679");
    }
}
