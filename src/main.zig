const std = @import("std");

pub const FlightPlan = @import("FlightPlan.zig");
pub const Waypoint = @import("Waypoint.zig");
pub const Route = @import("Route.zig");
pub const Departure = @import("Departure.zig");
pub const Runway = @import("Runway.zig");
pub const Error = @import("Error.zig");
pub const Format = struct {
    pub const Garmin = @import("format/garmin.zig");
};

/// deinit should be called when the process is done with this library
/// to perform process-level cleanup. This frees memory associated with
/// some global error values.
pub fn deinit() void {
    Error.setLastError(null);
}

test {
    _ = Error;
    _ = Departure;
    _ = FlightPlan;
    _ = Route;
    _ = Runway;
    _ = Format.Garmin;
}
