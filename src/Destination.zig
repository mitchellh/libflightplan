/// Destination represents information about the destination portion of a flight
/// plan, such as the destination airport, arrival, approach, etc.
const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const Runway = @import("Runway.zig");

/// Destination waypoint ID. This waypoint must be present in the waypoints map
/// on a flight plan for more information such as lat/lon. This doesn't have to
/// be an airport, this can be a VOR or another NAVAID.
identifier: [:0]const u8,

/// Destination runway. While this can be set for any identifier, note that
/// a runway is non-sensical for a non-airport identifier.
runway: ?Runway = null,

// Name of the STAR used for arrival (if any).
star: ?[:0]const u8 = null,

// Name of the arrival transition (if any).
star_transition: ?[:0]const u8 = null,

// Name of the approach used for arrival (if any). The recommended format
// is the ARINC 424-18 format, such as LOCD, I26L, etc.
approach: ?[:0]const u8 = null,

// Name of the arrival transition (if any).
approach_transition: ?[:0]const u8 = null,

pub fn deinit(self: *Self, alloc: Allocator) void {
    alloc.free(self.identifier);
    if (self.star) |v| alloc.free(v);
    if (self.star_transition) |v| alloc.free(v);
    if (self.approach) |v| alloc.free(v);
    if (self.approach_transition) |v| alloc.free(v);
    self.* = undefined;
}
