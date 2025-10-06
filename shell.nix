{ pkgs ? import <nixpkgs> { }, }:

let
  unstablenixpkgs = fetchTarball {
    url =
      "https://github.com/NixOS/nixpkgs/archive/34a26e5164c13b960cff8ea54ab3e4b5fec796a9.tar.gz";
    sha256 = "0iap44a9f92hrbgqf80q2sr69ixc4p06qsvw755wi11m2m2p4hqf";
  };
  unstablepkgs = import unstablenixpkgs {
    config = { };
    overlays = [ ];
  };

in pkgs.mkShell {

  buildInputs = [

    unstablepkgs.flutter

  ];

}
