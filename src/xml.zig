pub const c = @cImport({
    @cDefine("LIBXML_WRITER_ENABLED", {});
    @cInclude("libxml/xmlreader.h");
    @cInclude("libxml/xmlwriter.h");
});

// free calls xmlFree
pub fn free(ptr: ?*anyopaque) void {
    if (ptr) |v| {
        c.xmlFree.?(v);
    }
}

/// Find a node that has the given element type and return it. This looks
/// in sibling nodes.
pub fn findNode(node: ?*c.xmlNode, name: []const u8) ?*c.xmlNode {
    var cur = node;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, name.ptr) == 0) {
            return n;
        }
    }

    return null;
}
