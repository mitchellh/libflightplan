// This file contains the C bindings that are exported when building
// the system libraries.
//
// WHERE IS THE DOCUMENTATION? Note that all the documentation for the C
// interface is in the header file libflightplan.h. The implementation for
// these various functions may have some comments but are meant towards
// maintainers.

const std = @import("std");
const Allocator = std.mem.Allocator;
const c_allocator = std.heap.c_allocator;

const lib = @import("main.zig");
const FlightPlan = lib.FlightPlan;

/// The C headers for our binding. This is public so that formats can
/// import this and use these for types.
pub const c = @cImport({
    @cInclude("libflightplan.h");
});

//-------------------------------------------------------------------
// Formats

pub usingnamespace @import("format/garmin.zig").Binding;

//-------------------------------------------------------------------
// General functions

export fn fpl_new() ?*c.flightplan {
    const result = c_allocator.create(FlightPlan) catch return null;
    result.* = FlightPlan{ .alloc = c_allocator };
    return @ptrCast(?*c.flightplan, result);
}

export fn fpl_set_created(raw: ?*c.flightplan, str: [*:0]const u8) u8 {
    const fpl = flightplan(raw) orelse return 1;
    const copy = std.mem.span(str);
    fpl.created = Allocator.dupeZ(c_allocator, u8, copy) catch return 1;
    return 0;
}

export fn fpl_get_created(raw: ?*c.flightplan) ?[*:0]const u8 {
    if (flightplan(raw)) |fpl| {
        if (fpl.created) |v| {
            return v.ptr;
        }
    }

    return null;
}

export fn fpl_free(raw: ?*c.flightplan) void {
    if (flightplan(raw)) |v| {
        v.deinit();
    }
}

pub fn flightplan(raw: ?*c.flightplan) ?*FlightPlan {
    return @ptrCast(?*FlightPlan, @alignCast(@alignOf(?*FlightPlan), raw));
}

pub fn cflightplan(fpl: FlightPlan) ?*c.flightplan {
    const result = c_allocator.create(FlightPlan) catch return null;
    result.* = fpl;
    return @ptrCast(?*c.flightplan, result);
}
