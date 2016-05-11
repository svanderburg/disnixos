{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
, disnixos ? { outPath = ./.; rev = 1234; }
, officialRelease ? false
, fetchDependenciesFromNixpkgs ? false
}:

let
  pkgs = import nixpkgs {};
  
  # Refer either to dysnomia in the parent folder, or to the one in Nixpkgs
  dysnomiaJobset = if fetchDependenciesFromNixpkgs then {
    build = pkgs.lib.genAttrs systems (system:
      (import nixpkgs { inherit system; }).dysnomia
    );
  } else import ../dysnomia/release.nix { inherit nixpkgs systems officialRelease; };
  
  # Refer either to disnix in the parent folder, or to the one in Nixpkgs
  disnixJobset = if fetchDependenciesFromNixpkgs then {
    tarball = pkgs.dysnomia.src;
    
    build = pkgs.lib.genAttrs systems (system:
      (import nixpkgs { inherit system; }).disnix
    );
  } else import ../disnix/release.nix { inherit nixpkgs systems officialRelease; };
  
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

        buildInputs = [ pkgs.socat pkgs.getopt pkgs.pkgconfig pkgs.libxml2 pkgs.libxslt dysnomia disnix pkgs.dblatex (pkgs.dblatex.tex or pkgs.tetex) pkgs.help2man pkgs.doclifter pkgs.nukeReferences ];
        
        # Add documentation in the tarball
        configureFlags = ''
          --with-docbook-rng=${pkgs.docbook5}/xml/rng/docbook
          --with-docbook-xsl=${pkgs.docbook5_xsl}/xml/xsl/docbook
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
        let
          pkgs = import nixpkgs { inherit system; };
          dysnomia = builtins.getAttr system (dysnomiaJobset.build);
          disnix = builtins.getAttr system (disnixJobset.build);
        in
        pkgs.releaseTools.nixBuild {
          name = "disnixos";
          src = tarball;
          buildInputs = [ pkgs.socat pkgs.pkgconfig dysnomia disnix pkgs.getopt ];
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
        
        deploymentNixOps = import ./tests/deployment-nixops.nix {
          inherit nixpkgs dysnomia disnix disnixos;
          inherit (pkgs) writeTextFile openssh;
        };
      };
  };
in jobs
