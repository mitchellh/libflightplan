{ mkShell
, zig
}: mkShell rec {
  name = "libflightplan";

  buildInputs = [
    zig
  ];
}
