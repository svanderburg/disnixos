{ nixpkgs ? /etc/nixos/nixpkgs }:

let
  jobs = rec {
    tarball =
      { disnix_vm_addons ? {outPath = ./.; rev = 1234;}
      , officialRelease ? false
      , disnix ? (import ../../disnix/trunk/release.nix {}).build {}
      }:

      with import nixpkgs {};

      releaseTools.sourceTarball {
        name = "disnix-vm-addons-tarball";
        version = builtins.readFile ./version;
        src = disnix_vm_addons;
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
        name = "disnix-vm-addons";
        src = tarball;

        buildInputs = [ socat pkgconfig disnix ];
      };      
  };
in jobs
