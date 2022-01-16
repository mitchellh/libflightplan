/// Departure represents information about the departure portion of a flight
/// plan, such as the departing airport, runway, procedure, transition, etc.
///
/// This is just the departure procedure metadata. The route of the DP is
/// expected to still be added manually to the FlightPlan's route field.
const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const Runway = @import("Runway.zig");

/// Departure waypoint ID. This waypoint must be present in the waypoints map
/// on a flight plan for more information such as lat/lon. This doesn't have to
/// be an airport, this can be a VOR or another NAVAID.
identifier: [:0]const u8,

/// Departure runway. While this can be set for any identifier, note that
/// a runway is non-sensical for a non-airport identifier.
runway: ?Runway = null,

// Name of the SID used for departure (if any)
sid: ?[:0]const u8 = null,

// Name of the departure transition (if any). This may be set when sid
// is null but that makes no sense.
transition: ?[:0]const u8 = null,

pub fn deinit(self: *Self, alloc: Allocator) void {
    alloc.free(self.identifier);
    if (self.sid) |v| alloc.free(v);
    if (self.transition) |v| alloc.free(v);
    self.* = undefined;
}
