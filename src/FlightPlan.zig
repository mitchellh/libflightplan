const Self = @This();

const std = @import("std");
const mem = std.mem;
const hash_map = std.hash_map;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Waypoint = @import("Waypoint.zig");
const testutil = @import("test.zig");
const xml = @import("xml.zig");
const c = xml.c;
const Error = @import("errors.zig").Error;

const WPHashMap = hash_map.StringHashMap(Waypoint);

alloc: Allocator,
created: []const u8,
waypoints: WPHashMap,

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

    var self = Self{
        .alloc = alloc,
        .created = undefined,
        .waypoints = WPHashMap.init(alloc),
    };

    try self.parseFlightPlan(node);
    return self;
}

fn parseFlightPlan(self: *Self, node: *c.xmlNode) !void {
    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "created") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.created = try Allocator.dupe(self.alloc, u8, mem.sliceTo(copy, 0));
            continue;
        } else if (c.xmlStrcmp(n.name, "waypoint-table") == 0) {
            try self.parseWaypointTable(n);
        }
    }
}

fn parseWaypointTable(self: *Self, node: *c.xmlNode) !void {
    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "waypoint") == 0) {
            const wp = try Waypoint.initFromXMLNode(self.alloc, n);
            try self.waypoints.put(wp.identifier, wp);
            continue;
        }

        return Error.InvalidElement;
    }
}

pub fn deinit(self: *Self) void {
    self.alloc.free(self.created);

    var it = self.waypoints.iterator();
    while (it.next()) |kv| {
        kv.value_ptr.deinit(self.alloc);
    }
    self.waypoints.deinit();

    self.* = undefined;
}

test {
    _ = Waypoint;
}

test {
    const testPath = testutil.testFile("basic.fpl");
    var plan = try parseFromFile(testing.allocator, testPath);
    defer plan.deinit();

    try testing.expectEqualStrings(plan.created, "20211230T22:07:20Z");
    try testing.expectEqual(plan.waypoints.count(), 20);

    // Test a waypoint
    {
        const wp = plan.waypoints.get("KHHR").?;
        try testing.expectEqualStrings(wp.identifier, "KHHR");
        try testing.expectEqualStrings(wp.lat, "33.92286102713828");
        try testing.expectEqualStrings(wp.lon, "-118.3350830946681");
        try testing.expectEqual(wp.type, .airport);
    }
}
