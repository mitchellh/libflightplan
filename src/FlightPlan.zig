/// The primary abstract flight plan structure. This is the structure that
/// various formats decode to an encode from. Note all features of this structure
/// are supported by all formats.
const Self = @This();

const std = @import("std");
const hash_map = std.hash_map;
const Allocator = std.mem.Allocator;

const Waypoint = @import("Waypoint.zig");
const Error = @import("errors.zig").Error;
const Route = @import("Route.zig");

/// Allocator associated with this FlightPlan. This allocator must be
/// used for all the memory owned by this structure for deinit to work.
alloc: Allocator,

created: ?[]const u8 = null,

/// Waypoints that are part of the route. These are unordered, they are
/// just the full list of possible waypoints that the route may contain.
waypoints: hash_map.StringHashMapUnmanaged(Waypoint) = .{},

/// The flight plan route. This route may only contain waypoints in the
/// waypoints map.
route: Route = .{},

pub fn deinit(self: *Self) void {
    if (self.created) |v| {
        self.alloc.free(v);
    }

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
}
