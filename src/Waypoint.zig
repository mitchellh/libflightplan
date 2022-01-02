const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const xml = @import("xml.zig");
const c = xml.c;
const Error = @import("errors.zig").Error;

identifier: []const u8,
type: Type,
lat: []const u8,
lon: []const u8,

const Type = enum {
    user_waypoint,
    airport,
    ndb,
    vor,
    int,
    int_vrp,

    pub fn fromString(v: []const u8) Type {
        if (mem.eql(u8, v, "AIRPORT")) {
            return .airport;
        } else if (mem.eql(u8, v, "NDB")) {
            return .ndb;
        } else if (mem.eql(u8, v, "USER WAYPOINT")) {
            return .user_waypoint;
        } else if (mem.eql(u8, v, "VOR")) {
            return .vor;
        } else if (mem.eql(u8, v, "INT")) {
            return .int;
        } else if (mem.eql(u8, v, "INT-VRP")) {
            return .int_vrp;
        }

        @panic("invalid waypoint type");
    }
};

pub fn initFromXMLNode(alloc: Allocator, node: *c.xmlNode) !Self {
    var self = Self{
        .identifier = undefined,
        .type = undefined,
        .lat = undefined,
        .lon = undefined,
    };

    var cur: ?*c.xmlNode = node.children;
    while (cur) |n| : (cur = n.next) {
        if (n.type != c.XML_ELEMENT_NODE) {
            continue;
        }

        if (c.xmlStrcmp(n.name, "identifier") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.identifier = try Allocator.dupe(alloc, u8, mem.sliceTo(copy, 0));
        } else if (c.xmlStrcmp(n.name, "lat") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.lat = try Allocator.dupe(alloc, u8, mem.sliceTo(copy, 0));
        } else if (c.xmlStrcmp(n.name, "lon") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.lon = try Allocator.dupe(alloc, u8, mem.sliceTo(copy, 0));
        } else if (c.xmlStrcmp(n.name, "type") == 0) {
            const copy = c.xmlNodeListGetString(node.doc, n.children, 1);
            defer xml.free(copy);
            self.type = Type.fromString(mem.sliceTo(copy, 0));
        }
    }

    return self;
}

pub fn deinit(self: *Self, alloc: Allocator) void {
    alloc.free(self.identifier);
    alloc.free(self.lat);
    alloc.free(self.lon);
    self.* = undefined;
}
