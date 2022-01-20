{ lib, fetchFromGitHub }:

let
  pname = "zig-libxml2";
  version = "c2cf5ec294d08adfa0fc7aea7245a83871ed19f2";
in fetchFromGitHub {
  name = "${pname}-src-${version}";
  owner = "mitchellh";
  repo = pname;
  rev = version;
  sha256 = "sha256-zQh4yqCOetocb8fV/0Rgbq3JcMhaJQKGgvmsSrdl/h4=";
  fetchSubmodules = true;
}
