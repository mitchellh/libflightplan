// This file contains the C bindings that are exported when building
// the system libraries.

const std = @import("std");
const c_allocator = std.heap.c_allocator;

const c = @cImport({
    @cInclude("libflightplan.h");
});

const lib = @import("main.zig");
const FlightPlan = lib.FlightPlan;

export fn fpl_new() ?*c.flightplan {
    const result = c_allocator.create(FlightPlan) catch return null;
    result.* = FlightPlan{ .alloc = c_allocator };
    return @ptrCast(?*c.flightplan, result);
}
