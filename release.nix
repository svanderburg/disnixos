{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
, disnixos ? { outPath = ./.; rev = 1234; }
, dysnomia ? { outPath = ../dysnomia; rev = 1234; }
, disnix ? { outPath = ../disnix; rev = 1234; }
, officialRelease ? false
}:

let
  pkgs = import nixpkgs {};

  dysnomiaJobset = import "${dysnomia}/release.nix" {
    inherit nixpkgs systems officialRelease dysnomia;
  };

  disnixJobset = import "${disnix}/release.nix" {
    inherit nixpkgs systems officialRelease dysnomia disnix;
  };

  jobs = rec {
    tarball =
      let
        dysnomia = builtins.getAttr (builtins.currentSystem) (dysnomiaJobset.build);
        disnix = builtins.getAttr (builtins.currentSystem) (disnixJobset.build);
      in
      pkgs.releaseTools.sourceTarball {
        name = "disnixos-tarball";
        version = builtins.readFile ./version;
        src = disnixos;
        inherit officialRelease;
        dontBuild = false;

        buildInputs = [ pkgs.socat pkgs.getopt pkgs.pkg-config pkgs.libxml2 pkgs.libxslt dysnomia disnix pkgs.dblatex (pkgs.dblatex.tex or pkgs.tetex) pkgs.help2man pkgs.doclifter pkgs.nukeReferences ];

        # Add documentation in the tarball
        configureFlags = [
          "--with-docbook-rng=${pkgs.docbook5}/xml/rng/docbook"
          "--with-docbook-xsl=${pkgs.docbook_xsl_ns}/xml/xsl/docbook"
        ];

        preConfigure = ''
          # TeX needs a writable font cache.
          export VARTEXFONTS=$TMPDIR/texfonts
        '';

        preDist = ''
          make -C doc/manual install prefix=$out

          make -C doc/manual index.pdf prefix=$out
          cp doc/manual/index.pdf $out/index.pdf

          # The PDF containes filenames of included graphics (see
          # http://www.tug.org/pipermail/pdftex/2007-August/007290.html).
          # This causes a retained dependency on dblatex, which Hydra
          # doesn't like (the output of the tarball job is distributed
          # to Windows and Macs, so there should be no Linux binaries
          # in the closure).
          nuke-refs $out/index.pdf

          echo "doc-pdf manual $out/index.pdf" >> $out/nix-support/hydra-build-products
          echo "doc manual $out/share/doc/disnixos/manual" >> $out/nix-support/hydra-build-products
        '';
      };

    build =
      pkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          dysnomia = builtins.getAttr system (dysnomiaJobset.build);
          disnix = builtins.getAttr system (disnixJobset.build);
        in
        pkgs.releaseTools.nixBuild {
          name = "disnixos";
          src = tarball;
          buildInputs = [ pkgs.socat pkgs.pkg-config dysnomia disnix pkgs.getopt ];
        }
      );

    tests =
      let
        dysnomia = builtins.getAttr (builtins.currentSystem) (dysnomiaJobset.build);
        disnix = builtins.getAttr (builtins.currentSystem) (disnixJobset.build);
        disnixos = builtins.getAttr (builtins.currentSystem) build;
      in
      {
        deploymentInfra = import ./tests/deployment-infra.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
        };

        deploymentInfraWithData = import ./tests/deployment-infra-with-data.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile runCommand openssh;
          dysnomiaTarball = dysnomiaJobset.tarball;
        };

        distbuildInfra = import ./tests/distbuild-infra.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
        };

        deploymentServices = import ./tests/deployment-services.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
        };

        deploymentServicesWithData = import ./tests/deployment-services-with-data.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
        };

        distbuildServices = import ./tests/distbuild-services.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
        };

        nixopsClientToDBus = import ./tests/nixops-client.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
          disnixRemoteClient = "disnix-client";
        };

        nixopsClientToRunActivity = import ./tests/nixops-client.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
          disnixRemoteClient = "disnix-run-activity";
        };

        snapshotsViaDBus = import ./tests/snapshots.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) stdenv writeTextFile openssh;
          disnixRemoteClient = "disnix-client";
        };

        snapshotsViaRunActivity = import ./tests/snapshots.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) stdenv writeTextFile openssh;
          disnixRemoteClient = "disnix-run-activity";
        };

        deploymentNixOps = import ./tests/deployment-nixops.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
        };
      };

    release = pkgs.releaseTools.aggregate {
      name = "disnixos-${tarball.version}";
      constituents = [
        tarball
      ]
      ++ map (system: builtins.getAttr system build) systems
      ++ [
        tests.deploymentInfra
        tests.deploymentInfraWithData
        tests.distbuildInfra
        tests.deploymentServices
        tests.deploymentServicesWithData
        tests.distbuildServices
        tests.nixopsClientToDBus
        tests.nixopsClientToRunActivity
        tests.snapshotsViaDBus
        tests.snapshotsViaRunActivity
        tests.deploymentNixOps
      ];
      meta.description = "Release-critical builds";
    };
  };
in jobs
