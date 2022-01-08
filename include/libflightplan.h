#ifndef LIBFLIGHTPLAN_H_GUARD
#define LIBFLIGHTPLAN_H_GUARD

// Flight plan types are opaque. Use the various getters to get access
// to fields within the struct.
typedef struct _flightplan flightplan;

char *fpl_get_created(flightplan *);
void fpl_free(flightplan *);

flightplan *fpl_parse_garmin(char *);

#endif
