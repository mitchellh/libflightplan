#include <libxml/xmlreader.h>

// Zig can't "call" the macro properly so this is a brige function we can
// call in order to initialize libxml.
void _zig_LIBXML_TEST_VERSION() {
    LIBXML_TEST_VERSION
}
