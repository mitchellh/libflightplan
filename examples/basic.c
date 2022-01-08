#include <stddef.h>
#include <stdio.h>
#include <libflightplan.h>

int main() {
    flightplan *fpl = fpl_parse_garmin("./test/basic.fpl");
    if (fpl == NULL) {
        return 1;
    }

    printf("created at: %s\n\n", fpl_created(fpl));
    printf("waypoints: %d\n", fpl_waypoints_count(fpl));

    flightplan_waypoint_iter *iter = fpl_waypoints_iter(fpl);
    while (1) {
        flightplan_waypoint *wp = fpl_waypoints_next(iter);
        if (wp == NULL) {
            break;
        }

        printf("  %s\t(%s, %s)\n",
                fpl_waypoint_identifier(wp),
                fpl_waypoint_lat(wp),
                fpl_waypoint_lon(wp)
        );
    }
    fpl_waypoint_iter_free(iter);

    fpl_free(fpl);
    return 0;
}
