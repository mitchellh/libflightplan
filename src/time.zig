// This file exports a singular source for time.h from libc.

pub const c = @cImport({
    @cInclude("time.h");
});
