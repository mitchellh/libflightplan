/// Route structure represents an ordered list of waypoints (and other
/// potential metadata) for a route in a flight plan.
const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const PointsList = std.ArrayListUnmanaged(Point);

/// Name of the route, human-friendly.
name: ?[:0]const u8 = null,

/// Ordered list of points in the route. Currently, each value is a string
/// matching the name of a Waypoint. In the future, this will be changed
/// to a rich struct that has more information.
points: PointsList = .{},

/// Point is a point in a route.
pub const Point = struct {
    /// Identifier of this route point, MUST correspond to a matching
    /// waypoint in the flight plan or most encoding will fail.
    identifier: [:0]const u8,

    /// The route that this point is via, such as an airway. This is used
    /// by certain formats and ignored by most.
    via: ?Via = null,

    /// Altitude in feet (MSL, AGL, whatever you'd like for your flight
    /// plan and format). This is used by some formats to note the desired
    /// altitude at a given point. This can be zero to note cruising altitude
    /// or field elevation.
    altitude: u16 = 0,

    pub const Via = union(enum) {
        airport_departure: void,
        airport_destination: void,
        direct: void,
        airway: [:0]const u8,
    };

    pub fn deinit(self: *Point, alloc: Allocator) void {
        alloc.free(self.identifier);
        self.* = undefined;
    }
};

pub fn deinit(self: *Self, alloc: Allocator) void {
    if (self.name) |v| alloc.free(v);
    while (self.points.popOrNull()) |*v| v.deinit(alloc);
    self.points.deinit(alloc);
    self.* = undefined;
}
