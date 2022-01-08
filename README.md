# libflightplan (Zig and C)

libflightplan is a library for reading and writing flight plans in
various formats. Flight plans are used in aviation to save properties of
one or more flights such as route (waypoints), altitude, source and departure
airport, etc. This library is written primarily in Zig but exports a C ABI
compatible shared and static library so that any programming language that
can interface with C can interface with this library.

**Library status: Pre-Alpha.** This library is _brand new_, supports
a whopping _one_ format, and is not widely used at the moment.

## Formats

| Name | Ext | Read | Write |
| :--- | :---: | :---: | :---: |
| ForeFlight | FPL | ✅ | ❌ |
| Garmin | FPL | ✅ | ❌ |

## Usage

libflightplan can be used from C and [Zig](https://ziglang.org/). Examples
for each are shown below.

### C

The C API is documented in the
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
	flightplan *fpl = fpl_parse_garmin("./test/basic.fpl");
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

	fpl_free(fpl);
	fpl_cleanup();
	return 0;
}
```

### Zig

```zig
const std = @import("std");
const flightplan = @import("flightplan");

fn main() void {
	defer flightplan.deinit();

	var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
	defer arena.deinit();

	var fpl = try flightplan.Format.Garmin.parseFromFile(alloc, "./test/basic.fpl");
	defer fpl.deinit();

	std.debug.print("route: \"{s}\" (points: {d})\n", .{
		fpl.route.name.?,
		fpl.route.points.items.len,
	});
	for (fpl.route.points.items) |point| {
		std.debug.print("  {s}\n", .{point});
	}
}
```

## Build

To build libflightplan, you need to have the following installed:

  * [Zig](https://ziglang.org/)
  * [Libxml2](http://www.xmlsoft.org/)

With the dependencies installed, you can run `zig build` to make a local
build of the libraries. You can run `zig build install` to build and install
the libraries and headers to your standard prefix. And you can run `zig build test`
to run all the tests.

A [Nix](https://nixos.org/) flake is also provided. If you are a Nix user, you
can easily build this library, depend on it, etc. You know who you are and you
know what to do.

