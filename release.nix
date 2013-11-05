{ nixpkgs ? <nixpkgs> }:

let
  jobs = rec {
    tarball =
      { disnixos ? {outPath = ./.; rev = 1234;}
      , officialRelease ? false
      , disnix ? builtins.getAttr (builtins.currentSystem) ((import ../disnix/release.nix {}).build {}) {}
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
      { tarball ? jobs.tarball { inherit disnix; }
      , system ? builtins.currentSystem
      , disnix ? builtins.getAttr (builtins.currentSystem) ((import ../disnix/release.nix {}).build {}) {}
      }:

      with import nixpkgs { inherit system; };

      releaseTools.nixBuild {
        name = "disnixos";
        src = tarball;
        buildInputs = [ socat pkgconfig disnix ];
      };

    tests = 
      { disnix ? (import ../disnix/release.nix {}).build {}
      , dysnomia ? (import ../dysnomia/release.nix {}).build {}
      }:
      
      let
        pkgs = import nixpkgs {};
        
        disnixos = build {
          system = builtins.currentSystem;
          inherit disnix;
        };
        
        logicalNetworkNix = pkgs.writeTextFile {
          name = "network-logical.nix";
          
          text = ''
            {
              testtarget1 = {pkgs, ...}:
            
              {
                environment.systemPackages = [ pkgs.zip ];
              };
            
              testtarget2 = {pkgs, ...}:
              
              {
                environment.systemPackages = [ pkgs.hello ];
              };
            }
          '';
        };
        
        physicalNetworkNix = pkgs.writeTextFile {
          name = "network-physical.nix";
          
          text = ''
            let
              machine = {hostname}: {pkgs, ...}:
            
              {
                require = [
                  "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
                  "${nixpkgs}/nixos/modules/testing/test-instrumentation.nix"
                ];
                boot.loader.grub.enable = false;
                disnixInfrastructure.enable = true;
                disnixInfrastructure.infrastructure.hostname = hostname;
                services.nixosManual.enable = false;
                services.dbus.enable = true;
                
                # Create dummy Disnix job that does nothing. This prevents it from stopping.
                jobs.disnix =
                  { description = "Disnix dummy server";

                    wantedBy = [ "multi-user.target" ];
                    restartIfChanged = false;
                    script = "true";
                  };
              };
            in
            {
              testtarget1 = machine { hostname = "testtarget1"; };
              testtarget2 = machine { hostname = "testtarget2"; };
            }
          '';
        };
      
        machine =
          {config, pkgs, ...}:
          
          {
            virtualisation.writableStore = true;
            virtualisation.memorySize = 1024;
            virtualisation.diskSize = 10240;
            
            ids.gids = { disnix = 200; };
            users.extraGroups = [ { gid = 200; name = "disnix"; } ];
            
            services.dbus.enable = true;
            services.dbus.packages = [ disnix ];
            services.openssh.enable = true;
            
            jobs.ssh.restartIfChanged = false;
            
            jobs.disnix =
              { description = "Disnix server";

                wantedBy = [ "multi-user.target" ];
                after = [ "dbus.service" ];
                
                path = [ pkgs.nix disnix ];
                restartIfChanged = false; # Important, otherwise we cannot upgrade

                script =
                  ''
                    export HOME=/root
                    disnix-service --dysnomia-modules-dir=${dysnomia}/libexec/dysnomia
                  '';
               };
              
            environment.systemPackages = [ pkgs.stdenv pkgs.nix disnix disnixos pkgs.busybox pkgs.module_init_tools pkgs.hello pkgs.zip ];
          };
          
          manifestTests = ./tests/manifest;
      in
      with import "${nixpkgs}/lib/testing.nix" { system = builtins.currentSystem; };
      
      {
        deploymentInfra = simpleTest {
          nodes = {
            coordinator = machine;
            testtarget1 = machine;
            testtarget2 = machine;
          };
          testScript = 
            ''
              startAll;
              $coordinator->waitForJob("network-interfaces.target");
              $testtarget1->waitForJob("disnix");
              $testtarget2->waitForJob("disnix");
              
              # Initialise ssh stuff by creating a key pair for communication
              my $key=`${pkgs.openssh}/bin/ssh-keygen -t dsa -f key -N ""`;
    
              $testtarget1->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget1->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

              $testtarget2->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget2->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");
              
              $coordinator->mustSucceed("mkdir -m 700 /root/.ssh");
              $coordinator->copyFileFromHost("key", "/root/.ssh/id_dsa");
              $coordinator->mustSucceed("chmod 600 /root/.ssh/id_dsa");
              
              # Deploy the test NixOS network expression. This test should succeed.
              $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-deploy-network ${logicalNetworkNix} ${physicalNetworkNix} --disable-disnix --show-trace");
              
              # Check if zip is installed on the correct machine
              $testtarget1->mustSucceed("zip -h");
              $testtarget2->mustFail("zip -h");
              
              # Check if hello is installed on the correct machine
              $testtarget2->mustSucceed("hello");
              $testtarget1->mustFail("hello");
            '';
        };
        
        distbuildInfra = simpleTest {
          nodes = {
            coordinator = machine;
            testtarget1 = machine;
            testtarget2 = machine;
          };
          testScript = 
            ''
              startAll;
              $coordinator->waitForJob("network-interfaces.target");
              $testtarget1->waitForJob("disnix");
              $testtarget2->waitForJob("disnix");
              
              # Initialise ssh stuff by creating a key pair for communication
              my $key=`${pkgs.openssh}/bin/ssh-keygen -t dsa -f key -N ""`;
    
              $testtarget1->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget1->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

              $testtarget2->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget2->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");
              
              $coordinator->mustSucceed("mkdir -m 700 /root/.ssh");
              $coordinator->copyFileFromHost("key", "/root/.ssh/id_dsa");
              $coordinator->mustSucceed("chmod 600 /root/.ssh/id_dsa");
              
              # Deploy the test NixOS network expression. This test should succeed.
              $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-deploy-network ${logicalNetworkNix} ${physicalNetworkNix} --disable-disnix --build-on-targets");
              
              # Check if zip is installed on the correct machine
              $testtarget1->mustSucceed("zip -h");
              $testtarget2->mustFail("zip -h");
              
              # Check if hello is installed on the correct machine
              $testtarget2->mustSucceed("hello");
              $testtarget1->mustFail("hello");
            '';
        };
        
        deploymentServices = simpleTest {
          nodes = {
            coordinator = machine;
            testtarget1 = machine;
            testtarget2 = machine;
          };
          testScript = 
            ''
              startAll;
              $coordinator->waitForJob("network-interfaces.target");
              $testtarget1->waitForJob("disnix");
              $testtarget2->waitForJob("disnix");
              
              # Initialise ssh stuff by creating a key pair for communication
              my $key=`${pkgs.openssh}/bin/ssh-keygen -t dsa -f key -N ""`;
    
              $testtarget1->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget1->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

              $testtarget2->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget2->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");
              
              $coordinator->mustSucceed("mkdir -m 700 /root/.ssh");
              $coordinator->copyFileFromHost("key", "/root/.ssh/id_dsa");
              $coordinator->mustSucceed("chmod 600 /root/.ssh/id_dsa");
              
              # Deploy a NixOS network and services in a network specified by a NixOS network expression simultaneously
              $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-env -s ${manifestTests}/services.nix -n ${physicalNetworkNix} -d ${manifestTests}/distribution.nix --disable-disnix --no-infra-deployment");
              
              # Use disnixos-query to see if the right services are installed on
              # the right target platforms. This test should succeed.
              my @lines = split('\n', $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-query ${physicalNetworkNix}"));
              
              if(@lines[3] =~ /\-testService1/) {
                  print "Found testService1 on disnix-query output line 3\n";
              } else {
                  die "disnix-query output line 3 does not contain testService1!\n";
              }
              
              if(@lines[7] =~ /\-testService2/) {
                  print "Found testService2 on disnix-query output line 7\n";
              } else {
                  die "disnix-query output line 7 does not contain testService2!\n";
              }
              
              if(@lines[8] =~ /\-testService3/) {
                  print "Found testService3 on disnix-query output line 8\n";
              } else {
                  die "disnix-query output line 8 does not contain testService3!\n";
              }
            '';
        };
        
        distbuildServices = simpleTest {
          nodes = {
            coordinator = machine;
            testtarget1 = machine;
            testtarget2 = machine;
          };
          testScript = 
            ''
              startAll;
              $coordinator->waitForJob("network-interfaces.target");
              $testtarget1->waitForJob("disnix");
              $testtarget2->waitForJob("disnix");
              
              # Initialise ssh stuff by creating a key pair for communication
              my $key=`${pkgs.openssh}/bin/ssh-keygen -t dsa -f key -N ""`;
    
              $testtarget1->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget1->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

              $testtarget2->mustSucceed("mkdir -m 700 /root/.ssh");
              $testtarget2->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");
              
              $coordinator->mustSucceed("mkdir -m 700 /root/.ssh");
              $coordinator->copyFileFromHost("key", "/root/.ssh/id_dsa");
              $coordinator->mustSucceed("chmod 600 /root/.ssh/id_dsa");
              
              # Deploy a NixOS network and services in a network specified by a NixOS network expression simultaneously
              $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-env -s ${manifestTests}/services.nix -n ${physicalNetworkNix} -d ${manifestTests}/distribution.nix --disable-disnix --no-infra-deployment --build-on-targets");
              
              # Use disnixos-query to see if the right services are installed on
              # the right target platforms. This test should succeed.
              my @lines = split('\n', $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-query ${physicalNetworkNix}"));
              
              if(@lines[3] =~ /\-testService1/) {
                  print "Found testService1 on disnix-query output line 3\n";
              } else {
                  die "disnix-query output line 3 does not contain testService1!\n";
              }
              
              if(@lines[7] =~ /\-testService2/) {
                  print "Found testService2 on disnix-query output line 7\n";
              } else {
                  die "disnix-query output line 7 does not contain testService2!\n";
              }
              
              if(@lines[8] =~ /\-testService3/) {
                  print "Found testService3 on disnix-query output line 8\n";
              } else {
                  die "disnix-query output line 8 does not contain testService3!\n";
              }
            '';
        };
        
        deploymentNixOps = 
          let
            machine =
              {config, pkgs, ...}:
          
              {
                virtualisation.writableStore = true;
                virtualisation.memorySize = 1024;
                virtualisation.diskSize = 10240;
            
                ids.gids = { disnix = 200; };
                users.extraGroups = [ { gid = 200; name = "disnix"; } ];
            
                services.dbus.enable = true;
                services.dbus.packages = [ disnix ];
                services.openssh.enable = true;
            
                jobs.ssh.restartIfChanged = false;
            
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
              
                environment.systemPackages = [ pkgs.stdenv pkgs.nix disnix disnixos pkgs.busybox pkgs.module_init_tools pkgs.hello pkgs.zip pkgs.nixops ];
              };
              
              physicalNetworkNix = pkgs.writeTextFile {
                name = "network-physical.nix";
          
                text = ''
                  let
                    machine = {pkgs, ...}:
                    
                    {
                      require = [
                        "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
                        "${nixpkgs}/nixos/modules/testing/test-instrumentation.nix"
                      ];
                      boot.loader.grub.enable = false;
                      services.nixosManual.enable = false;
                      services.dbus.enable = true;
                      services.openssh.enable = true;
                      
                      # Create dummy Disnix job that does nothing. This prevents it from stopping.
                      jobs.disnix =
                        { description = "Disnix dummy server";

                          wantedBy = [ "multi-user.target" ];
                          restartIfChanged = false;
                          script = "true";
                        };
                      
                      environment.systemPackages = [ "${disnix}" ];
                      
                      deployment.targetEnv = "none";
                    };
                  in
                  {
                    testtarget1 = machine;
                    testtarget2 = machine;
                  }
                '';
              };
          in
          simpleTest {
            nodes = {
              coordinator = machine;
              testtarget1 = machine;
              testtarget2 = machine;
            };
            testScript =
              ''
                startAll;
                $coordinator->waitForJob("network-interfaces.target");
                $testtarget1->waitForJob("disnix");
                $testtarget2->waitForJob("disnix");
                
                # Initialise ssh stuff by creating a key pair for communication
                my $key=`${pkgs.openssh}/bin/ssh-keygen -t dsa -f key -N ""`;
    
                $testtarget1->mustSucceed("mkdir -m 700 /root/.ssh");
                $testtarget1->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

                $testtarget2->mustSucceed("mkdir -m 700 /root/.ssh");
                $testtarget2->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");
              
                $coordinator->mustSucceed("mkdir -m 700 /root/.ssh");
                $coordinator->copyFileFromHost("key", "/root/.ssh/id_dsa");
                $coordinator->mustSucceed("chmod 600 /root/.ssh/id_dsa");
                
                # Test SSH connectivity
                $coordinator->succeed("ssh -o StrictHostKeyChecking=no -v testtarget1 ls /");
                $coordinator->succeed("ssh -o StrictHostKeyChecking=no -v testtarget2 ls /");
                
                # Deploy infrastructure with NixOps
                $coordinator->mustSucceed("nixops create ${logicalNetworkNix} ${physicalNetworkNix}");
                $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} nixops deploy");
                
                # Deploy services with disnixos-env
                $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs}:nixops=${pkgs.nixops}/share/nix/nixops disnixos-env -s ${manifestTests}/services.nix -n ${logicalNetworkNix} -n ${physicalNetworkNix} -d ${manifestTests}/distribution.nix --use-nixops");
                
                # Use disnixos-query to see if the right services are installed on
                # the right target platforms. This test should succeed.
                my @lines = split('\n', $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs}:nixops=${pkgs.nixops}/share/nix/nixops disnixos-query ${physicalNetworkNix} --use-nixops"));
              
                if(@lines[3] =~ /\-testService1/) {
                    print "Found testService1 on disnix-query output line 3\n";
                } else {
                    die "disnix-query output line 3 does not contain testService1!\n";
                }
              
                if(@lines[7] =~ /\-testService2/) {
                    print "Found testService2 on disnix-query output line 7\n";
                } else {
                    die "disnix-query output line 7 does not contain testService2!\n";
                }
              
                if(@lines[8] =~ /\-testService3/) {
                    print "Found testService3 on disnix-query output line 8\n";
                } else {
                    die "disnix-query output line 8 does not contain testService3!\n";
                }
              '';
          };
      };
      
  };
in jobs
