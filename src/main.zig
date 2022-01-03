const std = @import("std");

pub const FlightPlan = @import("FlightPlan.zig");
pub const Waypoint = @import("Waypoint.zig");
pub const Route = @import("Route.zig");
pub const Format = struct {
    pub const Garmin = @import("format/garmin.zig");
};

test {
    _ = FlightPlan;
    _ = Format.Garmin;
}
