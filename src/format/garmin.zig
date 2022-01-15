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
const format = @import("../format.zig");
const testutil = @import("../test.zig");
const xml = @import("../xml.zig");
const c = xml.c;
const Error = @import("../Error.zig");
const ErrorSet = Error.Set;
const Route = @import("../Route.zig");

const Garmin = @This();

test {
    _ = Binding;
    _ = Reader;
    _ = Writer;
}

/// The Format type that can be used with the generic functions on FlightPlan.
/// You can also call the direct functions in this file.
pub const Format = format.Format(Garmin);

/// Initialize a flightplan from a file.
pub fn initFromFile(alloc: Allocator, path: [:0]const u8) !FlightPlan {
    return Reader.initFromFile(alloc, path);
}

/// Encode a flightplan to this format to the given writer. writer should
/// be a std.io.Writer-like implementation.
pub fn writeTo(writer: anytype, fpl: *const FlightPlan) !void {
    return Writer.writeTo(writer, fpl);
}

/// Binding are the C bindings for this format.
pub const Binding = struct {
    const binding = @import("../binding.zig");
    const c_allocator = std.heap.c_allocator;

    export fn fpl_parse_garmin(path: [*:0]const u8) ?*binding.c.flightplan {
        var fpl = Reader.initFromFile(c_allocator, mem.sliceTo(path, 0)) catch return null;
        return binding.cflightplan(fpl);
    }
};

