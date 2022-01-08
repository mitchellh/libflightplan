# libflightplan (Zig and C)

libflightplan is a library for reading and writing flight plans in
various formats. Flight plans are used in aviation to save properties of
one or more flights such as route (waypoints), altitude, source and departure
airport, etc. This library is written primarily in Zig but exports a C ABI
compatible shared and static library so that any programming language that
can interface with C can interface with this library.

**Library status: Pre-Alpha.** This library is _brand new_, supports
a whopping _one_ format, and is not widely used at the moment.

## Features

* Abstract representation of a flight plan across formats (note that
  not all features are supported by all formats).
* Reading flight plans

### TODO

* Writing flight plans

## Formats

| Name | Ext | Read | Write |
| :--- | :---: | :---: | :---: |
| ForeFlight | FPL | ✅ | ❌ |
| Garmin | FPL | ✅ | ❌ |

## Usage (C)

The C API is documented in the
[libflightplan.h header file](https://github.com/mitchellh/libflightplan/blob/main/include/libflightplan.h).
An example program is available in [`examples/basic.c`](https://github.com/mitchellh/libflightplan/blob/main/examples/basic.c),
and a simplified version is reproduced below. This example shows how to
read and extract information from a ForeFlight flight plan.

```c
#include <stddef.h>
#include <stdio.h>
#include <libflightplan.h>

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
