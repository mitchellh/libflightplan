#include <stddef.h>
#include <stdio.h>
#include <libflightplan.h>

int main() {
    flightplan *fpl = fpl_parse_garmin("./test/basic.fpl");
    if (fpl == NULL) {
        return 1;
    }

    printf("created at: %s\n", fpl_created(fpl));
    printf("waypoints: %d\n", fpl_waypoints_count(fpl));

    fpl_free(fpl);
    return 0;
}
