/// This file contains the reading/writing logic for the Garmin FPL
/// format. This format is also used by ForeFlight with slight modifications.
/// The reader/writer handle both formats.
///
/// Reference: https://www8.garmin.com/xmlschemas/FlightPlanv1.xsd
const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const Allocator = std.mem.Allocator;

const FlightPlan = @import("../FlightPlan.zig");
const Waypoint = @import("../Waypoint.zig");
const testutil = @import("../test.zig");
const xml = @import("../xml.zig");
const c = xml.c;
const Error = @import("../errors.zig").Error;
const Route = @import("../Route.zig");

/// Binding are the C bindings for this format.
pub const Binding = struct {
    const binding = @import("../binding.zig");
    const c_allocator = std.heap.c_allocator;

    export fn fpl_parse_garmin(path: [*:0]const u8) ?*binding.c.flightplan {
        var fpl = parseFromFile(c_allocator, mem.sliceTo(path, 0)) catch return null;
        return binding.cflightplan(fpl);
    }
};

pub fn parseFromFile(alloc: Allocator, path: []const u8) !FlightPlan {
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

fn parseFromXMLNode(alloc: Allocator, node: *c.xmlNode) !FlightPlan {
    // Should be an opening node
    if (node.type != c.XML_ELEMENT_NODE) {
        return Error.NodeExpected;
    }

    // Should be a "flight-plan" node.
    if (c.xmlStrcmp(node.name, "flight-plan") != 0) {
        return Error.InvalidElement;
    }

    const WPType = comptime std.meta.fieldInfo(FlightPlan, .waypoints).field_type;
    var self = FlightPlan{
        .alloc = alloc,
        .created = undefined,
        .waypoints = WPType{},
        .route = undefined,
    };

    try parseFlightPlan(&self, node);
    return self;
}

fn parseFlightPlan(self: *FlightPlan, node: *c.xmlNode) !void {
    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "created") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.created = try Allocator.dupeZ(self.alloc, u8, mem.sliceTo(copy, 0));
        } else if (c.xmlStrcmp(n.name, "waypoint-table") == 0) {
            try parseWaypointTable(self, n);
        } else if (c.xmlStrcmp(n.name, "route") == 0) {
            self.route = try parseRoute(self.alloc, n);
        }
    }
}

fn parseWaypointTable(self: *FlightPlan, node: *c.xmlNode) !void {
    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "waypoint") == 0) {
            const wp = try parseWaypoint(self.alloc, n);
            try self.waypoints.put(self.alloc, wp.identifier, wp);
        }
    }
}

pub fn parseRoute(alloc: Allocator, node: *c.xmlNode) !Route {
    var self = Route{
        .name = undefined,
        .points = .{},
    };

    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "route-name") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.name = try Allocator.dupe(alloc, u8, mem.sliceTo(copy, 0));
        } else if (c.xmlStrcmp(n.name, "route-point") == 0) {
            try parseRoutePoint(&self, alloc, n);
        }
    }

    return self;
}

fn parseRoutePoint(self: *Route, alloc: Allocator, node: *c.xmlNode) !void {
    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "waypoint-identifier") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            const zcopy = try Allocator.dupe(alloc, u8, mem.sliceTo(copy, 0));
            try self.points.append(alloc, zcopy);
        }
    }
}

pub fn parseWaypoint(alloc: Allocator, node: *c.xmlNode) !Waypoint {
    var self = Waypoint{
        .identifier = undefined,
        .type = undefined,
        .lat = undefined,
        .lon = undefined,
    };

    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "identifier") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.identifier = try Allocator.dupeZ(alloc, u8, mem.sliceTo(copy, 0));
        } else if (c.xmlStrcmp(n.name, "lat") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.lat = try Allocator.dupeZ(alloc, u8, mem.sliceTo(copy, 0));
        } else if (c.xmlStrcmp(n.name, "lon") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.lon = try Allocator.dupeZ(alloc, u8, mem.sliceTo(copy, 0));
        } else if (c.xmlStrcmp(n.name, "type") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.type = Waypoint.Type.fromString(mem.sliceTo(copy, 0));
        }
    }

    return self;
}

test "basic reading" {
    const testPath = testutil.testFile("basic.fpl");
    var plan = try parseFromFile(testing.allocator, testPath);
    defer plan.deinit();

    try testing.expectEqualStrings(plan.created.?, "20211230T22:07:20Z");
    try testing.expectEqual(plan.waypoints.count(), 20);

    // Test route
    try testing.expectEqualStrings(plan.route.name.?, "KHHR TO KHTH");
    try testing.expectEqual(plan.route.points.items.len, 20);

    // Test a waypoint
    {
        const wp = plan.waypoints.get("KHHR").?;
        try testing.expectEqualStrings(wp.identifier, "KHHR");
        try testing.expectEqualStrings(wp.lat, "33.92286102713828");
        try testing.expectEqualStrings(wp.lon, "-118.3350830946681");
        try testing.expectEqual(wp.type, .airport);
        try testing.expectEqualStrings(wp.type.toString(), "AIRPORT");
    }
}