/// Reader implementation (see format.zig)
pub const Reader = struct {
    pub fn initFromFile(alloc: Allocator, path: [:0]const u8) !FlightPlan {
        // Create a parser context. We use the context form rather than the global
        // xmlReadFile form so that we can be a little more thread safe.
        const ctx = c.xmlNewParserCtxt();
        if (ctx == null) {
            Error.setLastError(null);
            return ErrorSet.ReadFailed;
        }
        // NOTE: we do not defer freeing the context cause we want to preserve
        // the context if there are any errors.

        // Read the file
        const doc = c.xmlCtxtReadFile(ctx, path.ptr, null, 0);
        if (doc == null) {
            return Error.setLastErrorXML(ErrorSet.ReadFailed, .{ .parser = ctx });
        }
        defer c.xmlFreeParserCtxt(ctx);
        defer c.xmlFreeDoc(doc);

        // Get the root elem
        const root = c.xmlDocGetRootElement(doc);
        return initFromXMLNode(alloc, root);
    }

    fn initFromXMLNode(alloc: Allocator, node: *c.xmlNode) !FlightPlan {
        // Should be an opening node
        if (node.type != c.XML_ELEMENT_NODE) {
            return ErrorSet.NodeExpected;
        }

        // Should be a "flight-plan" node.
        if (c.xmlStrcmp(node.name, "flight-plan") != 0) {
            Error.setLastError(try Error.initMessage(
                alloc,
                ErrorSet.InvalidElement,
                "flight-plan element not found",
                .{},
            ));

            return ErrorSet.InvalidElement;
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

    fn parseRoute(alloc: Allocator, node: *c.xmlNode) !Route {
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
                self.name = try Allocator.dupeZ(alloc, u8, mem.sliceTo(copy, 0));
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
                const zcopy = try Allocator.dupeZ(alloc, u8, mem.sliceTo(copy, 0));
                try self.points.append(alloc, zcopy);
            }
        }
    }

    fn parseWaypoint(alloc: Allocator, node: *c.xmlNode) !Waypoint {
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
        const testPath = try testutil.testFile("basic.fpl");
        var plan = try Format.initFromFile(testing.allocator, testPath);
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

    test "parse error" {
        const testPath = try testutil.testFile("error_syntax.fpl");
        try testing.expectError(ErrorSet.ReadFailed, Format.initFromFile(testing.allocator, testPath));

        var lastErr = Error.lastError().?;
        defer Error.setLastError(null);
        try testing.expectEqual(lastErr.code, ErrorSet.ReadFailed);

        const xmlErr = lastErr.detail.?.xml.err();
        const message = mem.span(xmlErr.?.message);
        try testing.expect(message.len > 0);
    }

    test "error: no flight-plan" {
        const testPath = try testutil.testFile("error_no_flightplan.fpl");
        try testing.expectError(ErrorSet.InvalidElement, Format.initFromFile(testing.allocator, testPath));

        var lastErr = Error.lastError().?;
        defer Error.setLastError(null);
        try testing.expectEqual(lastErr.code, ErrorSet.InvalidElement);
    }
};

/// Writer implementation (see format.zig)
pub const Writer = struct {
    pub fn writeTo(writer: anytype, fpl: *const FlightPlan) !void {
        _ = writer;
        _ = fpl;

        // Initialize an in-memory buffer. We have to do all writes to a buffer
        // first. We know that our flight plans can't be _that_ big (for a
        // reasonable user) so this is fine.
        var buf = c.xmlBufferCreate();
        if (buf == null) {
            return Error.setLastErrorXML(ErrorSet.OutOfMemory, .{ .global = {} });
        }
        defer c.xmlBufferFree(buf);

        var xmlwriter = c.xmlNewTextWriterMemory(buf, 0);
        if (xmlwriter == null) {
            return Error.setLastErrorXML(ErrorSet.OutOfMemory, .{ .global = {} });
        }

        // Make the output human-friendly
        var rc = c.xmlTextWriterSetIndent(xmlwriter, 1);
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }
        rc = c.xmlTextWriterSetIndentString(xmlwriter, "\t");
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }

        rc = c.xmlTextWriterStartDocument(xmlwriter, "1.0", "utf-8", null);
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }

        // Start <flight-plan>
        const ns = "http://www8.garmin.com/xmlschemas/FlightPlan/v1";
        rc = c.xmlTextWriterStartElementNS(xmlwriter, null, "flight-plan", ns);
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }

        // <created>
        if (fpl.created) |created| {
            rc = c.xmlTextWriterWriteElement(xmlwriter, "created", created);
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }
        }

        // Encode our waypoints
        try writeWaypoints(xmlwriter, fpl);

        // Encode our route
        try writeRoute(xmlwriter, fpl);

        // End <flight-plan>
        rc = c.xmlTextWriterEndElement(xmlwriter);
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }

        // End doc
        rc = c.xmlTextWriterEndDocument(xmlwriter);
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }

        // Free our text writer. We defer this now because errors below no longer
        // need this reference.
        defer c.xmlFreeTextWriter(xmlwriter);

        // Success, lets copy our buffer to the writer.
        try writer.writeAll(mem.span(buf.*.content));
    }

    fn writeWaypoints(xmlwriter: c.xmlTextWriterPtr, fpl: *const FlightPlan) !void {
        // Do nothing if we have no waypoints
        if (fpl.waypoints.count() == 0) {
            return;
        }

        // Start <waypoint-table>
        var rc = c.xmlTextWriterStartElement(xmlwriter, "waypoint-table");
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }

        // Iterate over each waypoint and write it
        var iter = fpl.waypoints.valueIterator();
        while (iter.next()) |wp| {
            // Start <waypoint>
            rc = c.xmlTextWriterStartElement(xmlwriter, "waypoint");
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }

            rc = c.xmlTextWriterWriteElement(xmlwriter, "identifier", wp.identifier);
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }

            rc = c.xmlTextWriterWriteElement(xmlwriter, "type", wp.type.toString());
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }

            rc = c.xmlTextWriterWriteElement(xmlwriter, "lat", wp.lat);
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }

            rc = c.xmlTextWriterWriteElement(xmlwriter, "lon", wp.lon);
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }

            // End <waypoint>
            rc = c.xmlTextWriterEndElement(xmlwriter);
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }
        }

        // End <waypoint-table>
        rc = c.xmlTextWriterEndElement(xmlwriter);
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }
    }

    fn writeRoute(xmlwriter: c.xmlTextWriterPtr, fpl: *const FlightPlan) !void {
        // Start <route>
        var rc = c.xmlTextWriterStartElement(xmlwriter, "route");
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }

        if (fpl.route.name) |name| {
            rc = c.xmlTextWriterWriteElement(xmlwriter, "route-name", name);
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }
        }

        for (fpl.route.points.items) |point| {
            // Find the waypoint for this point
            const wp = fpl.waypoints.get(point) orelse return ErrorSet.RouteMissingWaypoint;

            // Start <route-point>
            rc = c.xmlTextWriterStartElement(xmlwriter, "route-point");
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }

            rc = c.xmlTextWriterWriteElement(xmlwriter, "waypoint-identifier", point);
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }

            rc = c.xmlTextWriterWriteElement(xmlwriter, "waypoint-type", wp.type.toString());
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }

            // End <route-point>
            rc = c.xmlTextWriterEndElement(xmlwriter);
            if (rc < 0) {
                return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
            }
        }

        // End <route>
        rc = c.xmlTextWriterEndElement(xmlwriter);
        if (rc < 0) {
            return Error.setLastErrorXML(ErrorSet.WriteFailed, .{ .writer = xmlwriter });
        }
    }

    test "basic writing" {
        const testPath = try testutil.testFile("basic.fpl");
        var plan = try Format.initFromFile(testing.allocator, testPath);
        defer plan.deinit();

        // Write the plan and compare
        var output = std.ArrayList(u8).init(testing.allocator);
        defer output.deinit();

        // Write
        try Writer.writeTo(output.writer(), &plan);

        // Debug, write output to compare
        //std.debug.print("write:\n\n{s}\n", .{output.items});

        // TODO: re-read to verify it parses
    }
};
