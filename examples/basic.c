#include <libflightplan.h>

int main() {
    flightplan *fpl = fpl_new();
    fpl_set_created(fpl, "yo");
    fpl_free(fpl);
    return 0;
}
