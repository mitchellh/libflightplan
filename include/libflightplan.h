#ifndef LIBFLIGHTPLAN_H_GUARD
#define LIBFLIGHTPLAN_H_GUARD

// A flightplan represents the primary flightplan data structure.
typedef void flightplan;

/*
 * NAME fpl_new()
 *
 * DESCRIPTION
 *
 * Create a new empty flight plan.
 */
flightplan *fpl_new();

/*
 * NAME fpl_free()
 *
 * DESCRIPTION
 *
 * Free resources associated with a flight plan. The flight plan can no longer
 * be used after this is called. This must be called for any flight plan that
 * is returned.
 */
void fpl_free(flightplan *);

/*
 * NAME fpl_created()
 *
 * DESCRIPTION
 *
 * Returns the timestamp when the flight plan was created.
 *
 * NOTE(mitchellh): This raw string is not what I want long term. I want to
 * convert this to a UTC unix timestamp, so this function will probably change
 * to a time_t result at some point.
 */
char *fpl_created(flightplan *);

/**************************************************************************
 * Import/Export
 *************************************************************************/

/*
 * NAME fpl_parse_garmin()
 *
 * DESCRIPTION
 *
 * Parse a Garmin FPL file. This is also compatible with ForeFlight.
 */
flightplan *fpl_parse_garmin(char *);

/**************************************************************************
 * Waypoints
 *************************************************************************/

// A waypoint that the flight plan may or may not use but knows about.
typedef void flightplan_waypoint;
typedef void flightplan_waypoint_iter;

/*
 * NAME fpl_waypoints_count()
 *
 * DESCRIPTION
 *
 * Returns the total number of waypoints that are in this flight plan.
 */
int fpl_waypoints_count(flightplan *);

/*
 * NAME fpl_waypoint_iter()
 *
 * DESCRIPTION
 *
 * Returns an iterator that can be used to read each of the waypoints.
 * The iterator is only valid so long as zero modifications are made
 * to the waypoint list.
 *
 * The iterator must be freed with fpl_waypoint_iter_free.
 */
flightplan_waypoint_iter *fpl_waypoints_iter(flightplan *);

/*
 * NAME fpl_waypoint_iter_free()
 *
 * DESCRIPTION
 *
 * Free resources associated with an iterator.
 */
void fpl_waypoint_iter_free(flightplan_waypoint_iter *);

/*
 * NAME fpl_waypoints_next()
 *
 * DESCRIPTION
 *
 * Get the next waypoint for the iterator. This returns NULL when there are
 * no more waypoints available.
 */
flightplan_waypoint *fpl_waypoints_next(flightplan_waypoint_iter *);

flightplan_waypoint *fpl_waypoint_new();
void fpl_waypoint_free(flightplan_waypoint *);
char *fpl_waypoint_identifier(flightplan_waypoint *);

#endif
