# libflightplan (Zig and C)

libflightplan is a library for reading and writing flight plans in
various formats. Flight plans are used in aviation to save properties of
one or more flights such as route (waypoints), altitude, source and departure
airport, etc. This library is written primarily in Zig but exports a C ABI
compatible shared and static library so that any programming language that
can interface with C can interface with this library.

**Warning!** If you use this library with the intention of using the
flight plan for actual flight, be very careful to verify the plan in
your avionics or EFB. Never trust the output of this library for actual
flight.

**Library status: Unstable.** This library is _brand new_ and was built for
hobby purposes. It only supports a handful of formats, with limitations.
My primary interest at the time of writing this is ForeFlight flight plans
and being able to use them to build supporting tools, but I'm interested
in supporting more formats over time.

## Formats

| Name | Ext | Read | Write |
| :--- | :---: | :---: | :---: |
| ForeFlight | FPL | ✅ | ✅* |
| Garmin | FPL | ✅ | ✅* |
| X-Plane FMS 11 | FMS | ❌ | ✅* |

\*: The C API doesn't support creating flight plans from scratch or
modifying existing flight plans. But you can read in one format and
encode in another. The Zig API supports full creation and modification.

## Usage

libflightplan can be used from C and [Zig](https://ziglang.org/). Examples
for each are shown below.

### C

The C API is documented as
[man pages](https://github.com/mitchellh/libflightplan/tree/main/doc) as well as the
[flightplan.h header file](https://github.com/mitchellh/libflightplan/blob/main/include/flightplan.h).
An example program is available in [`examples/basic.c`](https://github.com/mitchellh/libflightplan/blob/main/examples/basic.c),
and a simplified version is reproduced below. This example shows how to
read and extract information from a ForeFlight flight plan.

The C API is available as both a static and shared library. To build them,
install [Zig](https://ziglang.org/) and run `zig build install`. This also
installs `pkg-config` files so the header and libraries can be easily found
and integrated with other build systems.

```c
#include <stddef.h>
#include <stdio.h>
#include <flightplan.h>

int main() {
	// Parse our flight plan from an FPL file out of ForeFlight.
	flightplan *fpl = fpl_garmin_parse_file("./test/basic.fpl");
	if (fpl == NULL) {
		// We can get a more detailed error.
		flightplan_error *err = fpl_last_error();
		printf("error: %s\n", fpl_error_message(err));
		fpl_cleanup();
		return 1;
	}

	// Iterate and output the full ordered route.
	int max = fpl_route_points_count(fpl);
	printf("\nroute: \"%s\" (points: %d)\n", fpl_route_name(fpl), max);
	for (int i = 0; i < max; i++) {
		flightplan_route_point *point = fpl_route_points_get(fpl, i);
		printf("  %s\n", fpl_route_point_identifier(point));
	}

	// Convert this to an X-Plane 11 flight plan.
	fpl_xplane11_write_to_file(fpl, "./copy.fms");

	fpl_free(fpl);
	fpl_cleanup();
	return 0;
}
```

### Zig

```zig
const std = @import("std");
const flightplan = @import("flightplan");

fn main() !void {
	defer flightplan.deinit();

	var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer alloc.deinit();

	var fpl = try flightplan.Format.Garmin.initFromFile(alloc, "./test/basic.fpl");
	defer fpl.deinit();

	std.debug.print("route: \"{s}\" (points: {d})\n", .{
		fpl.route.name.?,
		fpl.route.points.items.len,
	});
	for (fpl.route.points.items) |point| {
		std.debug.print("  {s}\n", .{point});
	}

	// Convert to an X-Plane 11 flight plan format
	flightplan.Format.XPlaneFMS11.Format.writeToFile("./copy.fms", fpl);
}
```

## Build

To build libflightplan, you need to fetch the git submodules (`git submodule update --init --recursive`)
and have the following installed:

  * [Zig](https://ziglang.org/)
  * [Libxml2](http://www.xmlsoft.org/)

With the dependencies installed, you can run `zig build` to make a local
build of the libraries. You can run `zig build install` to build and install
the libraries and headers to your standard prefix. And you can run `zig build test`
to run all the tests.

A [Nix](https://nixos.org/) flake is also provided. If you are a Nix user, you
can easily build this library, depend on it, etc. You know who you are and you
know what to do.
