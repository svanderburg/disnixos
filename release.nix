{ nixpkgs ? <nixpkgs> }:

let
  jobs = rec {
    tarball =
      { disnixos ? {outPath = ./.; rev = 1234;}
      , officialRelease ? false
      , disnix ? (import ../disnix/release.nix {}).build {}
      }:

      with import nixpkgs {};

      releaseTools.sourceTarball {
        name = "disnixos-tarball";
        version = builtins.readFile ./version;
        src = disnixos;
        inherit officialRelease;

        buildInputs = [ socat pkgconfig libxml2 libxslt disnix dblatex tetex nukeReferences ];
        
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
      { tarball ? jobs.tarball {}
      , system ? builtins.currentSystem
      , disnix ? (import ../disnix/release.nix {}).build {}
      }:

      with import nixpkgs { inherit system; };

      releaseTools.nixBuild {
        name = "disnixos";
        src = tarball;
        buildInputs = [ socat pkgconfig disnix ];
      };
  };
in jobs
