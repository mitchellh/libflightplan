/// Waypoint structure is a single potential waypoint in a route. This
/// contains all the metadata about the waypoint.
const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;

/// Name of the waypoint. This is a key that is used by the route to lookup
/// the waypoint.
identifier: [:0]const u8,

/// Type of the waypoint, such as VOR, NDB, etc.
type: Type,

/// Latitude and longitude of this waypoint.
lat: f32 = 0,
lon: f32 = 0,

pub const Type = enum {
    user_waypoint,
    airport,
    ndb,
    vor,
    int,
    int_vrp,

    pub fn fromString(v: []const u8) Type {
        if (mem.eql(u8, v, "AIRPORT")) {
            return .airport;
        } else if (mem.eql(u8, v, "NDB")) {
            return .ndb;
        } else if (mem.eql(u8, v, "USER WAYPOINT")) {
            return .user_waypoint;
        } else if (mem.eql(u8, v, "VOR")) {
            return .vor;
        } else if (mem.eql(u8, v, "INT")) {
            return .int;
        } else if (mem.eql(u8, v, "INT-VRP")) {
            return .int_vrp;
        }
        @panic("invalid waypoint type");
    }

    pub fn toString(self: Type) [:0]const u8 {
        return switch (self) {
            .user_waypoint => "USER WAYPOINT",
            .airport => "AIRPORT",
            .ndb => "NDB",
            .vor => "VOR",
            .int => "INT",
            .int_vrp => "INT-VRP",
        };
    }
};

pub fn deinit(self: *Self, alloc: Allocator) void {
    alloc.free(self.identifier);
    self.* = undefined;
}
