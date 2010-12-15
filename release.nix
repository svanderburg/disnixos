{ nixpkgs ? /etc/nixos/nixpkgs }:

let
  jobs = rec {
    tarball =
      { disnixos ? {outPath = ./.; rev = 1234;}
      , officialRelease ? false
      , disnix ? (import ../../disnix/trunk/release.nix {}).build {}
      }:

      with import nixpkgs {};

      releaseTools.sourceTarball {
        name = "disnixos-tarball";
        version = builtins.readFile ./version;
        src = disnixos;
        inherit officialRelease;

        buildInputs = [ socat pkgconfig disnix ];
      };

    build =
      { tarball ? jobs.tarball {}
      , system ? "x86_64-linux"
      , disnix ? (import ../../disnix/trunk/release.nix {}).build {}
      }:

      with import nixpkgs { inherit system; };

      releaseTools.nixBuild {
        name = "disnixos";
        src = tarball;

        buildInputs = [ socat pkgconfig disnix ];
      };      
  };
in jobs
