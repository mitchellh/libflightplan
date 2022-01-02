const Self = @This();

const std = @import("std");
const mem = std.mem;
const hash_map = std.hash_map;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const testutil = @import("test.zig");
const xml = @import("xml.zig");
const c = xml.c;

alloc: Allocator,
created: []const u8,
waypoints: hash_map.StringHashMap(Waypoint),

pub const Error = error{
    ReadFailed,
    NodeExpected,
    InvalidElement,
};

pub const Waypoint = struct {
    identifier: []const u8,
    type: Type,
    lat: []const u8,
    lon: []const u8,

    const Type = enum {
        user_waypoint,
        airport,
        ndb,
        vor,
        int,
        int_vrp,
    };
};

pub fn parseFromFile(alloc: Allocator, path: []const u8) !Self {
    // Read the file
    // TODO: errors
    const doc = c.xmlReadFile(path.ptr, null, 0);
    if (doc == null) {
        return Error.ReadFailed;
    }
    defer c.xmlFreeDoc(doc);

    // Get the root elem
    const root = c.xmlDocGetRootElement(doc);
    return parseFromXMLNode(alloc, root);
}

fn parseFromXMLNode(alloc: Allocator, node: *c.xmlNode) !Self {
    // Should be an opening node
    if (node.type != c.XML_ELEMENT_NODE) {
        return Error.NodeExpected;
    }

    // Should be a "flight-plan" node.
    if (c.xmlStrcmp(node.name, "flight-plan") != 0) {
        return Error.InvalidElement;
    }

    var result = Self{
        .alloc = alloc,
        .created = undefined,
        .waypoints = undefined,
    };

    // Go through each child, and parse depending on type
    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "created") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            result.created = try Allocator.dupe(alloc, u8, mem.sliceTo(copy, 0));
            continue;
        }
    }

    return result;
}

pub fn deinit(self: *Self) void {
    self.alloc.free(self.created);
    self.* = undefined;
}

test {
    const testPath = testutil.testFile("basic.fpl");
    var plan = try parseFromFile(testing.allocator, testPath);
    defer plan.deinit();

    try testing.expectEqualStrings(plan.created, "20211230T22:07:20Z");
}
