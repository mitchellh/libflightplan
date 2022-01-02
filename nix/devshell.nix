{ mkShell

, pkg-config
, libxml2
, zig
}: mkShell rec {
  name = "libflightplan";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libxml2
    zig
  ];
}
