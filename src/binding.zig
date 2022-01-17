// This file contains the C bindings that are exported when building
// the system libraries.
//
// WHERE IS THE DOCUMENTATION? Note that all the documentation for the C
// interface is in the header file flightplan.h. The implementation for
// these various functions may have some comments but are meant towards
// maintainers.

const std = @import("std");
const Allocator = std.mem.Allocator;
const c_allocator = std.heap.c_allocator;

const lib = @import("main.zig");
const Error = lib.Error;
const FlightPlan = lib.FlightPlan;
const Waypoint = lib.Waypoint;
const Route = lib.Route;
const testutil = @import("test.zig");

const c = @cImport({
    @cInclude("flightplan.h");
});

//-------------------------------------------------------------------
// Formats

pub usingnamespace @import("format/garmin.zig").Binding;
pub usingnamespace @import("format/xplane_fms_11.zig").Binding;

//-------------------------------------------------------------------
// General functions

export fn fpl_cleanup() void {
    lib.deinit();
}

export fn fpl_new() ?*FlightPlan {
    return cflightplan(.{ .alloc = c_allocator });
}

export fn fpl_set_created(raw: ?*FlightPlan, str: [*:0]const u8) u8 {
    const fpl = raw orelse return 1;
    const copy = std.mem.span(str);
    fpl.created = Allocator.dupeZ(c_allocator, u8, copy) catch return 1;
    return 0;
}

export fn fpl_created(raw: ?*FlightPlan) ?[*:0]const u8 {
    if (raw) |fpl| {
        if (fpl.created) |v| {
            return v.ptr;
        }
    }

    return null;
}

export fn fpl_free(raw: ?*FlightPlan) void {
    if (raw) |v| {
        v.deinit();
        c_allocator.destroy(v);
    }
}

pub fn cflightplan(fpl: FlightPlan) ?*FlightPlan {
    const result = c_allocator.create(FlightPlan) catch return null;
    result.* = fpl;
    return result;
}

//-------------------------------------------------------------------
// Errors

export fn fpl_last_error() ?*Error {
    return Error.lastError();
}

export fn fpl_error_message(raw: ?*Error) ?[*:0]const u8 {
    const err = raw orelse return null;
    return err.message().ptr;
}

//-------------------------------------------------------------------
// Waypoints

const WPIterator = std.meta.fieldInfo(FlightPlan, .waypoints).field_type.ValueIterator;

export fn fpl_waypoints_count(raw: ?*FlightPlan) c_int {
    if (raw) |fpl| {
        return @intCast(c_int, fpl.waypoints.count());
    }

    return 0;
}

export fn fpl_waypoints_iter(raw: ?*FlightPlan) ?*WPIterator {
    const fpl = raw orelse return null;
    const iter = fpl.waypoints.valueIterator();

    const result = c_allocator.create(@TypeOf(iter)) catch return null;
    result.* = iter;
    return result;
}

export fn fpl_waypoint_iter_free(raw: ?*WPIterator) void {
    if (raw) |iter| {
        c_allocator.destroy(iter);
    }
}

export fn fpl_waypoints_next(raw: ?*WPIterator) ?*Waypoint {
    const iter = raw orelse return null;
    return iter.next();
}

export fn fpl_waypoint_identifier(raw: ?*Waypoint) ?[*:0]const u8 {
    const wp = raw orelse return null;
    return wp.identifier.ptr;
}

export fn fpl_waypoint_lat(raw: ?*Waypoint) f32 {
    const wp = raw orelse return -1;
    return wp.lat;
}

export fn fpl_waypoint_lon(raw: ?*Waypoint) f32 {
    const wp = raw orelse return -1;
    return wp.lon;
}

export fn fpl_waypoint_type(raw: ?*Waypoint) c.flightplan_waypoint_type {
    const wp = raw orelse return c.FLIGHTPLAN_INVALID;
    return @enumToInt(wp.type) + 1; // must add 1 due to _INVALID
}

export fn fpl_waypoint_type_str(raw: c.flightplan_waypoint_type) [*:0]const u8 {
    // subtraction here due to _INVALID
    return @intToEnum(Waypoint.Type, raw - 1).toString().ptr;
}

//-------------------------------------------------------------------
// Route

export fn fpl_route_name(raw: ?*FlightPlan) ?[*:0]const u8 {
    const fpl = raw orelse return null;
    if (fpl.route.name) |v| {
        return v.ptr;
    }

    return null;
}

export fn fpl_route_points_count(raw: ?*FlightPlan) c_int {
    const fpl = raw orelse return 0;
    return @intCast(c_int, fpl.route.points.items.len);
}

export fn fpl_route_points_get(raw: ?*FlightPlan, idx: c_int) ?*Route.Point {
    const fpl = raw orelse return null;
    return &fpl.route.points.items[@intCast(usize, idx)];
}

export fn fpl_route_point_identifier(raw: ?*Route.Point) ?[*:0]const u8 {
    const ptr = raw orelse return null;
    return ptr.identifier;
}
