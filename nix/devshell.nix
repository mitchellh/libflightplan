{ mkShell

, pkg-config
, libxml2
, scdoc
, zig
}: mkShell rec {
  name = "libflightplan";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libxml2
    scdoc
    zig
  ];
}
