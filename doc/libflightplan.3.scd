libflightplan(3) "github.com/mitchellh/libflightplan" "Library Functions Manual"

# NAME

libflightplan - library used to read and write aviation flight plans

# DESCRIPTION

*libflightplan* is a library for reading and writing flight plans in
various formats. Flight plans are used in aviation to save properties of
one or more flights such as route (waypoints), altitude, source and departure
airport, etc.

This library is available as a native C library as well as Zig. The man pages
focus on the C API currently.

# API NOTES

- fpl_cleanup(3) should be called when all users of the library are done.
  This cleans up any global state associatd with the library.

- The library may allocate global state on the heap to store error
  information (accessible via fpl_last_error(3)).

- The library is not threadsafe. Global error state is stored in thread local
  variables.

# EXAMPLE

The example below shows how the C API can be used to parse a ForeFlight
flight plan and read route information about it.

```
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

# AUTHORS

Mitchell Hashimoto (xmitchx@gmail.com) and any open source contributors.
See <https://github.com/mitchellh/libflightplan>.
