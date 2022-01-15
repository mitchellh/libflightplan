const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const Allocator = std.mem.Allocator;

const FlightPlan = @import("FlightPlan.zig");

/// Format returns a typed format for the given underlying implementation.
///
/// Users do NOT need to use this type; most formats have direct reader/writer
/// functions you can use directly. This generic type is here just to be useful
/// as a way to guide format implementors to a common format and to add higher
/// level operations in the future.
///
/// Implementations must support the following fields:
///
///   * Binding: type - C bindings to expose
///   * Reader: type - Reader implementation for reading flight plans.
///   * Writer: type - Writer implementatino for encoding flight plans.
///
/// TODO: more docs
pub fn Format(
    comptime Impl: type,
) type {
    return struct {
        /// Initialize a flight plan from a file path.
        pub fn initFromFile(alloc: Allocator, path: [:0]const u8) !FlightPlan {
            return Impl.Reader.initFromFile(alloc, path);
        }

        /// Write the flightplan to the given writer. writer is expected
        /// to implement std.io.writer.
        pub fn writeTo(writer: anytype, fpl: *const FlightPlan) !void {
            return Impl.Writer.writeTo(writer, fpl);
        }
    };
}
