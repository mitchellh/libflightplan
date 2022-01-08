#include <stddef.h>
#include <stdio.h>
#include <flightplan.h>

int main() {
    // Parse our flight plan from an FPL file out of ForeFlight.
    flightplan *fpl = fpl_parse_garmin("./test/basic.fpl");
    if (fpl == NULL) {
        return 1;
    }

    // Extract information from our flight plan easily
    printf("created at: %s\n\n", fpl_created(fpl));

    // Iterate through the available waypoints in the flightplan
    printf("waypoints: %d\n", fpl_waypoints_count(fpl));
    flightplan_waypoint_iter *iter = fpl_waypoints_iter(fpl);
    while (1) {
        flightplan_waypoint *wp = fpl_waypoints_next(iter);
        if (wp == NULL) {
            break;
        }

        printf("  %s\t(type: %s,\tlat/lon: %s/%s)\n",
                fpl_waypoint_identifier(wp),
                fpl_waypoint_type_str(fpl_waypoint_type(wp)),
                fpl_waypoint_lat(wp),
                fpl_waypoint_lon(wp)
        );
    }
    fpl_waypoint_iter_free(iter);

    // Iterate through the ordered route
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
