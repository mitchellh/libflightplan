/// The primary abstract flight plan structure. This is the structure that
/// various formats decode to an encode from.
///
/// Note all features of this structure are not supported by all formats.
/// For example, the flight rules field (IFR or VFR) is not used at all by
/// the Garmin or ForeFlight FPL formats, but is used by MSFS 2020 PLN.
/// Formats just ignore information they don't use.
const Self = @This();

const std = @import("std");
const hash_map = std.hash_map;
const Allocator = std.mem.Allocator;

const Waypoint = @import("Waypoint.zig");
const Departure = @import("Departure.zig");
const Route = @import("Route.zig");

/// Allocator associated with this FlightPlan. This allocator must be
/// used for all the memory owned by this structure for deinit to work.
alloc: Allocator,

// The type of flight rules, assumes IFR.
rules: Rules = .ifr,

/// The AIRAC cycle used to create this flight plan, i.e. 2201.
/// See: https://en.wikipedia.org/wiki/Aeronautical_Information_Publication
/// This is expected to be heap-allocated and will be freed on deinit.
airac: ?[:0]const u8 = null,

/// The timestamp when this flight plan was created. This is expected to
/// be heap-allocated and will be freed on deinit.
/// TODO: some well known format
created: ?[:0]const u8 = null,

/// Departure information
departure: ?Departure = null,

/// Waypoints that are part of the route. These are unordered, they are
/// just the full list of possible waypoints that the route may contain.
waypoints: hash_map.StringHashMapUnmanaged(Waypoint) = .{},

/// The flight plan route. This route may only contain waypoints in the
/// waypoints map.
route: Route = .{},

/// Flight rules types
pub const Rules = enum {
    vfr,
    ifr,
};

/// Clean up resources associated with the flight plan. This should
/// always be called for any created flight plan when it is no longer in use.
pub fn deinit(self: *Self) void {
    if (self.airac) |v| self.alloc.free(v);
    if (self.created) |v| self.alloc.free(v);
    if (self.departure) |*dep| dep.deinit(self.alloc);

    self.route.deinit(self.alloc);

    var it = self.waypoints.iterator();
    while (it.next()) |kv| {
        kv.value_ptr.deinit(self.alloc);
    }
    self.waypoints.deinit(self.alloc);

    self.* = undefined;
}

test {
    _ = Waypoint;
    _ = @import("binding.zig");
}
