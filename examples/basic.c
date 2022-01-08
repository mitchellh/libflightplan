#include <stddef.h>
#include <stdio.h>
#include <libflightplan.h>

int main() {
    flightplan *fpl = fpl_parse_garmin("./test/basic.fpl");
    if (fpl == NULL) {
        return 1;
    }

    printf("created at: %s\n", fpl_get_created(fpl));

    fpl_free(fpl);
    return 0;
}
