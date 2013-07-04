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

    tests = 
      { nixos ? <nixos>
      , disnix ? (import ../disnix/release.nix {}).build {}
      , dysnomia ? (import ../dysnomia/release.nix {}).build {}
      }:
      
      let
        pkgs = import nixpkgs {};
        
        disnixos = build { system = builtins.currentSystem; };
        
        networkNix = pkgs.writeTextFile {
          name = "network.nix";
          
          text = ''
            {
              testtarget1 = {pkgs, ...}:
            
              {
                require = [
                  "${nixos}/modules/virtualisation/qemu-vm.nix"
                  "${nixos}/modules/testing/test-instrumentation.nix"
                ];
                #boot.loader.grub.device = "/dev/null";
                #fileSystems."/".device = "/dev/null";
                #services.openssh.enable = true;
                services.disnix.infrastructure.hostname = "testtarget1";
                services.nixosManual.enable = false;
                boot.loader.grub.enable = false;
                environment.systemPackages = [ pkgs.zip ];
              };
            
              testtarget2 = {pkgs, ...}:
              
              {
                require = [
                  "${nixos}/modules/virtualisation/qemu-vm.nix"
                  "${nixos}/modules/testing/test-instrumentation.nix"
                ];
                #boot.loader.grub.device = "/dev/null";
                #fileSystems."/".device = "/dev/null";
                #services.openssh.enable = true;
                services.disnix.infrastructure.hostname = "testtarget1";
                services.nixosManual.enable = false;
                boot.loader.grub.enable = false;
                environment.systemPackages = [ pkgs.hello ];
              };
            }
          '';
        };
      
        network = import networkNix;
        
        networkBuilds = map (targetName:
          let
            target = builtins.getAttr targetName network;
          in
          (import "${nixos}/lib/eval-config.nix" {
            inherit nixpkgs;
            modules = [ target ];
          }).config.system.build.toplevel
        ) (builtins.attrNames network);
      
        machine =
          {config, pkgs, ...}:
            
          {
            virtualisation.writableStore = true;
            
            ids.gids = { disnix = 200; };
            users.extraGroups = [ { gid = 200; name = "disnix"; } ];
            
            services.dbus.enable = true;
            services.dbus.packages = [ disnix ];
            services.openssh.enable = true;
            
            jobs.disnix =
              { description = "Disnix server";

                wantedBy = [ "multi-user.target" ];
                after = [ "dbus.service" ];
                
                path = [ pkgs.nix disnix ];

                script =
                  ''
                    export HOME=/root
                    disnix-service --dysnomia-modules-dir=${dysnomia}/libexec/dysnomia
                  '';
               };
              
            environment.systemPackages = [ pkgs.stdenv pkgs.nix disnix disnixos pkgs.hello pkgs.zip pkgs.busybox pkgs.module_init_tools ];
          };
      in
      with import "${nixos}/lib/testing.nix" { system = builtins.currentSystem; };
      
      {
        deployment = simpleTest {
          nodes = {
            coordinator = machine;
            testtarget1 = machine;
            testtarget2 = machine;
          };
          testScript = "";
          /*testScript = 
            ''
              startAll;
              
              # Initialise ssh stuff by creating a key pair for communication
              my $key=`${pkgs.openssh}/bin/ssh-keygen -t dsa -f key -N ""`;
    
              $testtarget1->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget1->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

              $testtarget2->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget2->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");
              
              $coordinator->mustSucceed("mkdir -m 700 /root/.ssh");
              $coordinator->copyFileFromHost("key", "/root/.ssh/id_dsa");
              $coordinator->mustSucceed("chmod 600 /root/.ssh/id_dsa");
              
              # Deploy the test NixOS network expression
              $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs}:nixos=${nixos} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-deploy-network ${networkNix} --show-trace >&2");
            '';*/
        };
      };
  };
in jobs
