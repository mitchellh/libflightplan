/// Route structure represents an ordered list of waypoints (and other
/// potential metadata) for a route in a flight plan.
const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const PointsList = std.ArrayListUnmanaged([]const u8);

/// Name of the route, human-friendly.
name: ?[]const u8 = null,

/// Ordered list of points in the route. Currently, each value is a string
/// matching the name of a Waypoint. In the future, this will be changed
/// to a rich struct that has more information.
points: PointsList = .{},

pub fn deinit(self: *Self, alloc: Allocator) void {
    if (self.name) |v| {
        alloc.free(v);
    }

    while (self.points.popOrNull()) |v| {
        alloc.free(v);
    }
    self.points.deinit(alloc);

    self.* = undefined;
}
