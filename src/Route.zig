const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const xml = @import("xml.zig");
const c = xml.c;
const Error = @import("errors.zig").Error;

const PointsList = std.ArrayListUnmanaged([]const u8);

name: []const u8,
points: PointsList,

pub fn initFromXMLNode(alloc: Allocator, node: *c.xmlNode) !Self {
    var self = Self{
        .name = undefined,
        .points = .{},
    };

    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "route-name") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.name = try Allocator.dupe(alloc, u8, mem.sliceTo(copy, 0));
        } else if (c.xmlStrcmp(n.name, "route-point") == 0) {
            try self.parseRoutePoint(alloc, n);
        }
    }

    return self;
}

fn parseRoutePoint(self: *Self, alloc: Allocator, node: *c.xmlNode) !void {
    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "waypoint-identifier") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            const zcopy = try Allocator.dupe(alloc, u8, mem.sliceTo(copy, 0));
            try self.points.append(alloc, zcopy);
        }
    }
}

pub fn deinit(self: *Self, alloc: Allocator) void {
    alloc.free(self.name);

    while (self.points.popOrNull()) |v| {
        alloc.free(v);
    }
    self.points.deinit(alloc);

    self.* = undefined;
}
