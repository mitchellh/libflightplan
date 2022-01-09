{ mkShell

, pkg-config
, libxml2
, scdoc
, zig
}: mkShell rec {
  name = "libflightplan";

  nativeBuildInputs = [
    pkg-config
    scdoc
    zig
  ];

  buildInputs = [
    libxml2
  ];
}
