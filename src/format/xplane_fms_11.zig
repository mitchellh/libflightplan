/// This file contains the format implementation for the X-Plane FMS v11 format
/// used by X-Plane 11.10 and later.
///
/// Reference: https://developer.x-plane.com/article/flightplan-files-v11-fms-file-format/
const FMS = @This();

const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const Allocator = std.mem.Allocator;

const format = @import("../format.zig");
const testutil = @import("../test.zig");
const time = @import("../time.zig");
const FlightPlan = @import("../FlightPlan.zig");
const Route = @import("../Route.zig");
const Waypoint = @import("../Waypoint.zig");
const Error = @import("../Error.zig");
const ErrorSet = Error.Set;

test {
    _ = Binding;
    _ = Reader;
    _ = Writer;
}

/// The Format type that can be used with the generic functions on FlightPlan.
/// You can also call the direct functions in this file.
pub const Format = format.Format(FMS);

/// Binding are the C bindings for this format.
pub const Binding = struct {
    const binding = @import("../binding.zig");
    const c_allocator = std.heap.c_allocator;

    export fn fpl_xplane11_write_to_file(raw: ?*FlightPlan, path: [*:0]const u8) c_int {
        const fpl = raw orelse return -1;
        Format.writeToFile(mem.sliceTo(path, 0), fpl) catch return -1;
        return 0;
    }
};

/// Reader implementation (see format.zig)
/// TODO
pub const Reader = struct {
    pub fn initFromFile(alloc: Allocator, path: [:0]const u8) !FlightPlan {
        _ = alloc;
        _ = path;
        return ErrorSet.Unimplemented;
    }
};

