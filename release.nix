{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
, disnixos ? { outPath = ./.; rev = 1234; }
, officialRelease ? false
, disnixJobset ? import ../disnix/release.nix { inherit nixpkgs systems officialRelease; }
, dysnomiaJobset ? import ../dysnomia/release.nix { inherit nixpkgs systems officialRelease; }
}:

let
  pkgs = import nixpkgs {};
  
  jobs = rec {
    tarball =
      with pkgs;

      let
        disnix = builtins.getAttr (builtins.currentSystem) (disnixJobset.build);
      in
      releaseTools.sourceTarball {
        name = "disnixos-tarball";
        version = builtins.readFile ./version;
        src = disnixos;
        inherit officialRelease;
        dontBuild = false;

        buildInputs = [ socat getopt pkgconfig libxml2 libxslt disnix dblatex tetex help2man doclifter nukeReferences ];
        
        # Add documentation in the tarball
        configureFlags = ''
          --with-docbook-rng=${docbook5}/xml/rng/docbook
          --with-docbook-xsl=${docbook5_xsl}/xml/xsl/docbook
        '';
        
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
        
        with import nixpkgs { inherit system; };
        
        let
          disnix = builtins.getAttr system (disnixJobset.build);
        in
        releaseTools.nixBuild {
          name = "disnixos";
          src = tarball;
          buildInputs = [ socat pkgconfig disnix getopt ];
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
        
        deploymentNixOps = import ./tests/deployment-nixops.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
        };
      };
  };
in jobs
