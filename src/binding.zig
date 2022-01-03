// This file contains the C bindings that are exported when building
// the system libraries.

const std = @import("std");
const Allocator = std.mem.Allocator;
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

export fn fpl_set_created(raw: ?*c.flightplan, str: [*:0]const u8) u8 {
    const fpl = flightplan(raw) orelse return 1;
    const copy = std.mem.span(str);
    fpl.created = Allocator.dupe(c_allocator, u8, copy) catch return 1;
    return 0;
}

export fn fpl_free(raw: ?*c.flightplan) void {
    const fpl = @ptrCast(?*FlightPlan, @alignCast(@alignOf(?*FlightPlan), raw));
    if (fpl) |v| {
        v.deinit();
    }
}

fn flightplan(raw: ?*c.flightplan) ?*FlightPlan {
    return @ptrCast(?*FlightPlan, @alignCast(@alignOf(?*FlightPlan), raw));
}