/// Writer implementation (see format.zig)
pub const Writer = struct {
    pub fn writeTo(writer: anytype, fpl: *const FlightPlan) !void {
        // Buffer that might be used for string operations.
        // Ensure this is always big enough.
        var buf: [8]u8 = undefined;

        // Header
        try writer.writeAll("I\n");
        try writer.writeAll("1100 Version\n");

        // Determine our AIRAC cycle. We try to use the airac cycle
        // on the flight plan. If that's not set, we just make
        // one up based on the current year. Waypoints don't change
        // often and flightplan validation will find this error so
        // if the user got here they are okay with defaults.
        if (fpl.airac) |v| {
            try writer.print("CYCLE {s}\n", .{v});
        } else {
            const t = time.c.time(null);
            const tm = time.c.localtime(&t).*;
            const v = try std.fmt.bufPrintZ(&buf, "{d}01", .{
                // we want years since 2000
                tm.tm_year - 100,
            });

            try writer.print("CYCLE {s}\n", .{v});
        }

        // Departure
        if (fpl.departure) |dep| {
            // Departure airport. If we have departure info set then we use that.
            try writeDeparture(writer, fpl, dep.identifier);

            // Write additional departure info
            try writeDepartureProc(writer, fpl);
        } else if (fpl.route.points.items.len > 0) {
            // No departure info set, we just try to use the first route.
            const point = &fpl.route.points.items[0];
            try writeDeparture(writer, fpl, point.identifier);
        } else {
            // No route
            return ErrorSet.RequiredValueMissing;
        }

        // Destination
        if (fpl.destination) |des| {
            // Departure airport. If we have departure info set then we use that.
            try writeDestination(writer, fpl, des.identifier);

            // Write additional departure info
            try writeDestinationProc(writer, fpl);
        } else if (fpl.route.points.items.len > 0) {
            // No departure info set, we just try to use the first route.
            const point = &fpl.route.points.items[fpl.route.points.items.len - 1];
            try writeDestination(writer, fpl, point.identifier);
        } else {
            // No route
            return ErrorSet.RequiredValueMissing;
        }

        // Route
        try writeRoute(writer, fpl);
    }

    fn writeDeparture(writer: anytype, fpl: *const FlightPlan, id: []const u8) !void {
        // Get the waypoint associated with the departure ID so we can
        // determine the type.
        const wp = fpl.waypoints.get(id) orelse
            return ErrorSet.RouteMissingWaypoint;

        // Prefix we use depends if departure is an airport or not.
        const prefix = switch (wp.type) {
            .airport => "ADEP",
            else => "DEP",
        };

        try writer.print("{s} {s}\n", .{ prefix, wp.identifier });
    }

    fn writeDepartureProc(writer: anytype, fpl: *const FlightPlan) !void {
        var buf: [8]u8 = undefined;
        const dep = fpl.departure.?;

        if (dep.runway) |rwy| try writer.print("DEPRWY RW{s}\n", .{
            try rwy.toString(&buf),
        });

        if (dep.sid) |v| {
            try writer.print("SID {s}\n", .{v});
            if (dep.transition) |transition|
                try writer.print("SIDTRANS {s}\n", .{transition});
        }
    }

    fn writeDestination(writer: anytype, fpl: *const FlightPlan, id: []const u8) !void {
        // Get the waypoint associated with the ID so we can determine the type.
        const wp = fpl.waypoints.get(id) orelse
            return ErrorSet.RouteMissingWaypoint;

        // Prefix we use depends if departure is an airport or not.
        const prefix = switch (wp.type) {
            .airport => "ADES",
            else => "DES",
        };

        try writer.print("{s} {s}\n", .{ prefix, wp.identifier });
    }

    fn writeDestinationProc(writer: anytype, fpl: *const FlightPlan) !void {
        var buf: [8]u8 = undefined;
        const des = fpl.destination.?;

        if (des.runway) |rwy| try writer.print("DESRWY RW{s}\n", .{
            try rwy.toString(&buf),
        });

        if (des.star) |v| {
            try writer.print("STAR {s}\n", .{v});
            if (des.star_transition) |transition|
                try writer.print("STARTRANS {s}\n", .{transition});
        }

        if (des.approach) |v| {
            try writer.print("APP {s}\n", .{v});
            if (des.approach_transition) |transition|
                try writer.print("APPTRANS {s}\n", .{transition});
        }
    }

    fn writeRoute(writer: anytype, fpl: *const FlightPlan) !void {
        try writer.print("NUMENR {d}\n", .{fpl.route.points.items.len});

        for (fpl.route.points.items) |point, i| {
            const wp = fpl.waypoints.get(point.identifier) orelse return ErrorSet.RouteMissingWaypoint;

            const typeCode: u8 = switch (wp.type) {
                .airport => 1,
                .ndb => 2,
                .vor => 3,
                .int => 11,
                .int_vrp => 11,
                .user_waypoint => 28,
            };

            // Get our "via" value for XPlane. If this isn't set, we try to
            // determine it based on what kind of route point this is.
            const via = point.via orelse blk: {
                if (i == 0 and wp.type == .airport) {
                    // First route, airport => departure airport
                    break :blk Route.Point.Via{ .airport_departure = {} };
                } else if (i == fpl.route.points.items.len - 1 and wp.type == .airport) {
                    // Last route, airport => destination airport
                    break :blk Route.Point.Via{ .airport_destination = {} };
                } else {
                    // Anything else, we go direct
                    break :blk Route.Point.Via{ .direct = {} };
                }
            };

            // Convert the Via tagged union to the string value xplane expects
            const viaString = switch (via) {
                .airport_departure => "ADEP",
                .airport_destination => "ADES",
                .direct => "DRCT",
                .airway => |v| v,
            };

            try writer.print("{d} {s} {s} {d} {d} {d}\n", .{
                typeCode,
                wp.identifier,
                viaString,
                point.altitude,
                wp.lat,
                wp.lon,
            });
        }
    }

    test "read Garmin FPL, write X-Plane" {
        const Garmin = @import("garmin.zig");

        const testPath = try testutil.testFile("basic.fpl");
        var plan = try Garmin.Format.initFromFile(testing.allocator, testPath);
        defer plan.deinit();

        // Write the plan and compare
        var output = std.ArrayList(u8).init(testing.allocator);
        defer output.deinit();

        // Write
        try Writer.writeTo(output.writer(), &plan);

        // Debug, write output to compare
        // std.debug.print("write:\n\n{s}\n", .{output.items});

        // TODO: re-read to verify it parses
    }
};
