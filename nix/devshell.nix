{ mkShell

, pkg-config
, libxml2
, scdoc
, zig
, glibc
}: mkShell rec {
  name = "libflightplan";

  nativeBuildInputs = [
    glibc
    pkg-config
    scdoc
    zig
  ];

  buildInputs = [
    libxml2
  ];
}
