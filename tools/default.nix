{ pkgs ? import <nixpkgs> { inherit system; }
, system ? builtins.currentSystem
}:

rec {
  build = import ./build {
    inherit (pkgs) stdenv getopt;
  };

  generate-config = import ./generate-config {
    inherit (pkgs) stdenv getopt;
  };

  bsdrc = import ./bsdrc {
    inherit (pkgs) stdenv getopt;
  };

  cygrunsrv = import ./cygrunsrv {
    inherit (pkgs) stdenv getopt;
  };

  launchd = import ./launchd {
    inherit (pkgs) stdenv getopt;
  };

  supervisord = import ./supervisord {
    inherit (pkgs) stdenv getopt;
  };

  systemd = import ./systemd {
    inherit (pkgs) stdenv getopt;
  };

  sysvinit = import ./sysvinit {
    inherit (pkgs) stdenv getopt;
  };
}