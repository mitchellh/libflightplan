#include <stddef.h>
#include <libflightplan.h>

int main() {
    flightplan *fpl = fpl_parse_garmin("./test/basic.fpl");
    if (fpl == NULL) {
        return 1;
    }

    fpl_free(fpl);
    return 0;
}
