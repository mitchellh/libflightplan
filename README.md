# libflightplan (Zig and C)

libflightplan is a library for reading and writing flight plans in
various formats. Flight plans are used in aviation to save properties of
one or more flights such as route (waypoints), altitude, source and departure
airport, etc. This library is written primarily in Zig but exports a C ABI
compatible shared and static library so that any programming language that
can interface with C can interface with this library.

**Library status: Pre-Alpha.** This library is _brand new_, supports
a whopping _one_ format, and is not widely used at the moment.

## Features

* Abstract representation of a flight plan across formats (note that
  not all features are supported by all formats).
* Reading flight plans

### TODO

* Writing flight plans

## Formats

| Name | Ext | Read | Write |
| :--- | :---: | :---: | :---: |
| ForeFlight | FPL | ✅ | ❌ |
| Garmin | FPL | ✅ | ❌ |
