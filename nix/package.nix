{ stdenv
, lib
, zig
, pkg-config
, scdoc
, libxml2
, zig-libxml2-src
}:

stdenv.mkDerivation rec {
  pname = "libflightplan";
  version = "0.1.0";

  src = ./..;

  nativeBuildInputs = [ zig scdoc pkg-config ];

  buildInputs = [
    libxml2
  ];

  dontConfigure = true;

  preBuild = ''
    export HOME=$TMPDIR
    cp -r ${zig-libxml2-src}/* ./vendor/zig-libxml2
  '';

  installPhase = ''
    runHook preInstall
    zig build -Drelease-safe -Dman-pages --prefix $out install
    runHook postInstall
  '';

  outputs = [ "out" "dev" "man" ];

  meta = with lib; {
    description = "A library for reading and writing flight plans in various formats";
    homepage = "https://github.com/mitchellh/libflightplan";
    license = licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
}
