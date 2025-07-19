{ pkgs ? import <nixpkgs> { }, }:

let
  unstablenixpkgs = fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  unstablepkgs = import unstablenixpkgs {
    config = { };
    overlays = [ ];
  };

in pkgs.mkShell {

  buildInputs = with pkgs;
    [

      unstablepkgs.flutter

    ];

}
