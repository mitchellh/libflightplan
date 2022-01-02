const c = @cImport({
    @cInclude("bridge.h");
    @cInclude("libxml/xmlreader.h");
});

const std = @import("std");
const testing = std.testing;
const testutil = @import("test.zig");

pub const FlightPlan = @import("FlightPlan.zig");

fn printElementNames(node: ?*c.xmlNode) void {
    var current: ?*c.xmlNode = node;

    while (current) |n| : (current = n.next) {
        if (n.type == c.XML_ELEMENT_NODE) {
            std.debug.print("name: {s}\n", .{n.name});
        }

        printElementNames(n.children);
    }
}

test {
    _ = FlightPlan;
}
